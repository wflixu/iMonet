//
//  ImageThumbnailView.swift
//  Monet
//
//  Created by 李旭 on 2024/9/5.
//

import SwiftUI

struct ImageThumbnailView: View {
    @Environment(\.colorScheme) private var colorScheme

    let imageURL: URL
    let isSelected: Bool

    private var highlightColor: Color {
        colorScheme == .dark ? Color.yellow : Color.blue
    }

    var body: some View {
        HStack {
            if let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 90)
                    .clipShape(.rect(cornerRadius: 4))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(highlightColor, lineWidth: 3)
                        }
                    }
                    .scaleEffect(isSelected ? 1.06 : 1.0)
                    .shadow(color: isSelected ? .black.opacity(colorScheme == .dark ? 0.25 : 0.15) : .clear, radius: 6, x: 0, y: 3)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                    .frame(width: 120, height: 90)
                    .background(Color.clear)
            }
        }
    }
}


