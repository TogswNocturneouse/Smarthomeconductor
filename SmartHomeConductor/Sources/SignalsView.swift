import SwiftUI

struct SignalsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(title: "Classifier pipeline", subtitle: "Sound, sensor and local bridge events")

                    VStack(spacing: 12) {
                        ForEach(store.signals) { signal in
                            SignalCard(signal: signal)
                        }
                    }

                    SectionHeader(title: "Sensor sources", subtitle: "First inputs for adaptive control")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Temp", value: "23.4 C", detail: "bedroom", symbol: "thermometer.medium")
                        MetricTile(title: "Humidity", value: "48%", detail: "stable", symbol: "humidity")
                        MetricTile(title: "Light", value: "318 lx", detail: "studio", symbol: "sun.max")
                        MetricTile(title: "AQI", value: "31", detail: "good", symbol: "wind")
                    }
                }
                .padding()
            }
            .background(AppStyle.background.ignoresSafeArea())
            .navigationTitle("Signals")
        }
    }
}

private struct SignalCard: View {
    let signal: SignalEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: signal.symbol)
                    .font(.title3)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading) {
                    Text(signal.title).font(.headline)
                    Text(signal.source).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(signal.confidence * 100))%")
                    .font(.headline)
            }

            ProgressView(value: signal.confidence)
                .tint(.teal)

            Text(signal.action)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
