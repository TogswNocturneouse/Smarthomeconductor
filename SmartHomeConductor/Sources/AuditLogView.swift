import SwiftUI

struct AuditLogView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var showClearConfirmation = false

    private var records: [CommandAuditRecord] {
        guard !searchText.isEmpty else {
            return store.commandAudits
        }
        return store.commandAudits.filter {
            $0.deviceName.localizedCaseInsensitiveContains(searchText) ||
            $0.command.localizedCaseInsensitiveContains(searchText) ||
            $0.origin.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.outcome.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Command Audits" : "No Matching Audits",
                        systemImage: "checklist",
                        description: Text(
                            searchText.isEmpty
                                ? "Physical command decisions will appear here."
                                : "Try a different device, command, origin, or outcome."
                        )
                    )
                } else {
                    List(records) { record in
                        AuditRecordRow(record: record)
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Command Audit")
            .searchable(text: $searchText, prompt: "Device, command, or outcome")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(store.commandAudits.isEmpty)
                    .help("Clear command audit")
                }
            }
            .confirmationDialog(
                "Clear the command audit?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Audit", role: .destructive) {
                    store.clearCommandAudits()
                }
            } message: {
                Text("This removes local command decision records from this home.")
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .preferredColorScheme(.dark)
    }
}

private struct AuditRecordRow: View {
    let record: CommandAuditRecord

    private var accent: Color {
        switch record.outcome {
        case .localStateUpdated, .deviceConfirmed:
            AppStyle.mint
        case .confirmationRequired:
            AppStyle.amber
        case .rejected, .transportUnavailable:
            AppStyle.coral
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusDot(color: accent)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(record.command)
                        .font(.headline)
                    Spacer()
                    Text(record.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                }

                Text("\(record.deviceName) · \(record.origin.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.secondaryText)

                Text(record.detail)
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Pill(record.outcome.rawValue, color: accent)
        }
        .padding(.vertical, 5)
    }
}
