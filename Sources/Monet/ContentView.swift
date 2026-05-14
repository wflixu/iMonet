//
//  ContentView.swift
//  Monet
//

import SwiftUI

struct ContentView: View {
    @AppLog(category: "ContentView")
    private var logger

    @EnvironmentObject var appState: AppState

    @State private var scale: CGSize = .init(width: 1, height: 1)
    @State private var isNavBarVisible = true
    @State private var window: NSWindow?
    @State private var monetImageView: MonetImageView?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if isNavBarVisible {
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

                ImagePreviewView(scale: $scale, monetImageView: $monetImageView)
                    .frame(width: geometry.size.width, height: geometry.size.height + 28)
                    .zIndex(10)

                ToolBarView(scale: scale, onTap: { actionID in
                    handleToolbarTap(actionID)
                })
                .zIndex(20)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 32)
            }
            .ignoresSafeArea(.container)
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

        default:
            logger.warning("no action after tap toolbar")
        }
    }

    func appearHandler() {
        if let window = NSApplication.shared.windows.first {
            self.window = window
        }
    }
}

#Preview {
    ContentView()
}
