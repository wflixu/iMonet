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

    private enum ImporterKind {
        case imageFile
        case folder
    }
    @State private var importerKind: ImporterKind?
    @State private var showFileImporter = false

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

                // Index banner overlay (only when image is loaded, so fileImporter here
                // doesn't conflict with the image file importer in the else branch below)
                if appState.showIndexBanner,
                   appState.pendingDirectoryURL != nil
                {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 16))
                            if appState.pendingDirectoryImageCount > 0 {
                                Text("此文件夹包含 \(appState.pendingDirectoryImageCount) 张图片")
                                    .font(.system(size: 14))
                            } else {
                                Text("浏览此文件夹中的所有图片")
                                    .font(.system(size: 14))
                            }
                            Button("浏览全部") {
                                appState.showIndexBanner = false
                                importerKind = .folder
                                showFileImporter = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            Button(action: {
                                if let dir = appState.pendingDirectoryURL {
                                    appState.dismissedBannerFolders.insert(dir)
                                }
                                appState.showIndexBanner = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding(.top, 8)

                        Spacer()
                    }
                    .zIndex(25)
                    .transition(.move(edge: .top))
                }

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
                                importerKind = .imageFile
                                showFileImporter = true
                            }
                        }
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height + 28)
                    .zIndex(10)
            }

            .ignoresSafeArea(.container)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: importerKind == .imageFile
                    ? [.png, .jpeg, .gif, .webP]
                    : [.directory],
                allowsMultipleSelection: true
            ) { result in
                let kind = importerKind
                importerKind = nil
                switch kind {
                case .imageFile:
                    if case .success(let urls) = result, let url = urls.first {
                        handleFileSelect(url)
                    }
                case .folder:
                    if case .success(let dirs) = result, let dir = dirs.first {
                        handleFolderAccess(dir)
                    }
                case nil:
                    break
                }
            }
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

    func handleFileSelect(_ fileUrl: URL) {
        let gotAccess = fileUrl.startAccessingSecurityScopedResource()
        if !gotAccess {
            logger.warning("not got access")
            return
        }

        if let appDelegate = appState.appDelegate {
            appDelegate.loadImages(from: fileUrl)
            loadImage(at: appState.selectedImageIndex)
        } else {
            logger.warning("not appDelegate")
        }
    }

    func handleFolderAccess(_ dir: URL) {
        guard let currentURL = appState.currentImageURL else {
            logger.error("handleFolderAccess: currentImageURL is nil")
            return
        }
        let gotAccess = dir.startAccessingSecurityScopedResource()
        guard gotAccess else {
            logger.warning("Failed to access folder: \(dir.path)")
            return
        }
        // keep access alive for image loading; indexFolder manages lifecycle

        if !appState.dirs.contains(dir) {
            appState.dirs.append(dir)
            appState.storeBookmarkData()
        }

        if let appDelegate = appState.appDelegate {
            appDelegate.indexFolder(dir, currentURL: currentURL, keepAccess: true)
            loadImage(at: appState.selectedImageIndex)
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
