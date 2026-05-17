//
//  AboutSettingsPane.swift
//  Monet
//
//  Created by 李旭 on 2024/9/13.
//

import SwiftUI

struct AboutSettingsPane: View {
    @Environment(\.openURL) private var openURL

    private var contributeURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/wflixu/Monet")!
    }

    private var issuesURL: URL {
        contributeURL.appendingPathComponent("issues")
    }

    var body: some View {
        VStack {
            Spacer()

            Image("Monet")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)

            Text("iMonet")
                .font(.largeTitle)
                .bold()

            HStack(spacing: 4) {
                Text("Version")
                Text(Constants.appVersion)
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Text("一款专注于高效浏览图片的查看器。支持鼠标焦点缩放，精准放大你关注的细节；打开图片时自动索引同文件夹所有图片，浏览无需重复操作。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .padding(.top, 8)

            Spacer()

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Actions

    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func openContribute() {
        openURL(contributeURL)
    }

    private func openIssues() {
        openURL(issuesURL)
    }

    // MARK: - Subviews

    private var bottomBar: some View {
        HStack {
            Button("Quit iMonet", action: quitApp)
            Spacer()
            Button("Contribute", action: openContribute)
            Button("Report a Bug", action: openIssues)
        }
        .padding()
    }
}

#Preview {
    AboutSettingsPane()
}
