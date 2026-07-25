import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section("Brand adapters") {
                    ForEach(store.brandAdapters) { adapter in
                        NavigationLink {
                            AdapterDetailView(adapter: adapter)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: adapter.symbol)
                                    .foregroundStyle(.teal)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(adapter.brand)
                                        .font(.headline)
                                    Text(adapter.ecosystem)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(adapter.stage.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(adapter.stage == .ready ? .green : .secondary)
                            }
                        }
                    }
                }

                Section("Bridge command plan") {
                    ForEach(store.bridgeCommands) { command in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(command.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(command.transport.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.teal)
                            }
                            Text(command.safetyNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Local intelligence") {
                    ForEach(store.classifierSlots) { classifier in
                        LabeledContent(classifier.name, value: classifier.modelFile)
                    }
                }
            }
            .navigationTitle("Integrations")
        }
    }
}

private struct AdapterDetailView: View {
    let adapter: BrandAdapterPlan

    var body: some View {
        List {
            Section("Connection plan") {
                Text(adapter.connectionPlan)
            }

            Section("Device families") {
                ForEach(adapter.deviceKinds) { kind in
                    Label(kind.rawValue, systemImage: kind.symbol)
                }
            }

            Section("Next action") {
                Text(adapter.nextAction)
            }
        }
        .navigationTitle(adapter.brand)
    }
}
