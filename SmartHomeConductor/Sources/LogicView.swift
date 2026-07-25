import SwiftUI

struct LogicView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isAddingRule = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AutomationStatusBand()

                    SectionHeader(
                        title: "Rules",
                        subtitle: "Conditions and actions evaluated locally"
                    )

                    if store.rules.isEmpty {
                        EmptyStateView(
                            title: "No automations",
                            detail: "Create a rule from the add button.",
                            symbol: "point.3.connected.trianglepath.dotted"
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.rules) { rule in
                                RuleCard(rule: rule)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.clear)
            .navigationTitle("Automations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingRule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add automation")
                }
            }
            .sheet(isPresented: $isAddingRule) {
                AddAutomationView()
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
}

private struct AutomationStatusBand: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        GlassPanel(
            accent: store.enabledRuleCount > 0 ? AppStyle.cyan : AppStyle.secondaryText,
            isActive: store.enabledRuleCount > 0
        ) {
            HStack(spacing: 14) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title2)
                    .foregroundStyle(AppStyle.cyan)
                    .frame(width: 42, height: 42)
                    .background(AppStyle.cyan.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Automation engine")
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Text("\(store.enabledRuleCount) of \(store.rules.count) rules enabled")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                }

                Spacer()

                Pill("LOCAL", color: AppStyle.mint)
            }
        }
    }
}

private struct RuleCard: View {
    let rule: AutomationRule
    @EnvironmentObject private var store: AppStore

    var body: some View {
        GlassPanel(
            accent: AppStyle.cyan,
            isActive: rule.isEnabled,
            padding: 15
        ) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Toggle(
                        rule.title,
                        isOn: Binding(
                            get: { rule.isEnabled },
                            set: { _ in store.toggleRule(rule.id) }
                        )
                    )
                    .font(.headline)
                    .foregroundStyle(AppStyle.text)
                    .tint(AppStyle.cyan)

                    Button {
                        store.runRule(rule.id)
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(AppStyle.cyan)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.cyan))
                    .disabled(!rule.isEnabled)
                    .accessibilityLabel("Run \(rule.title)")
                }

                HStack(alignment: .top, spacing: 10) {
                    Text("IF")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppStyle.violet)
                        .frame(width: 34, alignment: .leading)
                    Text(rule.condition)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.text)
                }

                HStack(alignment: .top, spacing: 10) {
                    Text("THEN")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppStyle.mint)
                        .frame(width: 42, alignment: .leading)
                    Text(rule.action)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                }

                if let lastRun = rule.lastRun {
                    Label {
                        Text(lastRun, style: .relative)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                store.deleteRule(rule.id)
            } label: {
                Label("Delete automation", systemImage: "trash")
            }
        }
    }
}

private struct AddAutomationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var condition = ""
    @State private var action = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !condition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Automation name", text: $title)
                }
                Section("When") {
                    TextField("Condition", text: $condition, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Then") {
                    TextField("Action", text: $action, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("New Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addRule(
                            title: title,
                            condition: condition,
                            action: action
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
