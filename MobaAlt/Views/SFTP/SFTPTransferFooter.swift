import SwiftUI

// MARK: - SFTPTransferFooter

/// Non-blocking transfer progress footer rendered at the bottom of the SFTP panel.
///
/// - When no transfers are active: shows nothing (zero-height).
/// - Single active transfer: slim 32pt bar with filename and linear ProgressView.
/// - Multiple active transfers: scrollable list capped at 3 rows plus a summary line.
struct SFTPTransferFooter: View {

    let service: SFTPBrowserService

    // MARK: - Computed helpers

    /// Transfers that are still in flight (excludes completed and failed).
    private var activeTransfers: [TransferTask] {
        service.transfers.filter {
            if $0.status.isCompleted { return false }
            if $0.status.isFailed { return false }
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        if activeTransfers.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                Divider()
                if activeTransfers.count == 1, let transfer = activeTransfers.first {
                    singleTransferRow(transfer)
                        .frame(height: 32)
                        .padding(.horizontal, 8)
                        .background(Color(nsColor: .windowBackgroundColor))
                } else {
                    multiTransferList
                        .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
    }

    // MARK: - Single transfer row

    @ViewBuilder
    private func singleTransferRow(_ transfer: TransferTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: transfer.direction == .upload ? "arrow.up.to.line" : "arrow.down.to.line")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Text((transfer.localURL.lastPathComponent))
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressView(value: fractionCompleted(transfer), total: 1.0)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .frame(width: 100)
        }
    }

    // MARK: - Multi-transfer list

    @ViewBuilder
    private var multiTransferList: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(activeTransfers) { transfer in
                        HStack(spacing: 8) {
                            Image(systemName: transfer.direction == .upload ? "arrow.up.to.line" : "arrow.down.to.line")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Text(transfer.localURL.lastPathComponent)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ProgressView(value: fractionCompleted(transfer), total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.accentColor)
                                .frame(width: 80)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 96)

            // Summary line
            HStack {
                Text("\(activeTransfers.count) transfers in progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func fractionCompleted(_ transfer: TransferTask) -> Double {
        if case .inProgress(let f) = transfer.status { return f }
        return 0
    }
}
