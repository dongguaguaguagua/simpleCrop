//
//  TextViewWrapper.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/10.
//

import SwiftUI
import AppKit

struct TextViewWrapper: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false // 通常代码编辑器自动换行
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.isEditable = true // 允许编辑
        textView.isSelectable = true
        textView.isRichText = false
        // 使用等宽字体
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        // 允许撤销/重做
        textView.allowsUndo = true
        
        // 绑定代理
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // 防止循环更新：只有当 text 确实变了才更新 view
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextViewWrapper
        
        init(_ parent: TextViewWrapper) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}
