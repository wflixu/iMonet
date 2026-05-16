//
//  GeneralSettingsPane.swift
//  Monet
//
//  Created by 李旭 on 2024/9/12.
//

import SwiftUI

struct GeneralSettingsPane: View {
    @AppLog(category: "View-GeneralSettingsPane")
    private var logger

    @EnvironmentObject var appState: AppState

    @State private var showDirImporter = false

    @AppStorage("showCurDirImg")
    private var showCurDirImg = true

    private var permissionDirs: [PermissionDir] {
        appState.dirs.map { PermissionDir(url: $0) }
    }

    var body: some View {
        Form {
            imageBrowsingSection
        }
        .formStyle(.grouped)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Section 1: 图片浏览

    @ViewBuilder
    private var imageBrowsingSection: some View {
        Section {
            Toggle(isOn: $showCurDirImg) {
                Text("自动索引文件夹中的图片")
                Text("打开图片时自动加载同一文件夹下的所有图片")
            }

            if showCurDirImg {
                HStack {
                    Spacer()
                    Button(action: {
                        showDirImporter = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding([.leading, .trailing], 16)

                if permissionDirs.isEmpty {
                    Text("点击 + 添加授权文件夹，添加后打开该文件夹内的图片无需再次授权。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding([.leading, .trailing], 16)
                } else {
                    List {
                        ForEach(Array(permissionDirs.enumerated()), id: \.element.path) { index, dir in
                            HStack {
                                Text(dir.path)
                                    .font(.title3)
                                Spacer()
                                Button(action: {
                                    appState.dirs.remove(at: index)
                                    appState.storeBookmarkData()
                                }) {
                                    Image(systemName: "delete.left")
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showDirImporter,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let dirs):
                if let dir = dirs.first {
                    let gotAccess = dir.startAccessingSecurityScopedResource()
                    if gotAccess {
                        appState.dirs.append(dir)
                        appState.storeBookmarkData()
                    } else {
                        logger.warning("Failed to access directory: \(dir.path)")
                    }
                }
            case .failure(let error):
                logger.error("File importer failed: \(error.localizedDescription)")
            }
        }
        .onChange(of: showCurDirImg) { _, _ in
            appState.showCurDirImg = showCurDirImg
            if showCurDirImg {
                appState.restoreBookmarkData()
            }
        }
    }
}

#Preview {
    GeneralSettingsPane()
}
