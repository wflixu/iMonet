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
    @EnvironmentObject var storeManager: StoreManager

    @Binding var showPurchasePrompt: Bool

    @State private var showDirImporter = false

    @AppStorage("showCurDirImg")
    private var showCurDirImg = true

    private var permissionDirs: [PermissionDir] {
        appState.dirs.map { PermissionDir(url: $0) }
    }

    var body: some View {
        Form {
            imageBrowsingSection
            supportSection
        }
        .formStyle(.grouped)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - 图片浏览

    @ViewBuilder
    private var imageBrowsingSection: some View {
        Section {
            Toggle(isOn: $showCurDirImg) {
                Text("自动索引文件夹中的图片")
                Text("打开图片时自动加载同一文件夹下的所有图片")
            }

            if showCurDirImg {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("授权文件夹")
                            .font(.headline)

                        Spacer()

                        Button {
                            showDirImporter = true
                        } label: {
                            Label("添加文件夹", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if permissionDirs.isEmpty {
                        Text("点击 + 添加授权文件夹，添加后打开该文件夹内的图片无需再次授权。")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(Array(permissionDirs.enumerated()), id: \.element.path) { index, dir in
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                    Text(dir.path)
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        appState.dirs.remove(at: index)
                                        appState.storeBookmarkData()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                            }
                        }
                    }
                }
            }
        } header: {
            Text("图片浏览")
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
    }

    // MARK: - 支持 iMonet

    @ViewBuilder
    private var supportSection: some View {
        Section {
            if storeManager.isPurchased {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purchase Successful")
                            .font(.headline)
                        Text("Thank you for supporting iMonet!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "heart")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)

                        Text("Thank you for using iMonet to browse images! If you find it useful, please consider supporting us:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        showPurchasePrompt = true
                    } label: {
                        Text("View Support Options")
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        } header: {
            Text("Support iMonet")
        }
    }
}

#Preview {
    GeneralSettingsPane(showPurchasePrompt: .constant(false))
}
