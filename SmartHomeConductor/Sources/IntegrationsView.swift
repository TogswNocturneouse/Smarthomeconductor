import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "Brand adapters", subtitle: "Perfect integrations start as isolated, testable gateways")

                    VStack(spacing: 12) {
                        ForEach(store.brandAdapters) { adapter in
                            BrandAdapterCard(adapter: adapter)
                        }
                    }

                    SectionHeader(title: "RF / IR bridge", subtitle: "Legacy and analog command layer")

                    VStack(spacing: 12) {
                        ForEach(store.bridgeCommands) { command in
                            BridgeCommandCard(command: command)
                        }
                    }

                    SectionHeader(title: "Classifier slots", subtitle: "Your model work plugs in here")

                    VStack(spacing: 12) {
                        ForEach(store.classifierSlots) { slot in
                            ClassifierSlotCard(slot: slot)
                        }
                    }
                }
                .padding()
            }
            .background(AppStyle.background.ignoresSafeArea())
            .navigationTitle("Integrations")
        }
    }
}

private struct BrandAdapterCard: View {
    let adapter: BrandAdapterPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: adapter.symbol)
                    .font(.title3)
                    .foregroundStyle(.teal)
                    .frame(width: 36, height: 36)
                    .background(Color.teal.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(adapter.brand).font(.headline)
                    Text(adapter.ecosystem).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Text(adapter.stage.rawValue)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(stageColor.opacity(0.14))
                    .foregroundStyle(stageColor)
                    .clipShape(Capsule())
            }

            FlowTagRow(items: adapter.deviceKinds.map(\.rawValue))

            Text(adapter.connectionPlan)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(adapter.nextAction, systemImage: "arrow.forward.circle")
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var stageColor: Color {
        switch adapter.stage {
        case .ready: .green
        case .scaffolded: .teal
        case .planned: .orange
        }
    }
}

private struct BridgeCommandCard: View {
    let command: BridgeCommand

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(command.name, systemImage: command.transport == .infrared ? "sensor.tag.radiowaves.forward" : "dot.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                Text(command.transport.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Target", value: command.target)
            LabeledContent("Payload", value: command.payload)

            Label(command.safetyNote, systemImage: "shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ClassifierSlotCard: View {
    let slot: ClassifierSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(slot.name, systemImage: "waveform").font(.headline)
                Spacer()
                Text(slot.modelFile).font(.caption).foregroundStyle(.secondary)
            }

            Text(slot.input).font(.subheadline).foregroundStyle(.secondary)
            FlowTagRow(items: slot.outputs)
            Text(slot.nextAction).font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FlowTagRow: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
    }
}
