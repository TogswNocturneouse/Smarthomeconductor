import SwiftUI

struct SignalsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var classifier: SoundClassifierController

    private let metricColumns = [
        GridItem(.adaptive(minimum: 140), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ClassifierPanel()

                    SectionHeader(
                        title: "Environmental sources",
                        subtitle: "Latest aggregated sensor values"
                    )

                    LazyVGrid(columns: metricColumns, spacing: 10) {
                        MetricTile(
                            title: "TEMPERATURE",
                            value: store.environmentalSummary.temperature
                                .map { String(format: "%.1f C", $0) } ?? "--",
                            detail: "sensor average",
                            symbol: "thermometer.medium",
                            accent: AppStyle.cyan
                        )
                        MetricTile(
                            title: "HUMIDITY",
                            value: store.environmentalSummary.humidity
                                .map { "\(Int($0))%" } ?? "--",
                            detail: store.environmentalSummary.healthLabel,
                            symbol: "humidity",
                            accent: AppStyle.violet
                        )
                        MetricTile(
                            title: "LIGHT",
                            value: store.environmentalSummary.illuminance
                                .map { "\(Int($0)) lx" } ?? "--",
                            detail: "ambient level",
                            symbol: "sun.max",
                            accent: AppStyle.amber
                        )
                        MetricTile(
                            title: "AIR QUALITY",
                            value: store.environmentalSummary.airQualityIndex
                                .map { "AQI \($0)" } ?? "--",
                            detail: "lower is cleaner",
                            symbol: "wind",
                            accent: AppStyle.mint
                        )
                    }

                    SectionHeader(
                        title: "Event stream",
                        subtitle: "Classifier, bridge, scene, and automation activity"
                    )

                    if store.signals.isEmpty {
                        EmptyStateView(
                            title: "No events yet",
                            detail: "Run a scene, command, or classifier sample.",
                            symbol: "waveform.path.ecg"
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.signals) { signal in
                                SignalCard(signal: signal)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.clear)
            .navigationTitle("Signals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.clearAcknowledgedSignals()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .disabled(!store.signals.contains(where: \.isAcknowledged))
                    .accessibilityLabel("Clear acknowledged events")
                }
            }
            .onChange(of: classifier.latestReading) { _, reading in
                guard let reading else { return }
                store.recordClassification(
                    label: reading.label,
                    confidence: reading.confidence
                )
            }
        }
    }
}

private struct ClassifierPanel: View {
    @EnvironmentObject private var classifier: SoundClassifierController

    private var accent: Color {
        classifier.state.isListening ? AppStyle.coral : AppStyle.violet
    }

    var body: some View {
        GlassPanel(
            accent: accent,
            isActive: classifier.state.isListening
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 13) {
                    SoundMeter(isActive: classifier.state.isListening)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sound classifier")
                            .font(.headline)
                            .foregroundStyle(AppStyle.text)
                        Text(classifier.state.title)
                            .font(.subheadline)
                            .foregroundStyle(
                                classifier.state.isListening
                                    ? AppStyle.coral
                                    : AppStyle.secondaryText
                            )
                    }

                    Spacer()

                    Pill(
                        classifier.modelIsBundled ? "CORE ML" : "MODEL MISSING",
                        color: classifier.modelIsBundled ? AppStyle.mint : AppStyle.coral
                    )
                }

                if let reading = classifier.latestReading {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Latest classification")
                                .font(.caption)
                                .foregroundStyle(AppStyle.secondaryText)
                            Text(reading.label)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppStyle.text)
                        }
                        Spacer()
                        Text("\(Int(reading.confidence * 100))%")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(accent)
                            .monospacedDigit()
                    }
                }

                if case .unavailable(let message) = classifier.state {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppStyle.amber)
                }

                if classifier.state == .permissionDenied {
                    Label(
                        "Enable microphone access in system privacy settings.",
                        systemImage: "mic.slash.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(AppStyle.amber)
                }

                HStack(spacing: 10) {
                    Button {
                        classifier.toggleListening()
                    } label: {
                        Label(
                            classifier.state.isListening ? "Stop" : "Listen",
                            systemImage: classifier.state.isListening
                                ? "stop.fill"
                                : "mic.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppStyle.text)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                    }
                    .buttonStyle(
                        GlassButtonStyle(
                            accent: accent,
                            isActive: classifier.state.isListening
                        )
                    )
                    .disabled(classifier.state == .requestingPermission)

                    Button {
                        classifier.emitDemoReading()
                    } label: {
                        Label("Sample event", systemImage: "waveform.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppStyle.text)
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                    }
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.cyan))
                }
            }
        }
    }
}

private struct SoundMeter: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(isActive ? AppStyle.coral : AppStyle.secondaryText.opacity(0.45))
                        .frame(
                            width: 3,
                            height: isActive
                                ? 10 + abs(sin(phase * 4 + Double(index))) * 23
                                : 11
                        )
                }
            }
            .frame(width: 36, height: 42)
        }
        .accessibilityHidden(true)
    }
}

private struct SignalCard: View {
    let signal: SignalEvent
    @EnvironmentObject private var store: AppStore

    private var accent: Color {
        signal.isAcknowledged ? AppStyle.secondaryText : AppStyle.coral
    }

    var body: some View {
        GlassPanel(
            accent: accent,
            isActive: !signal.isAcknowledged,
            padding: 14
        ) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: signal.symbol)
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 31)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(signal.title)
                                .font(.headline)
                                .foregroundStyle(AppStyle.text)
                            Text(signal.source)
                                .font(.caption)
                                .foregroundStyle(AppStyle.secondaryText)
                        }

                        Spacer()

                        Text("\(Int(signal.confidence * 100))%")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(accent)
                            .monospacedDigit()
                    }

                    ProgressView(value: signal.confidence)
                        .tint(accent)

                    HStack {
                        Text(signal.action)
                            .font(.caption)
                            .foregroundStyle(AppStyle.secondaryText)
                            .lineLimit(2)
                        Spacer()
                        Text(signal.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(AppStyle.secondaryText)
                    }
                }

                Button {
                    store.acknowledgeSignal(signal.id)
                } label: {
                    Image(
                        systemName: signal.isAcknowledged
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .foregroundStyle(signal.isAcknowledged ? AppStyle.mint : AppStyle.secondaryText)
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(signal.isAcknowledged)
                .accessibilityLabel(
                    signal.isAcknowledged ? "Acknowledged" : "Acknowledge event"
                )
            }
        }
    }
}
