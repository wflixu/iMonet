//
//  ThumbnailSidebar.swift
//  Monet
//

import SwiftUI

struct ThumbnailSidebar: View {
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
        .background(Color.gray.opacity(0.6))
    }
}
