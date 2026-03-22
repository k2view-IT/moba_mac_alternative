import Foundation

/// Controls where the SFTP file browser panel appears relative to the terminal.
enum SFTPPanelPosition: String, CaseIterable, Sendable {
    case left
    case right
    case bottom
    case hidden

    /// Human-readable label used in Preferences UI.
    var displayName: String {
        switch self {
        case .left:   return "Left"
        case .right:  return "Right"
        case .bottom: return "Bottom"
        case .hidden: return "Hidden"
        }
    }
}
