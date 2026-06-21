//
//  SettingsView.swift
//  iMonet
//
//  Created by 李旭 on 2024/9/11.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsNavigationIdentifier = .general
    @State private var showPurchasePrompt = false

    var body: some View {
        ZStack {
            NavigationSplitView {
                sidebar
            } detail: {
                detailView
            }
            .navigationTitle(appState.settingsNavigationIdentifier.localized)
            .background(Color(NSColor.windowBackgroundColor))

            if showPurchasePrompt {
                PurchasePromptView(isPresented: $showPurchasePrompt)
                    .zIndex(100)
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            Task { @MainActor in
                appState.settingsNavigationIdentifier = newValue
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(SettingsNavigationIdentifier.allCases, id: \.self) { identifier in
                    sidebarItem(for: identifier)
                }
            } header: {
                HStack {
                    Image("iMonet")
                        .resizable()
                        .frame(width: 42, height: 42)

                    Text("iMonet")
                        .font(.system(size: 30, weight: .medium))
                }
                .foregroundStyle(.primary)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .collapsible(false)
        }
        .navigationSplitViewColumnWidth(210)
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.settingsNavigationIdentifier {
        case .general:
            GeneralSettingsPane(showPurchasePrompt: $showPurchasePrompt)
        case .about:
            AboutSettingsPane()
        }
    }

    @ViewBuilder
    private func sidebarItem(for identifier: SettingsNavigationIdentifier) -> some View {
        HStack(spacing: 6) {
            icon(for: identifier).view
                .font(.system(size: 16))
                .frame(width: 20)
            Text(identifier.localized)
                .font(.title3)
        }
        .padding(.vertical, 8)
        .padding(.leading, 4)
    }

    private func icon(for identifier: SettingsNavigationIdentifier) -> IconResource {
        switch identifier {
        case .general: .systemSymbol("gearshape")
        case .about: .systemSymbol("info.circle")
        }
    }
}
