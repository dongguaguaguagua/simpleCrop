//
//  HistoryManager.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/11.
//

import Foundation
import AppKit
import Combine

struct HistoryRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let text: String
    let confidence: Double
    let requestId: String
    let imageFileName: String // 只存文件名，不存路径
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var records: [HistoryRecord] = []
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.simpleCrop.historyQueue")
    
    private var rootURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("SimpleTexOCR/History")
        return folder
    }
    
    private var jsonURL: URL? {
        return rootURL?.appendingPathComponent("history.json")
    }
    
    init() {
        createDirectoryIfNeeded()
        loadRecords()
    }
    
    private func createDirectoryIfNeeded() {
        guard let url = rootURL else { return }
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func addRecord(image: NSImage, text: String, conf: Double, requestId: String) {
        queue.async { [weak self] in
            guard let self = self, let root = self.rootURL else { return }
            
            let id = UUID()
            let fileName = "\(id.uuidString).png"
            let fileURL = root.appendingPathComponent(fileName)
            
            // 1. 保存图片
            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: fileURL)
            }
            
            // 2. 创建记录对象
            let newRecord = HistoryRecord(
                id: id,
                date: Date(),
                text: text,
                confidence: conf,
                requestId: requestId,
                imageFileName: fileName
            )
            
            // 3. 更新内存和 JSON
            DispatchQueue.main.async {
                self.records.insert(newRecord, at: 0)
                self.saveRecordsToDisk()
            }
        }
    }
    
    func deleteRecord(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { records[$0] }
        records.remove(atOffsets: offsets)
        
        queue.async { [weak self] in
            guard let self = self, let root = self.rootURL else { return }
            
            for item in itemsToDelete {
                let url = root.appendingPathComponent(item.imageFileName)
                try? self.fileManager.removeItem(at: url)
            }
            // 在主线程触发保存可能会造成冲突，这里直接调用保存逻辑（注意 saveRecordsToDisk 目前是在主线程调用的，这里微调一下）
            DispatchQueue.main.async {
                self.saveRecordsToDisk()
            }
        }
    }
    
    private func saveRecordsToDisk() {
        guard let url = jsonURL else { return }
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: url)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    private func loadRecords() {
        guard let url = jsonURL, fileManager.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([HistoryRecord].self, from: data)
            // 按时间倒序
            self.records = loaded.sorted(by: { $0.date > $1.date })
        } catch {
            print("Failed to load history: \(error)")
        }
    }
    
    // 获取完整图片路径
    func imageURL(for fileName: String) -> URL? {
        return rootURL?.appendingPathComponent(fileName)
    }
}
