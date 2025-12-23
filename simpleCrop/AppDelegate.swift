//
//  AppDelegate.swift
//  simpleCrop
//
//  Created by hzy on 2025/12/10.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    var historyWindow: NSWindow? // 新增：历史记录窗口引用

    let viewModel = OCRViewModel()
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentView = ContentView(viewModel: viewModel)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        // 关键：设为 false，关闭时只是隐藏，方便快速恢复
        window.isReleasedWhenClosed = false
        window.center()
        window.title = "SimpleTex OCR"
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        setupMenus()
        setupStatusItem()
    }

    // MARK: - 窗口管理核心代码

    // 1. 点击 Dock 图标时调用
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 如果没有可见窗口，就显示主窗口
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    // 2. 显示主窗口的通用方法
    @objc func showMainWindow(_ sender: Any?) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // 3. 定义 Dock 菜单（右键点击 Dock 图标时显示）
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let showItem = NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow(_:)), keyEquivalent: "")
        menu.addItem(showItem)
        return menu
    }
    // MARK: - 窗口管理：历史记录
        
    @objc func showHistoryWindow(_ sender: Any?) {
        if historyWindow == nil {
            // 创建历史窗口
            let historyView = HistoryView() // 这里使用 HistoryManager.shared
            
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "SimpleTex 历史记录"
            win.isReleasedWhenClosed = false // 关闭只隐藏
            win.center()
            win.setFrameAutosaveName("History Window")
            win.contentView = NSHostingView(rootView: historyView)
            historyWindow = win
        }
        
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - 菜单设置

    private func setupMenus() {
        let mainMenu = NSMenu()

        // --- App 菜单 ---
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "关于 SimpleTex OCR", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // --- Window 菜单 (显示在顶部菜单栏) ---
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = NSMenu(title: "Window")
        windowMenuItem.submenu?.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenuItem.submenu?.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenuItem.submenu?.addItem(NSMenuItem.separator())
        
        // 增加显示主窗口命令
        let showMainItem = NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow(_:)), keyEquivalent: "0")
        showMainItem.keyEquivalentModifierMask = [.command] // Cmd + 0
        windowMenuItem.submenu?.addItem(showMainItem)
        
        // 新增：显示历史记录
        let historyItem = NSMenuItem(title: "历史记录", action: #selector(showHistoryWindow(_:)), keyEquivalent: "h")
        historyItem.keyEquivalentModifierMask = [.command, .shift] // Cmd + Shift + H
        windowMenuItem.submenu?.addItem(historyItem)
        
        mainMenu.addItem(windowMenuItem)
        
        // --- Edit 菜单 (必须保留，否则无法复制粘贴) ---
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        // --- SimpleTex 功能菜单 ---
        let simpletexMenuItem = NSMenuItem()
        mainMenu.addItem(simpletexMenuItem)
        let simpletexMenu = NSMenu(title: "Crop")
        simpletexMenuItem.submenu = simpletexMenu
        
        let captureItem = NSMenuItem(title: "截取屏幕...", action: #selector(captureScreen(_:)), keyEquivalent: "s")
        simpletexMenu.addItem(captureItem)
        
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Tex"
        }
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "截取屏幕", action: #selector(statusItemCapture(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "历史记录", action: #selector(showHistoryWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp(_:)), keyEquivalent: ""))
        statusItem.menu = menu
    }
    
    // ... captureScreen 等其他逻辑保持不变 ...
    @objc func captureScreen(_ sender: Any?) {
        // (保持原有的截图逻辑)
        let shouldShowAfterCapture = true
        window.orderOut(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.viewModel.onCaptureFinished = {
                if shouldShowAfterCapture {
                    DispatchQueue.main.async {
                        self.showMainWindow(nil) // 复用显示窗口方法
                    }
                }
            }
            self.viewModel.startFromMenu()
        }
    }
    
    @objc func statusItemCapture(_ sender: Any?) {
        captureScreen(sender)
    }

    @objc func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
