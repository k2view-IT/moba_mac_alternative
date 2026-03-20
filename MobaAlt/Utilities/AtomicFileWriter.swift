import Foundation

/// Writes data atomically to a URL.
///
/// Using `Data.write(to:options:.atomic)` ensures the file is either fully
/// written or unchanged — no partial writes. This utility exists for semantic
/// clarity and future extension (e.g., encryption support in Phase 2).
func atomicWrite(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
}
