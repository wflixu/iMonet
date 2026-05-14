//
//  MonetApp.swift
//  Monet
//
//  Created by 李旭 on 2024/9/1.
//

import AppKit
import SwiftUI

@main
struct MonetApp: App {
    @AppLog(category: "MonetApp")
    private var logger

    @Environment(\.openWindow) private var openWindow

    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    // 设置 App Delegate 以响应 open file 请求
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var appState = AppState()

    init() {
        logger.info("app init .....")
        appDelegate.assignAppState(appState)
    }

    var body: some Scene {
        Window("Monet", id: "main") {
            ContentView()
                .onAppear {
                    if appState.showCurDirImg && appState.dirs.isEmpty {
                        openWindow(id: Constants.settingsWindowID)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .environmentObject(appState)

        SettingsWindow(appState: appState, onAppear: {})

        MenuBarExtra(
            "Monet", image: "menubar", isInserted: $showMenuBarExtra
        ) {
            MenuBarView()
        }.environmentObject(appState)
    }
}

// AppDelegate 负责处理文件打开请求
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    @AppLog(category: "AppState")
    private var logger

    private var appState: AppState?

    func applicationWillFinishLaunching(_ notification: Notification) {
        logger.info("---- app will finish launch")
        guard let appState else {
            logger.warning("Missing app state in applicationWillFinishLaunching")
            return
        }

        // assign the delegate to the shared app state
        appState.assignAppDelegate(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("applicationDidFinishLaunching  .......")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 当最后一个窗口关闭时，终止应用
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        logger.info("application open urls")
        guard let currentImageURL = urls.first else {
            logger.warning("no url in urls")
            return
        }
        logger.info("Received file URL: \(currentImageURL)")
        loadImages(from: currentImageURL)
        NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("applicationShouldTerminate")
        return .terminateNow
    }

    /// Opens the settings window and activates the app.
    @objc func openSettingsWindow() {
        guard
            let appState,
            let settingsWindow = appState.settingsWindow
        else {
            logger.warning("Failed to open settings window")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            appState.activate(withPolicy: .regular)
            settingsWindow.center()
            settingsWindow.makeKeyAndOrderFront(self)
        }
    }

    /// Assigns the app state to the delegate.
    func assignAppState(_ appState: AppState) {
        guard self.appState == nil else {
            logger.warning("Multiple attempts made to assign app state")
            return
        }
        self.appState = appState
    }

    func loadImages(from url: URL) {
        logger.info("loadImages from: \(url.path)")
        guard let appState else { return }

        // Always load the selected image first
        appState.imageFiles = [url]
        appState.selectedImageIndex = 0
        appState.currentImageURL = url

        guard appState.showCurDirImg else { return }

        let directory = url.deletingLastPathComponent()

        // Try existing bookmark access first
        if indexFolder(directory, currentURL: url) { return }

        // No permission — request via NSOpenPanel sheet
        promptFolderPermission(for: directory, currentURL: url)
    }

    /// Request folder access permission via NSOpenPanel presented as a sheet on the main window.
    func promptFolderPermission(for directory: URL, currentURL: URL) {
        guard let appState else { return }
        guard let window = NSApplication.shared.windows.first(where: { $0.title == "Monet" }) else {
            logger.warning("No Monet window found for sheet")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.message = "允许 Monet 访问此文件夹以浏览所有图片"
        panel.prompt = "允许"

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let selectedURL = panel.url else { return }

            let gotAccess = selectedURL.startAccessingSecurityScopedResource()
            guard gotAccess else { return }

            if !appState.dirs.contains(selectedURL) {
                appState.dirs.append(selectedURL)
                appState.storeBookmarkData()
            }

            self.indexFolder(selectedURL, currentURL: currentURL, keepAccess: true)
        }
    }

    /// Scan a directory for images with proper security-scoped access.
    @discardableResult
    func indexFolder(_ directory: URL, currentURL: URL, keepAccess: Bool = false) -> Bool {
        guard let appState else { return false }

        let startedHere = !keepAccess && directory.startAccessingSecurityScopedResource()
        if !keepAccess {
            guard startedHere else { return false }
        }
        defer {
            if startedHere { directory.stopAccessingSecurityScopedResource() }
        }

        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            logger.warning("Cannot read directory: \(directory.path)")
            return false
        }

        let imageFiles = files
            .filter { Constants.supportedImageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !imageFiles.isEmpty else { return false }

        appState.imageFiles = imageFiles
        appState.selectedImageIndex = imageFiles.firstIndex(of: currentURL) ?? 0
        appState.currentImageURL = imageFiles[appState.selectedImageIndex]
        logger.info("Indexed \(imageFiles.count) images in folder")

        return true
    }
}
