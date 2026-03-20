import SwiftUI

struct SessionRowView: View {
    let session: SessionDefinition
    @Binding var selectedSessionId: UUID?
    var onEdit: () -> Void
    var onConnect: () -> Void

    @Environment(SessionLibrary.self) private var library
    @AppStorage("sidebarDensity") private var density: SidebarDensity = .comfortable
    @State private var isHovered = false

    private var protocolIconName: String {
        switch session.protocolConfig {
        case .ssh: return "terminal"
        case .rdp: return "desktopcomputer"
        case .vnc: return "eye"
        }
    }

    private var badgeColor: Color {
        switch session.protocolConfig {
        case .ssh: return .green
        case .rdp: return .blue
        case .vnc: return .orange
        }
    }

    private var verticalPadding: CGFloat {
        density == .compact ? 2 : 6
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: protocolIconName)
                .foregroundStyle(badgeColor)
                .frame(width: 16)
            Text(session.name)
                .lineLimit(1)
            Spacer()
            if isHovered {
                Text(session.protocolConfig.protocolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            print("[Phase 1] Connect: \(session.name)")
            onConnect()
        }
        .onTapGesture(count: 1) {
            selectedSessionId = session.id
        }
        .contextMenu {
            Button("Connect") {
                print("[Phase 1] Connect: \(session.name)")
                onConnect()
            }
            Button("Edit") {
                onEdit()
            }
            Button("Duplicate") {
                let copy = SessionDefinition(
                    id: UUID(),
                    name: session.name + " Copy",
                    folderId: session.folderId,
                    protocolConfig: session.protocolConfig,
                    notes: session.notes,
                    sortOrder: session.sortOrder + 1,
                    createdAt: Date()
                )
                library.addSession(copy)
            }
            Button("Delete", role: .destructive) {
                library.deleteSession(id: session.id)
            }
        }
        .onDrag {
            NSItemProvider(object: session.id.uuidString as NSString)
        }
    }
}
