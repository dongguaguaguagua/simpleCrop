//
//  ScreenCaptureView.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/10.
//

import Cocoa

class ScreenCaptureView: NSView {

    private let screenshot: NSImage
    private let completion: (NSImage?) -> Void

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var isDragging: Bool = false
    
    // 追踪区域，用于在不按鼠标时也能显示十字线
    private var trackingArea: NSTrackingArea?

    init(frame frameRect: NSRect, screenshot: NSImage, completion: @escaping (NSImage?) -> Void) {
        self.screenshot = screenshot
        self.completion = completion
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 再次确保 View 成为第一响应者
        window?.makeFirstResponder(self)
    }
    
    // MARK: - 追踪区域配置 (Mouse Hover)
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // .mouseMoved: 鼠标移动触发
        // .activeAlways: 无论窗口是否激活都生效
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    // MARK: - 绘制逻辑

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds

        // 1. 画整屏截图（底图）
        screenshot.draw(in: bounds)

        // 2. 黑色半透明遮罩
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill(using: .sourceOver)

        // 3. 画选区高亮 (挖空遮罩的效果)
        if let rect = currentSelectionRect() {
            drawSelection(rect: rect)
        }
        
        // 4. 画十字线和坐标 (在最上层)
        if let cursor = currentPoint {
            drawCrosshair(at: cursor, in: bounds)
            drawCoordinate(at: cursor)
        }
    }

    private func currentSelectionRect(allowEnded: Bool = false) -> NSRect? {
        guard let start = startPoint, let current = currentPoint else {
            return nil
        }
        
        // 如果不在拖拽且不允许结束，则没有选区
        if !isDragging && !allowEnded {
            return nil
        }

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(start.x - current.x)
        let h = abs(start.y - current.y)

        if w < 2 || h < 2 {
            return nil
        }

        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func drawSelection(rect: NSRect) {
        // 保存当前上下文
        NSGraphicsContext.saveGraphicsState()
        
        // 设置裁剪区域为选框
        let path = NSBezierPath(rect: rect)
        path.setClip()
        
        // 在裁剪区域内重绘原图（看起来就是变亮了，因为遮罩被去掉了）
        screenshot.draw(in: bounds)
        
        NSGraphicsContext.restoreGraphicsState()

        // 画边框
        NSColor.systemBlue.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawCrosshair(at point: NSPoint, in bounds: NSRect) {
        let path = NSBezierPath()
        path.lineWidth = 1

        // 垂直线
        path.move(to: NSPoint(x: point.x, y: bounds.minY))
        path.line(to: NSPoint(x: point.x, y: bounds.maxY))

        // 水平线
        path.move(to: NSPoint(x: bounds.minX, y: point.y))
        path.line(to: NSPoint(x: bounds.maxX, y: point.y))

        NSColor.white.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }

    private func drawCoordinate(at point: NSPoint) {
        // macOS 屏幕坐标系左下角为(0,0)，如果想显示左上角为0，可以用 bounds.height - point.y
        let text = "(\(Int(point.x)), \(Int(point.y)))"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]

        let attr = NSAttributedString(string: text, attributes: attributes)
        let size = attr.size()

        var origin = NSPoint(x: point.x + 10, y: point.y - 25)
        
        // 简单的边界检查
        if origin.x + size.width > bounds.maxX { origin.x = point.x - size.width - 5 }
        if origin.y < bounds.minY { origin.y = point.y + 10 }

        attr.draw(at: origin)
    }

    // MARK: - 事件处理

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        startPoint = p
        currentPoint = p
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        currentPoint = p
        needsDisplay = true
    }

    // 新增：鼠标移动（不按键）也刷新十字线
    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        // 只有在没有开始拖拽时，才更新 currentPoint
        if !isDragging {
            currentPoint = p
            // 这里不要设置 startPoint，否则会画出一个点大小的框
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        currentPoint = p
        isDragging = false
        needsDisplay = true

        guard let rect = currentSelectionRect(allowEnded: true) else {
            // 点击也没画框，不处理或取消
            return
        }

        let cropped = crop(image: screenshot, to: rect)
        completion(cropped)
    }

    // MARK: - 键盘：Esc 取消

    override func keyDown(with event: NSEvent) {
        // Esc code = 53
        if event.keyCode == 53 {
            completion(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - 裁剪函数

    private func crop(image: NSImage, to rect: NSRect) -> NSImage? {
        let newImage = NSImage(size: rect.size)
        newImage.lockFocus()
        image.draw(
            at: NSZeroPoint,
            from: rect,
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
}
