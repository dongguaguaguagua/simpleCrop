//
//  ScreenCaptureController.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/10.
//

import Cocoa
import CoreGraphics

// MARK: - 自定义窗口类
// 修复 Esc 无法触发的问题：无边框窗口默认无法成为 Key Window，必须重写此属性
class CanvasWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class ScreenCaptureController: NSObject {

    static let shared = ScreenCaptureController()

    private var overlayWindow: NSWindow?
    private var completion: ((NSImage?) -> Void)?

    // 防止类被外部初始化
    private override init() {}

    func beginCapture(completion: @escaping (NSImage?) -> Void) {
        self.completion = completion

        // 1. 获取主屏幕对象 (Cocoa)
        guard let screen = NSScreen.main else {
            print("Error: 未找到主屏幕")
            completion(nil)
            return
        }

        // 2. 关键修复：获取 CoreGraphics 坐标系下的屏幕范围
        // NSScreen.frame (左下角为0) vs CGWindow (左上角为0) 坐标系不同
        // 直接用 screen.frame 会导致截图区域错误（通常表现为只截到壁纸或顶部偏移）
        let displayID = CGMainDisplayID()
        let cgBounds = CGDisplayBounds(displayID)

        // 3. 执行截图
        // 注意：kCGNullWindowID 表示截取所有窗口
        // .optionOnScreenOnly 表示只截取屏幕上显示的（忽略被遮挡的）
        guard let cgImage = CGWindowListCreateImage(
            cgBounds,
            [.optionOnScreenOnly],
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            print("Error: 截图创建失败。请检查系统设置 -> 隐私与安全性 -> 屏幕录制权限。")
            completion(nil)
            return
        }

        // 将 CGImage 转为 NSImage，尺寸保持与屏幕逻辑尺寸一致
        let screenshot = NSImage(cgImage: cgImage, size: screen.frame.size)

        // 4. 创建覆盖窗口 (使用自定义的 CanvasWindow)
        let window = CanvasWindow(
            contentRect: screen.frame,
            styleMask: [.borderless], // 无边框
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // 5. 设置窗口属性
        window.level = .screenSaver + 1     // 确保盖住 Dock、菜单栏和屏保
        window.isOpaque = false             // 透明支持
        window.backgroundColor = .clear     // 背景透明
        window.ignoresMouseEvents = false   // 接收鼠标事件
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // 允许在全屏 App 上方显示

        // 6. 初始化视图
        let captureView = ScreenCaptureView(
            frame: screen.frame,
            screenshot: screenshot
        ) { [weak self] image in
            self?.finish(with: image)
        }

        window.contentView = captureView
        
        // 7. 关键：显示窗口并强制激活应用
        // 只有应用被激活 (.activate)，无边框窗口才能真正接收键盘事件 (Esc)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.overlayWindow = window
    }

    private func finish(with image: NSImage?) {
        // 关闭窗口
        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        // 执行回调
        let handler = completion
        completion = nil
        handler?(image)
    }
}
