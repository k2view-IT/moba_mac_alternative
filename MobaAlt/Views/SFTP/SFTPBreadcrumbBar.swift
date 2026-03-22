import SwiftUI

// MARK: - BreadcrumbSegment

/// A single segment in the breadcrumb bar path.
private struct BreadcrumbSegment: Identifiable {
    let id: Int
    let display: String
    let path: String
}

// MARK: - SFTPBreadcrumbBar

/// Clickable breadcrumb navigation bar showing the current remote path.
///
/// Each segment is a button that navigates to the partial path up to that segment.
/// The last (current) segment is displayed as bold non-interactive text.
struct SFTPBreadcrumbBar: View {

    let currentPath: String
    let onNavigate: (String) -> Void

    // MARK: - Computed segments

    /// Splits the path into BreadcrumbSegment values with stable ids.
    private var segments: [BreadcrumbSegment] {
        guard !currentPath.isEmpty else {
            return [BreadcrumbSegment(id: 0, display: "/", path: "/")]
        }

        var results: [BreadcrumbSegment] = []
        var index = 0

        if currentPath.hasPrefix("~") {
            let parts = currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
            results.append(BreadcrumbSegment(id: index, display: "~", path: "~"))
            index += 1
            var accumulated = "~"
            for part in parts {
                if part == "~" { continue }
                accumulated += "/\(part)"
                results.append(BreadcrumbSegment(id: index, display: part, path: accumulated))
                index += 1
            }
        } else {
            // Absolute path
            let parts = currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
            results.append(BreadcrumbSegment(id: index, display: "/", path: "/"))
            index += 1
            var accumulated = ""
            for part in parts {
                accumulated += "/\(part)"
                results.append(BreadcrumbSegment(id: index, display: part, path: accumulated))
                index += 1
            }
        }

        return results
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    segmentView(segment)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func segmentView(_ segment: BreadcrumbSegment) -> some View {
        let isLast = segment.id == segments.count - 1
        if isLast {
            // Current segment: bold, non-interactive
            Text(segment.display)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        } else {
            HStack(spacing: 2) {
                Button {
                    onNavigate(segment.path)
                } label: {
                    Text(segment.display)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
