//
//  HistoryView.swift
//  (修改 HistoryDetailView 部分)
//

import SwiftUI
import Combine // 必须引入 Combine

struct HistoryView: View {
    @ObservedObject var manager = HistoryManager.shared
    @State private var selectedRecordId: UUID?
    
    var body: some View {
        HSplitView {
            // 左侧：列表
            VStack(spacing: 0) {
                Text("历史记录")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                
                List(selection: $selectedRecordId) {
                    ForEach(manager.records) { record in
                        HistoryRow(record: record)
                            .tag(record.id) // 关键：用于 selection
                    }
                    // macOS 10.15 List 删除支持需要配合 contextMenu 或其它方式，这里简化处理
                }
                .listStyle(PlainListStyle()) // 10.15 兼容性较好
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // 右侧：详情
            if let uuid = selectedRecordId, let record = manager.records.first(where: { $0.id == uuid }) {
                HistoryDetailView(record: record)
                    .frame(minWidth: 400, maxWidth: .infinity)
            } else {
                Text("请选择一条记录")
                    .foregroundColor(.secondary)
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

struct HistoryRow: View {
    let record: HistoryRecord
    
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text.prefix(30) + (record.text.count > 30 ? "..." : ""))
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            
            HStack {
                Text(Self.dateFormatter.string(from: record.date))
                Spacer()
                Text(String(format: "Conf: %.2f", record.confidence))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct HistoryDetailView: View {
    let record: HistoryRecord
    @State private var text: String
    @State private var debouncedText: String
    @State private var nsImage: NSImage?
    
    // 用于防抖的发布者
    let textSubject = PassthroughSubject<String, Never>()
    
    init(record: HistoryRecord) {
        self.record = record
        _text = State(initialValue: record.text)
        _debouncedText = State(initialValue: record.text)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- 顶部信息栏 ---
            HStack(spacing: 12) {
                if let img = nsImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 60, height: 60)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date: \(HistoryRow.dateFormatter.string(from: record.date))")
                    Text("ID: \(record.requestId)").font(.system(.caption, design: .monospaced))
                    Text("Confidence: \(String(format: "%.4f", record.confidence))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("复制文本") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // --- 编辑与预览 ---
            HSplitView {
                VStack(spacing: 0) {
                    Text("LaTeX / Markdown")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .background(Color(NSColor.windowBackgroundColor))
                    
                    // 这里绑定 text，当 text 变化时，通过 updateNSView 或 Coordinator 触发 State 更新
                    // State 更新会触发 body 刷新，进而触发下面的 onReceive
                    TextViewWrapper(text: $text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack(spacing: 0) {
                    Text("Preview")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .background(Color(NSColor.windowBackgroundColor))
                    
                    MathJaxView(markdown: debouncedText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            loadImage()
        }
        // --- 修复报错 1 & 2: 替换 onChange(of: record.id) ---
        .onReceive(Just(record.id)) { _ in
            // 当传入的 record 改变时，重置内部状态
            if self.text != record.text {
                self.text = record.text
                self.debouncedText = record.text
                self.loadImage()
            }
        }
        // --- 修复报错 1 & 2: 替换 onChange(of: text) ---
        // 监听 text 变化，发送给 Combine 管道做防抖
        .onReceive(Just(text)) { val in
            textSubject.send(val)
        }
        // 处理防抖逻辑
        .onReceive(textSubject.debounce(for: .seconds(0.1), scheduler: RunLoop.main)) { val in
            if self.debouncedText != val {
                self.debouncedText = val
            }
        }
    }
    
    private func loadImage() {
        if let url = HistoryManager.shared.imageURL(for: record.imageFileName),
           let img = NSImage(contentsOf: url) {
            self.nsImage = img
        } else {
            self.nsImage = nil
        }
    }
}
