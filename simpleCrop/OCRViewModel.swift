//
//  OCRViewModel.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/10.
//

import Foundation
import AppKit
import Combine

// MARK: - JSON Models
struct SimpleTexResponse: Decodable {
    let status: Bool
    let res: SimpleTexRes?
    let request_id: String?
}

struct SimpleTexRes: Decodable {
    let type: String
    let info: InfoData
    let conf: Double?
    
    // 自定义解码逻辑来处理 'info' 可能是 String 也可能是 Object 的情况
    enum CodingKeys: String, CodingKey {
        case type, info, conf
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        conf = try container.decodeIfPresent(Double.self, forKey: .conf)
        
        // 尝试解码为 InfoObject
        if let objectVal = try? container.decode(InfoDataWrapper.self, forKey: .info) {
            info = .object(objectVal)
        } else if let stringVal = try? container.decode(String.self, forKey: .info) {
            info = .string(stringVal)
        } else {
            info = .string("") // Fallback
        }
    }
}

enum InfoData {
    case string(String)
    case object(InfoDataWrapper)
}

struct InfoDataWrapper: Decodable {
    let markdown: String?
}

// MARK: - ViewModel
class OCRViewModel: ObservableObject {
    @Published var resultText: String = ""
    // --- 新增：专门给预览视图用的防抖文本 ---
    @Published var debouncedResultText: String = ""
    
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    
    @Published var token: String {
        didSet {
            UserDefaults.standard.set(token, forKey: "SimpleTexToken")
        }
    }

    var onCaptureFinished: (() -> Void)?
    private let simpleTexURL = URL(string: "https://server.simpletex.net/api/simpletex_ocr")!
    private var cancellables = Set<AnyCancellable>()

    init() {
        let saved = UserDefaults.standard.string(forKey: "SimpleTexToken") ?? ""
        self.token = saved
        
        let initialText = "## 使用说明\n1. 在上方设置中填入 Token\n2. 点击菜单「SimpleTex -> 截取屏幕」\n3. 结果将显示在此处，右侧为预览"
        self.resultText = initialText
        self.debouncedResultText = initialText
        
        // --- 核心修复：在这里设置防抖 ---
        // 监听 resultText 的变化，延迟 0.1 秒后赋值给 debouncedResultText
        $resultText
            .debounce(for: .seconds(0.1), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: \.debouncedResultText, on: self)
            .store(in: &cancellables)
    }
    
    private func currentToken() -> String? {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    func startFromMenu() {
        // ... (保持之前的逻辑) ...
        guard currentToken() != nil else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = "请先在设置中填写 SimpleTex UAT Token"
                self.resultText = "请在设置区域填入 Token。"
            }
            self.onCaptureFinished?()
            return
        }

        DispatchQueue.main.async {
            self.isLoading = false
            self.lastError = nil
        }

        ScreenCaptureController.shared.beginCapture { [weak self] image in
            guard let self = self else { return }
            
            // 【修复报错 128 & 141】
            // 如果 ScreenCaptureController 返回的是 NSImage? (可选)，则用 guard let 解包
            // 如果它返回的是 NSImage (非可选)，直接使用 image
            
            // 假设 beginCapture 的闭包参数是 image (NSImage?)：
            guard let capturedImage = image else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.onCaptureFinished?()
                }
                return
            }

            DispatchQueue.main.async {
                self.isLoading = true
                self.onCaptureFinished?()
            }

            // 【修复报错 128】：capturedImage 已经是解包后的 NSImage，不需要 optional chaining (?)
            guard
                let tiffData = capturedImage.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData),
                let pngData = bitmap.representation(using: .png, properties: [:])
            else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.lastError = "图片转换失败"
                }
                return
            }

            // 【修复报错 221】：这里的 result 类型现在是 (String, Double, String)
            self.callSimpleTex(with: pngData) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch result {
                    case .success(let (text, conf, reqId)): // 解构元组
                        self.resultText = text
                        
                        // 保存到历史记录
                        HistoryManager.shared.addRecord(
                            image: capturedImage, // 【修复报错 141】：这里不需要 !，因为 capturedImage 已解包
                            text: text,
                            conf: conf,
                            requestId: reqId
                        )
                        
                    case .failure(let error):
                        self.lastError = error.localizedDescription
                        self.resultText = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // 【修复报错 221】：必须显式修改这里的 completion 类型签名
    // 从 Result<String, Error> 改为 Result<(String, Double, String), Error>
    private func callSimpleTex(with imageData: Data, completion: @escaping (Result<(String, Double, String), Error>) -> Void) {
        guard let token = currentToken() else { return }

        var request = URLRequest(url: simpleTexURL)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "token")
        
        var body = Data()
        let params: [String: String] = ["rec_mode": "document"]
        for (key, value) in params {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"capture.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode(SimpleTexResponse.self, from: data)
                let reqId = decoded.request_id ?? "unknown"
                
                guard decoded.status, let res = decoded.res else {
                    completion(.failure(NSError(domain: "ST", code: -2, userInfo: [NSLocalizedDescriptionKey: "API status false"])))
                    return
                }
                
                var finalString = ""
                switch res.info {
                case .string(let str):
                    if res.type == "formula" { finalString = "$$\n\(str)\n$$" } else { finalString = str }
                case .object(let wrapper):
                    if let md = wrapper.markdown { finalString = md } else { finalString = "解析结果结构未知" }
                }
                
                let conf = res.conf ?? 0.0
                
                // 返回元组
                completion(.success((finalString, conf, reqId)))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
