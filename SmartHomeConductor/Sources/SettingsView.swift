import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section("Apple framework plan") {
                    ForEach(store.frameworks) { framework in
                        HStack(spacing: 12) {
                            Image(systemName: framework.symbol)
                                .foregroundStyle(.teal)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(framework.name).font(.headline)
                                Text(framework.purpose).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(framework.status)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(framework.status == "Active" ? .green : .secondary)
                        }
                    }
                }

                Section("Git and access recommendation") {
                    Text("Use one main repository with protected main branch, feature branches for experiments, and forks only for outside contributors or risky hardware integrations.")
                    Text("Keep hardware secrets, Wi-Fi credentials, API tokens, camera URLs and model datasets out of git.")
                }

                Section("Next build steps") {
                    Text("1. Add real HomeKit permission flow.")
                    Text("2. Add adapter protocols for every device family.")
                    Text("3. Add local bridge API shape for RF and IR.")
                    Text("4. Add sound classifier import slot for Core ML.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
