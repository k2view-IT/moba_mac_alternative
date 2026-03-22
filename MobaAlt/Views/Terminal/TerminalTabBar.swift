import SwiftUI

// MARK: - TerminalTabBar

/// A custom scrollable/closable tab bar for terminal sessions.
///
/// Uses ScrollView + HStack — NOT NSTabView or SwiftUI.TabView.
/// Tab height: 32pt with .regularMaterial background.
struct TerminalTabBar: View {
    @Bindable var tabManager: TabManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabManager.tabs) { tab in
                    TabBarItem(
                        tab: tab,
                        isActive: tab.id == tabManager.activeTabId,
                        onSelect: { tabManager.activateTab(tab.id) },
                        onClose:  { tabManager.closeTab(tab.id) }
                    )
                }
            }
        }
        .frame(height: 32)
        .background(.regularMaterial)
    }
}

// MARK: - TabBarItem

/// A single tab item in the terminal tab bar.
private struct TabBarItem: View {
    let tab: TabItem
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tab.displayName.count > 20 ? String(tab.displayName.prefix(20)) : tab.displayName)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
    }
}
