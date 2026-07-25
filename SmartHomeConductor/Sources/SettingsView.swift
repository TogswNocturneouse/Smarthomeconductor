import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var classifier: SoundClassifierController
    @State private var showResetConfirmation = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument = ConductorConfigurationDocument()
    @State private var operationError: SettingsOperationError?

    private let columns = [
        GridItem(.adaptive(minimum: 250), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Runtime",
                        subtitle: "Privacy and endpoint visibility"
                    )

                    GlassPanel(accent: AppStyle.amber) {
                        VStack(spacing: 16) {
                            Toggle(
                                "Local processing only",
                                isOn: Binding(
                                    get: { store.preferences.localProcessingOnly },
                                    set: { value in
                                        store.updatePreferences {
                                            $0.localProcessingOnly = value
                                        }
                                    }
                                )
                            )
                            .tint(AppStyle.mint)

                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 0.7)

                            Toggle(
                                "Show offline devices",
                                isOn: Binding(
                                    get: { store.preferences.showOfflineDevices },
                                    set: { value in
                                        store.updatePreferences {
                                            $0.showOfflineDevices = value
                                        }
                                    }
                                )
                            )
                            .tint(AppStyle.cyan)

                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 0.7)

                            Toggle(
                                "Restrained visuals",
                                isOn: Binding(
                                    get: { store.preferences.reducedGlow },
                                    set: { value in
                                        store.updatePreferences {
                                            $0.reducedGlow = value
                                        }
                                    }
                                )
                            )
                            .tint(AppStyle.violet)

                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 0.7)

                            Toggle(
                                "Allow assistant light control",
                                isOn: Binding(
                                    get: { store.preferences.assistantLightControlAllowed },
                                    set: { value in
                                        store.updatePreferences {
                                            $0.assistantLightControlAllowed = value
                                        }
                                    }
                                )
                            )
                            .tint(AppStyle.mint)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                    }

                    SectionHeader(
                        title: "Apple frameworks",
                        subtitle: "Runtime services and adapter boundaries"
                    )

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.frameworks) { framework in
                            FrameworkStatusRow(framework: framework)
                        }
                    }

                    SectionHeader(
                        title: "Local data",
                        subtitle: "User-owned inventory and local app state"
                    )

                    GlassPanel(accent: AppStyle.coral) {
                        VStack(spacing: 14) {
                            LabeledContent("Devices", value: "\(store.devices.count)")
                            LabeledContent("Automations", value: "\(store.rules.count)")
                            LabeledContent("Events", value: "\(store.signals.count)")
                            LabeledContent("Command audits", value: "\(store.commandAudits.count)")
                            LabeledContent("Persistence", value: store.persistenceMode.rawValue)
                            LabeledContent(
                                "Sound model",
                                value: classifier.modelIsBundled ? "Bundled" : "Missing"
                            )

                            if let persistenceIssue = store.persistenceIssue {
                                Label(persistenceIssue, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(AppStyle.amber)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    exportHome()
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(GlassButtonStyle(accent: AppStyle.mint))

                                Button {
                                    isImporting = true
                                } label: {
                                    Label("Import", systemImage: "square.and.arrow.down")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(GlassButtonStyle(accent: AppStyle.cyan))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button(role: .destructive) {
                                showResetConfirmation = true
                            } label: {
                                Label("Clear this home", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppStyle.coral)
                                    .padding(.horizontal, 13)
                                    .frame(height: 42)
                            }
                            .buttonStyle(GlassButtonStyle(accent: AppStyle.coral))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(AppStyle.text)
                    }

                    Link(
                        destination: URL(
                            string: "https://github.com/TogswNocturneouse/Smarthomeconductor"
                        )!
                    ) {
                        HStack {
                            Label("Source repository", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppStyle.text)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(AppStyle.secondaryText)
                        }
                        .padding(15)
                    }
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.violet))
                }
                .padding(16)
            }
            .background(Color.clear)
            .navigationTitle("Settings")
            .alert("Clear this home?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    classifier.stop()
                    store.clearHome()
                }
            } message: {
                Text("This removes all device records, rules, and events stored by Conductor on this device.")
            }
            .alert(item: $operationError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Conductor-Home"
            ) { result in
                if case let .failure(error) = result {
                    operationError = SettingsOperationError(
                        title: "Export failed",
                        message: error.localizedDescription
                    )
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let url = try result.get().first.unwrap(
                        or: CocoaError(.fileNoSuchFile)
                    )
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer {
                        if scoped {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    try store.importConfiguration(Data(contentsOf: url))
                } catch {
                    operationError = SettingsOperationError(
                        title: "Import failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func exportHome() {
        do {
            exportDocument = ConductorConfigurationDocument(
                data: try store.exportConfiguration()
            )
            isExporting = true
        } catch {
            operationError = SettingsOperationError(
                title: "Export failed",
                message: error.localizedDescription
            )
        }
    }
}

private struct SettingsOperationError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
        guard let self else {
            throw error()
        }
        return self
    }
}

private struct FrameworkStatusRow: View {
    let framework: FrameworkPlan

    private var accent: Color {
        switch framework.status {
        case "Active": AppStyle.mint
        case "Adapter": AppStyle.cyan
        default: AppStyle.amber
        }
    }

    var body: some View {
        GlassPanel(
            accent: accent,
            isActive: framework.status == "Active",
            padding: 14
        ) {
            HStack(spacing: 12) {
                Image(systemName: framework.symbol)
                    .foregroundStyle(accent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(framework.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                    Text(framework.purpose)
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Pill(framework.status, color: accent)
            }
        }
    }
}
