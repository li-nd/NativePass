import AppKit
import SwiftUI

enum StoreKeySetupMode: Equatable, Identifiable {
    case create
    case changeRoot
    case changeFolder(String)

    var id: String {
        switch self {
        case .create: "create"
        case .changeRoot: "changeRoot"
        case .changeFolder(let path): "changeFolder:\(path)"
        }
    }

    var title: String {
        switch self {
        case .create:
            return String(localized: "Create Password Store")
        case .changeRoot:
            return String(localized: "Change Encryption Keys")
        case .changeFolder(let path):
            return String(localized: "Change Keys for \(path)")
        }
    }

    var confirmsReencrypt: Bool {
        switch self {
        case .create: false
        case .changeRoot, .changeFolder: true
        }
    }

    var folderPath: String? {
        if case .changeFolder(let path) = self { return path }
        return nil
    }
}

struct StoreKeySetupSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let mode: StoreKeySetupMode
    var onFinished: (() -> Void)?

    @State private var storePath: String = ""
    @State private var initializeGit = false
    @State private var keys: [GPGKeyInfo] = []
    @State private var selectedKeyIDs: Set<String> = []
    @State private var isLoadingKeys = true
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var didConfirmReencrypt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                if case .create = mode {
                    Section("Location") {
                        HStack {
                            TextField("Store path", text: $storePath)
                            Button("Choose…") { pickDirectory() }
                        }
                        Text("Default: ~/.password-store")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Toggle("Initialize Git", isOn: $initializeGit)
                    } footer: {
                        Text("Creates a Git repository in the store so changes can be synced.")
                    }
                } else if mode.confirmsReencrypt {
                    Section {
                        Text(
                            "Existing passwords will be decrypted and re-encrypted for the selected keys. You need the current private key unlocked, and the public keys of all new recipients."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        Toggle("I understand passwords will be re-encrypted", isOn: $didConfirmReencrypt)
                    }
                }

                Section("GPG Keys") {
                    if isLoadingKeys {
                        ProgressView("Loading keys…")
                    } else if keys.isEmpty {
                        Text("No secret GPG keys found. Create a GPG key first, then try again.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(keys) { key in
                            Toggle(isOn: binding(for: key)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key.primaryUserID)
                                    Text(key.passInitID)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(isWorking)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isWorking)

                Spacer()

                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }

                Button(primaryButtonTitle) {
                    Task { await runAction() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit || isWorking)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 420)
        .navigationTitle(mode.title)
        #if os(macOS)
        .toolbarBackground(.visible, for: .windowToolbar)
        #endif
        .task {
            await loadInitialState()
        }
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .create: String(localized: "Create")
        case .changeRoot, .changeFolder: String(localized: "Re-encrypt")
        }
    }

    private var canSubmit: Bool {
        guard !selectedKeyIDs.isEmpty, !keys.isEmpty else { return false }
        if case .create = mode {
            return !storePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if mode.confirmsReencrypt {
            return didConfirmReencrypt
        }
        return true
    }

    private func binding(for key: GPGKeyInfo) -> Binding<Bool> {
        Binding(
            get: { selectedKeyIDs.contains(key.id) },
            set: { selected in
                if selected {
                    selectedKeyIDs.insert(key.id)
                } else {
                    selectedKeyIDs.remove(key.id)
                }
            }
        )
    }

    private func selectedPassIDs() -> [String] {
        keys.filter { selectedKeyIDs.contains($0.id) }.map(\.passInitID)
    }

    @MainActor
    private func loadInitialState() async {
        isLoadingKeys = true
        defer { isLoadingKeys = false }

        if case .create = mode {
            storePath = StoreRegistry.defaultStoreURL.path
        }

        let env = appState.environment.processEnvironment()
        keys = GPGKeyListing.listSecretKeys(
            gpgBinary: appState.environment.gpgBinary,
            environment: env
        )

        let preselect: [String]
        switch mode {
        case .create:
            preselect = []
        case .changeRoot:
            preselect = appState.encryptionMap.rootIDs
        case .changeFolder(let path):
            preselect = appState.encryptionMap.effective(forFolder: path).gpgIDs
        }

        if preselect.isEmpty, keys.count == 1, case .create = mode {
            selectedKeyIDs = [keys[0].id]
        } else {
            selectedKeyIDs = Set(
                keys.filter { key in
                    preselect.contains { GPGKeyListing.matches(key, id: $0) }
                }.map(\.id)
            )
        }
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: storePath.isEmpty ? NSHomeDirectory() : storePath)
        panel.prompt = String(localized: "Select")
        if panel.runModal() == .OK, let url = panel.url {
            storePath = url.path
        }
    }

    @MainActor
    private func runAction() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        let ids = selectedPassIDs()
        do {
            switch mode {
            case .create:
                let path = storePath.trimmingCharacters(in: .whitespacesAndNewlines)
                let url = URL(fileURLWithPath: path, isDirectory: true)
                try await appState.createStore(
                    at: url,
                    gpgIDs: ids,
                    initializeGit: initializeGit
                )
            case .changeRoot:
                try await appState.changeEncryptionKeys(gpgIDs: ids, folderPath: nil)
            case .changeFolder(let folder):
                try await appState.changeEncryptionKeys(gpgIDs: ids, folderPath: folder)
            }
            onFinished?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
