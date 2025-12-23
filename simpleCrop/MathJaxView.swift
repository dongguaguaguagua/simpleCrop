//
//  MathJaxView.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/10.
//

import SwiftUI
import WebKit

struct MathJaxView: NSViewRepresentable {
    var markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // --- 修复点：macOS 上设置透明背景的方法 ---
        // WKWebView 在 macOS 上没有 drawsBackground 属性，使用 KVC 设置
        webView.setValue(false, forKey: "drawsBackground")
        // 如果 KVC 不起作用，也可以尝试：webView.layer?.backgroundColor = NSColor.clear.cgColor
        
        webView.loadHTMLString(htmlTemplate, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let data = markdown.data(using: .utf8) {
            let base64Str = data.base64EncodedString()
            let js = "updateContent('\(base64Str)');"
            
            webView.evaluateJavaScript(js) { _, error in
                if error != nil {
                    // 如果 JS 上下文还没准备好，回退到重新加载
                    webView.loadHTMLString(self.htmlTemplate, baseURL: nil)
                }
            }
        }
    }

    // HTML 模板保持不变，使用 Base64 更新内容
    private var htmlTemplate: String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script>
        MathJax = {
          tex: {
            inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
            displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
            processEscapes: true
          },
          svg: {
            fontCache: 'global'
          },
          startup: {
            typeset: false
          }
        };
        </script>
        <script type="text/javascript" id="MathJax-script" async
          src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js">
        </script>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                padding: 15px;
                font-size: 14px;
                line-height: 1.6;
                color: #333;
                background-color: transparent;
            }
            #content {
                white-space: pre-wrap;
                word-wrap: break-word;
            }
        </style>
        <script>
            function updateContent(base64Str) {
                try {
                    const str = decodeURIComponent(escape(window.atob(base64Str)));
                    const output = document.getElementById('content');
                    output.innerText = str;
                    if (window.MathJax && MathJax.typesetPromise) {
                        MathJax.typesetPromise([output]).catch(function (err) {
                            output.innerHTML = '';
                            output.appendChild(document.createTextNode(err.message));
                        });
                    }
                } catch(e) {
                    console.error(e);
                }
            }
        </script>
        </head>
        <body>
        <div id="content">Loading...</div>
        </body>
        </html>
        """
    }
}
