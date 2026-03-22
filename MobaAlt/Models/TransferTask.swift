import Foundation

// MARK: - TransferDirection

enum TransferDirection: Sendable {
    case upload
    case download
}

// MARK: - TransferStatus

/// Not Equatable — the `failed` case carries an `Error` which is not Equatable.
enum TransferStatus: Sendable {
    case pending
    case inProgress(fractionCompleted: Double)
    case completed
    case failed(Error)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

// MARK: - TransferProgress

struct TransferProgress: Sendable {
    let bytesTransferred: Int64
    let totalBytes: Int64

    var fractionCompleted: Double {
        Double(bytesTransferred) / Double(max(1, totalBytes))
    }
}

// MARK: - TransferTask

struct TransferTask: Identifiable, Sendable {
    let id: UUID
    let remotePath: String
    let localURL: URL
    let direction: TransferDirection
    var status: TransferStatus
}
