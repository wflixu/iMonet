//
//  ToolBarView.swift
//  Monet
//
//  Created by 李旭 on 2024/9/15.
//

import AppKit
import SwiftUI

struct ToolBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState

    let scale: CGSize

    let onTap: (_ actionID: ToolbarActionIdentifier) -> Void
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?
    
    var scaleFormated: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent // 设置百分比格式
        formatter.maximumFractionDigits = 0 // 保留小数位数（可选）
        formatter.minimumFractionDigits = 0 // 最少小数位数（可选）

        if let formattedString = formatter.string(from: NSNumber(value: scale.width)) {
            return formattedString
        } else {
            return ""
        }
    }
    
    var indexFormated: String {
        return "\(appState.selectedImageIndex + 1)/\(appState.imageFiles.count)"
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 缩放
            Button(action: {
                self.onTap(ToolbarActionIdentifier.scaleMinis)
            }) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Magnify the picture")

            Text(scaleFormated).foregroundStyle(.primary)

            Button(action: {
                self.onTap(.scalePlus)
            }) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Shrink the picture")

            Button(action: {
                self.onTap(.showPrev)
            }) {
                Image(systemName: "chevron.left.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Previous picture")

            Text(indexFormated).foregroundStyle(.primary)

            Button(action: {
                self.onTap(.showNext)
            }) {
                Image(systemName: "chevron.right.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Next picture")

            Button(action: {
                self.onTap(.centerFill)
            }) {
                Image(systemName: "rectangle.center.inset.filled")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Center Picture")

            Divider()
            Button(action: {
                self.onTap(.toggleNav)
            }) {
                Image(systemName: "square.leadingthird.inset.filled")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Toggle navigation")

            Button(action: {
                self.onTap(.toggleInfo)
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }.buttonStyle(PlainButtonStyle())
                .help("Toggle the picture info")
        }
        .padding([.leading, .trailing], 10)
        .padding([.top, .bottom], 8)
        .frame(height: 42)
        .background(colorScheme == .dark ? Color.gray.opacity(0.6) : Color.white.opacity(1))
        .cornerRadius(4)
        .shadow(radius: 2)
        .onHover { hovering in
            if hovering {
                onHoverEnter?()
            } else {
                onHoverExit?()
            }
        }
    }
}

enum ToolbarActionIdentifier: String, Hashable {
    case scaleMinis
    case scalePlus
    case showPrev
    case showNext
    case toggleNav
    case toggleInfo
    case centerFill
}

