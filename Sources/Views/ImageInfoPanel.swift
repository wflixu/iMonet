//
//  ImageInfoPanel.swift
//  iMonet
//

import SwiftUI

struct ImageInfoPanel: View {
    @Environment(\.colorScheme) private var colorScheme

    let imageURL: URL?
    let windowHeight: CGFloat
    let onClose: () -> Void

    private var infoItems: [(String, String)] {
        guard let url = imageURL else { return [] }
        let fileManager = FileManager.default

        let name = url.lastPathComponent
        let format = url.pathExtension.uppercased()

        var items: [(String, String)] = [
            (String(localized: "名称"), name),
            (String(localized: "格式"), format),
        ]

        if let attrs = try? fileManager.attributesOfItem(atPath: url.path) {
            if let fileSize = attrs[.size] as? Int64 {
                items.append((String(localized: "大小"), formatBytes(fileSize)))
            }
            if let modDate = attrs[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/MM/dd HH:mm"
                items.append((String(localized: "修改时间"), formatter.string(from: modDate)))
            }
        }

        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = props[kCGImagePropertyPixelWidth] as? Int,
           let height = props[kCGImagePropertyPixelHeight] as? Int {
            items.insert((String(localized: "像素"), "\(width) × \(height)"), at: 1)
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("信息")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 12)

            // Info items
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(infoItems, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 260, height: windowHeight)
        .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.9))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.gray.opacity(0.3))
                .frame(width: 1)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
