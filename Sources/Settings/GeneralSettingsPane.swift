//
//  GeneralSettingsPane.swift
//  iMonet
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
                purchasedBadge
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

    // MARK: - Purchased State

    @ViewBuilder
    private var purchasedBadge: some View {
        VStack(spacing: 0) {
            // Top ornament: heart icon with glow
            ZStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                    .shadow(color: .red.opacity(0.3), radius: 12, y: 2)

                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .offset(x: 24, y: -18)
            }
            .padding(.top, 20)
            .padding(.bottom, 10)

            // Plan badge pill
            Text(planBadgeText)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(planBadgeColor.opacity(0.15))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(planBadgeColor.opacity(0.3), lineWidth: 1)
                )
                .foregroundStyle(planBadgeColor)

            // Message
            Text(String(localized: "Thank you for supporting iMonet!"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(planBadgeColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(planBadgeColor.opacity(0.12), lineWidth: 1)
        )
    }

    private var planBadgeText: String {
        switch storeManager.purchasedProductID {
        case .yearly:  String(localized: "Yearly Support")
        case .lifetime: String(localized: "Lifetime Purchase")
        case nil: ""
        }
    }

    private var planBadgeColor: Color {
        switch storeManager.purchasedProductID {
        case .yearly:  .orange
        case .lifetime: .purple
        case nil: .accentColor
        }
    }
}

#Preview {
    GeneralSettingsPane(showPurchasePrompt: .constant(false))
}
