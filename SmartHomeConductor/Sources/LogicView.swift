import SwiftUI

struct LogicView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "Automation engine", subtitle: "Rules now, adaptive intelligence later")

                    VStack(spacing: 12) {
                        ForEach(store.rules) { rule in
                            RuleCard(rule: rule)
                        }
                    }

                    SectionHeader(title: "Recommended architecture", subtitle: "Keep every brand behind adapters")

                    VStack(spacing: 10) {
                        ArchitectureRow(title: "Device adapters", detail: "HomeKit, Matter, MQTT, IR, RF and vendor integrations")
                        ArchitectureRow(title: "Capability model", detail: "Power, brightness, color, sensors, media, camera and climate")
                        ArchitectureRow(title: "Automation core", detail: "IF signal + context THEN action chain")
                        ArchitectureRow(title: "Local-first privacy", detail: "Classifier and bridge logic should run on device when possible")
                    }
                }
                .padding()
            }
            .background(AppStyle.background.ignoresSafeArea())
            .navigationTitle("Logic")
        }
    }
}

private struct RuleCard: View {
    let rule: AutomationRule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(rule.title).font(.headline)
                Spacer()
                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                    .foregroundStyle(rule.isEnabled ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("IF \(rule.condition)")
                    .font(.subheadline.weight(.semibold))
                Text("THEN \(rule.action)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ArchitectureRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
