import SwiftUI

// MARK: - CommandSnippetsView

/// A panel view listing saved command snippets with send-to-terminal functionality.
///
/// Presented as a popover or sheet from the terminal toolbar.
/// Users can add, delete, and send snippets to the active SSH terminal.
struct CommandSnippetsView: View {

    @Environment(SnippetStore.self) private var snippetStore
    @Environment(TabManager.self) private var tabManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddForm = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Command Snippets")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if snippetStore.snippets.isEmpty {
                emptyState
            } else {
                snippetList
            }

            Divider()

            // Toolbar
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button {
                    showingAddForm = true
                } label: {
                    Label("Add Snippet", systemImage: "plus.circle")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 380, height: 360)
        .sheet(isPresented: $showingAddForm) {
            AddSnippetSheet { newSnippet in
                do {
                    try snippetStore.add(newSnippet)
                    errorMessage = nil
                } catch {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
        .task {
            do {
                try snippetStore.load()
                errorMessage = nil
            } catch {
                errorMessage = "Failed to load snippets: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No snippets saved")
                .foregroundStyle(.secondary)
            Text("Press \"+\" to create a reusable command snippet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var snippetList: some View {
        List {
            ForEach(snippetStore.snippets) { snippet in
                SnippetRowView(
                    snippet: snippet,
                    isSendEnabled: activeConnection != nil,
                    onSend: { sendSnippet(snippet) }
                )
            }
            .onDelete { offsets in
                deleteSnippets(at: offsets)
            }
        }
    }

    // MARK: - Helpers

    private var activeConnection: SSHConnection? {
        guard let activeTabId = tabManager.activeTabId,
              let tab = tabManager.tabs.first(where: { $0.id == activeTabId }),
              tab.connection.state == .connected else { return nil }
        return tab.connection
    }

    private func sendSnippet(_ snippet: CommandSnippet) {
        guard let connection = activeConnection,
              let terminalView = connection.terminalView else { return }
        let text = snippet.body.hasSuffix("\n") ? snippet.body : snippet.body + "\n"
        terminalView.send(txt: text)
    }

    private func deleteSnippets(at offsets: IndexSet) {
        let ids = offsets.map { snippetStore.snippets[$0].id }
        for id in ids {
            do {
                try snippetStore.remove(id: id)
                errorMessage = nil
            } catch {
                errorMessage = "Delete failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SnippetRowView

private struct SnippetRowView: View {
    let snippet: CommandSnippet
    let isSendEnabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.name)
                    .font(.body)
                Text(snippet.body)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSendEnabled ? Color.accentColor : Color.secondary)
            .disabled(!isSendEnabled)
            .help(isSendEnabled ? "Send to terminal" : "No active terminal connection")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AddSnippetSheet

private struct AddSnippetSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var snippetBody = ""

    var onAdd: (CommandSnippet) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Snippet")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            Form {
                TextField("Name", text: $name)
                    .help("A short label for this snippet")

                Section("Command") {
                    TextEditor(text: $snippetBody)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    let snippet = CommandSnippet(
                        name: name.trimmingCharacters(in: .whitespaces),
                        body: snippetBody
                    )
                    onAdd(snippet)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || snippetBody.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 320)
    }
}
