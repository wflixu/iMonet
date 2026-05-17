//
//  ContentView.swift
//  Monet
//

import SwiftUI

struct ContentView: View {
    @AppLog(category: "ContentView")
    private var logger

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var scale: CGSize = .init(width: 1, height: 1)
    @State private var isNavBarVisible = true
    @State private var window: NSWindow?
    @State private var monetImageView: MonetImageView?
    @State private var isChromeVisible = true
    @State private var chromeTimer: Timer?
    @State private var isInfoPanelVisible = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if isNavBarVisible && appState.imageFiles.count > 1 {
                    ThumbnailSidebar(
                        imageFiles: appState.imageFiles,
                        selectedIndex: appState.selectedImageIndex,
                        windowHeight: window?.frame.size.height ?? 720,
                        onSelect: { index in
                            appState.selectedImageIndex = index
                            appState.currentImageURL = appState.imageFiles[index]
                            NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
                        }
                    )
                    .zIndex(20)
                }

                if isInfoPanelVisible {
                    ImageInfoPanel(
                        imageURL: appState.currentImageURL,
                        windowHeight: window?.frame.size.height ?? 720,
                        onClose: { isInfoPanelVisible = false }
                    )
                    .zIndex(20)
                    .position(x: geometry.size.width - 130, y: (window?.frame.size.height ?? 720) / 2)
                }

                ImagePreviewView(scale: $scale, monetImageView: $monetImageView, onClick: showChrome)
                    .frame(width: geometry.size.width, height: geometry.size.height + 28)
                    .zIndex(10)

                Text("iMonet")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(isChromeVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isChromeVisible)
                    .zIndex(20)
                    .position(x: geometry.size.width / 2, y: 16)

                ToolBarView(scale: scale, onTap: { actionID in
                    handleToolbarTap(actionID)
                }, onHoverEnter: cancelChromeTimer, onHoverExit: resetChromeTimer)
                .opacity(isChromeVisible ? 1 : 0)
                .allowsHitTesting(isChromeVisible)
                .animation(.easeInOut(duration: 0.3), value: isChromeVisible)
                .zIndex(20)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 32)
            }
            .ignoresSafeArea(.container)
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.9))
            .onAppear(perform: appearHandler)
        }
    }

    func handleToolbarTap(_ id: ToolbarActionIdentifier) {
        switch id {
        case .toggleNav:
            isNavBarVisible.toggle()

        case .scaleMinis:
            monetImageView?.zoomOut()

        case .scalePlus:
            monetImageView?.zoomIn()

        case .showPrev:
            if appState.selectedImageIndex > 0 {
                appState.selectedImageIndex -= 1
                appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
                NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
            }

        case .showNext:
            if appState.selectedImageIndex < appState.imageFiles.count - 1 {
                appState.selectedImageIndex += 1
                appState.currentImageURL = appState.imageFiles[appState.selectedImageIndex]
                NotificationCenter.default.post(name: Notification.Name("open-image"), object: nil)
            }

        case .centerFill:
            monetImageView?.fitToWindow()

        case .toggleInfo:
            isInfoPanelVisible.toggle()
        }
    }

    func appearHandler() {
        if let window = NSApplication.shared.windows.first {
            self.window = window
        }
        showChrome()
    }

    func showChrome() {
        isChromeVisible = true
        resetChromeTimer()
    }

    func hideChrome() {
        isChromeVisible = false
        chromeTimer?.invalidate()
        chromeTimer = nil
    }

    func resetChromeTimer() {
        chromeTimer?.invalidate()
        let timer = Timer(timeInterval: 5, repeats: false) { _ in
            DispatchQueue.main.async {
                self.hideChrome()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        chromeTimer = timer
    }

    func cancelChromeTimer() {
        chromeTimer?.invalidate()
        chromeTimer = nil
    }
}

#Preview {
    ContentView()
}
