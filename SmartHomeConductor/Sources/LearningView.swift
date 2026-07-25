import SwiftData
import SwiftUI

struct LearningView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LearnedRecord.updatedAt, order: .reverse) private var records: [LearnedRecord]

    @State private var selectedKind: LearnedRecordKind = .memoryFact
    @State private var title = ""
    @State private var detail = ""
    @State private var includeUnconfirmed = true

    private var filteredRecords: [LearnedRecord] {
        records.filter { includeUnconfirmed || $0.isConfirmed }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(
                        title: "Teach Conductor",
                        subtitle: "Inspect and edit what the assistant is allowed to remember"
                    )

                    GlassPanel(accent: AppStyle.mint) {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Record type", selection: $selectedKind) {
                                ForEach(LearnedRecordKind.allCases) { kind in
                                    Label(kind.rawValue, systemImage: kind.symbol)
                                        .tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)

                            TextField("Short title", text: $title)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(AppStyle.surface.opacity(0.68))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            TextField("What should Conductor remember?", text: $detail, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3...7)
                                .padding(12)
                                .background(AppStyle.surface.opacity(0.68))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button {
                                addRecord()
                            } label: {
                                Label("Add memory", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppStyle.text)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(GlassButtonStyle(accent: AppStyle.mint))
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    HStack {
                        SectionHeader(
                            title: "Memory",
                            subtitle: "\(records.count) learned records"
                        )
                        Spacer()
                        Toggle("Drafts", isOn: $includeUnconfirmed)
                            .labelsHidden()
                            .tint(AppStyle.violet)
                    }

                    if filteredRecords.isEmpty {
                        EmptyMemoryPanel()
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredRecords) { record in
                                LearnedRecordRow(record: record)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.clear)
            .navigationTitle("Teach")
        }
    }

    private func addRecord() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        modelContext.insert(
            LearnedRecord(
                kind: selectedKind,
                title: trimmedTitle,
                detail: trimmedDetail.isEmpty ? trimmedTitle : trimmedDetail
            )
        )

        title = ""
        detail = ""
        try? modelContext.save()
    }

}

private struct LearnedRecordRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var record: LearnedRecord

    var body: some View {
        GlassPanel(
            accent: record.isConfirmed ? AppStyle.mint : AppStyle.amber,
            isActive: record.isConfirmed,
            padding: 14
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: record.kind.symbol)
                        .foregroundStyle(record.isConfirmed ? AppStyle.mint : AppStyle.amber)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppStyle.text)
                        Text(record.kind.rawValue)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppStyle.secondaryText)
                    }

                    Spacer()

                    Toggle("Confirmed", isOn: Binding(
                        get: { record.isConfirmed },
                        set: { value in
                            record.isConfirmed = value
                            record.updatedAt = .now
                            try? modelContext.save()
                        }
                    ))
                    .labelsHidden()
                    .tint(AppStyle.mint)
                }

                Text(record.detail)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(record.updatedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(AppStyle.secondaryText.opacity(0.82))
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct EmptyMemoryPanel: View {
    var body: some View {
        GlassPanel(accent: AppStyle.violet) {
            VStack(alignment: .leading, spacing: 8) {
                Label("No learned records yet", systemImage: "brain")
                    .font(.headline)
                    .foregroundStyle(AppStyle.text)
                Text("Use the assistant phrases remember, prefer, never, or feedback, or add a record here.")
                    .font(.footnote)
                    .foregroundStyle(AppStyle.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
