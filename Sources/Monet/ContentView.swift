//
//  ContentView.swift
//  Monet
//
//  Created by 李旭 on 2024/9/1.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @AppLog(category: "ContentView")
    private var logger

    @EnvironmentObject var appState: AppState

    @State private var currentImage: NSImage?
    @State private var scale: CGSize = .init(width: 1, height: 1)

    @State private var isNavBarVisible: Bool = true

    @State private var window: NSWindow?

    @State private var showFileSelector = false

    @State private var monetImageView: MonetImageView? = nil
    @State private var scrollViewProxy: ScrollViewProxy? = nil

    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .topLeading) {
                if isNavBarVisible {
                    VStack {
                        ScrollViewReader { scroller in

                            ScrollView {
                                LazyVStack {
                                    ForEach(Array(appState.imageFiles.enumerated()), id: \.offset) { index, imageURL in
                                        ImageThumbnailView(imageURL: imageURL, isSelected: appState.selectedImageIndex == index).id(index)
                                            .onTapGesture {
                                                loadImage(at: index)
                                            }
                                    }
                                }
                            }
                            .scrollIndicators(.never)
                            .padding(4)
                            .onAppear {
                                print("scrollViewProxy ....... init")
                                scrollViewProxy = scroller
                            }

                            // 确保浮动在主视图上方
                        }
                    }
                    .padding([.top], 28)
                    .frame(width: 128, height: (window?.frame.size.height ?? 720))
                    .background(Color.gray.opacity(0.6)) // 半透明背景
                    .zIndex(20)
                }

                ToolBarView(scale: scale, onTap: { actionID in
                    handleToolbarTap(actionID)
                })
                .zIndex(20)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 32)

                HStack {
                    if let currentImage = currentImage {
                        ZoomableImageView(image: currentImage,
                            onScaleChanged: { newScale in
                                scale = CGSize(width: newScale, height: newScale)
                            },
                            onViewCreated: { imageView in
                                monetImageView = imageView
                            }
                        )
                    } else {
                        HStack {
                            Button("Select Image File") {
                                showFileSelector = true
                            }
                            .fileImporter(isPresented: $showFileSelector, allowedContentTypes: [.png, .jpeg, .gif, .webP]) { result in
                                handleFileSelect(result)
                            }
                        }
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height + 28)
                    .zIndex(10)
            }

            .ignoresSafeArea(.container)
            .onAppear(perform: appearHandler)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("open-image"))) { _ in
                loadImage(at: appState.selectedImageIndex)
            }
        }
    }

    func handleToolbarTap(_ id: ToolbarActionIdentifier) {
        print(id)
        switch id {
        case .toggleNav:
            isNavBarVisible.toggle()

        case .scaleMinis:
            monetImageView?.zoomOut()

        case .scalePlus:
            monetImageView?.zoomIn()

        case .showPrev:
            showPreviousImage()
        case .showNext:
            showNextImage()

        case .centerFill:
            centerFillImage()

        default:
            logger.warning("no action after tap toolbar")
        }
    }
    
    func centerFillImage() {
        monetImageView?.fitToWindow()
    }

    func handleFileSelect(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let fileUrl):
            // gain access to the directory
            let gotAccess = fileUrl.startAccessingSecurityScopedResource()
            if !gotAccess {
                logger.warning("not got access")
                return
            }
            // access the directory URL

            if let appDelegate = appState.appDelegate {
                appDelegate.loadImages(from: fileUrl)
                loadImage(at: appState.selectedImageIndex)
            } else {
                logger.warning("not appDelegate")
            }

        // release access
//            fileUrl.stopAccessingSecurityScopedResource()
        case .failure(let error):
            // handle error
            logger.error("error: \(error)")
        }
    }

    func appearHandler() {
        setupKeyEvents()
        loadImage(at: appState.selectedImageIndex)

        if let window = NSApplication.shared.windows.first {
            print("windwo \(window.title)-- \(window.frame.size)")
            self.window = window
        } else {
            print("not get window")
        }
    }

    private func loadImage(at index: Int) {
        print("loadImage ........")
        guard appState.imageFiles.indices.contains(index) else { return }
        // 获取图片 URL
        let url = appState.imageFiles[index]

        // 更新 AppState 中的 currentImageURL 和 selectedImageIndex
        appState.currentImageURL = url
        appState.selectedImageIndex = index
        scrollViewProxy?.scrollTo(index)

        // 尝试加载图像
        if let image = NSImage(contentsOf: url) {
            currentImage = image
        }
    }

    private func setupKeyEvents() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 124, 125: // Right Arrow
                showNextImage()
                return nil
            case 123, 126: // Left Arrow
                showPreviousImage()
                return nil
            default:
                return event
            }
        }
    }

    private func showNextImage() {
        if appState.selectedImageIndex < appState.imageFiles.count - 1 {
            loadImage(at: appState.selectedImageIndex + 1)
        }
    }

    private func showPreviousImage() {
        if appState.selectedImageIndex > 0 {
            loadImage(at: appState.selectedImageIndex - 1)
        }
    }
}

#Preview {
    ContentView()
}
