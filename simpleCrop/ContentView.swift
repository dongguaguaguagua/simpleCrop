//
//  ContentView.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/10.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: OCRViewModel
    
    // 不需要 @State private var debouncedText 了，直接用 viewModel.debouncedResultText

    var body: some View {
        VStack(spacing: 0) {
            
            // --- 顶部工具栏 ---
            VStack(alignment: .leading, spacing: 10) {
                GroupBox {
                    HStack {
                        Text("Token:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("SimpleTex Token", text: $viewModel.token)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                
                HStack {
                    if viewModel.isLoading {
                        Text("识别中...").font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("就绪").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if let err = viewModel.lastError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            // --- 主内容：左右分栏 ---
            HSplitView {
                // 左侧：编辑器 (绑定原始 resultText)
                VStack(spacing: 0) {
                    headerView(title: "LaTeX / Markdown 编辑")
                    TextViewWrapper(text: $viewModel.resultText)
                        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor))
                }
                .layoutPriority(1)

                // 右侧：预览 (绑定防抖后的 debouncedResultText)
                VStack(spacing: 0) {
                    headerView(title: "MathJax 预览")
                    // 修复点：直接使用 viewModel 中的防抖属性
                    MathJaxView(markdown: viewModel.debouncedResultText)
                        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                }
                .layoutPriority(1)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
    
    private func headerView(title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(Divider(), alignment: .bottom)
    }
}
