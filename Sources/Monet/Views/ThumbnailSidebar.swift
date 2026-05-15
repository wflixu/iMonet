//
//  ThumbnailSidebar.swift
//  Monet
//

import SwiftUI

struct ThumbnailSidebar: View {
    @Environment(\.colorScheme) private var colorScheme

    let imageFiles: [URL]
    let selectedIndex: Int
    let windowHeight: CGFloat
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVStack {
                    ForEach(Array(imageFiles.enumerated()), id: \.offset) { index, imageURL in
                        ImageThumbnailView(imageURL: imageURL, isSelected: selectedIndex == index)
                            .id(index)
                            .onTapGesture { onSelect(index) }
                    }
                }
            }
            .scrollIndicators(.never)
            .padding(4)
            .onAppear { scroller.scrollTo(selectedIndex) }
            .onChange(of: selectedIndex) { _, new in scroller.scrollTo(new) }
        }
        .padding([.top], 28)
        .frame(width: 128, height: windowHeight)
        .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.8))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.gray.opacity(0.3))
                .frame(width: 1)
        }
    }
}
