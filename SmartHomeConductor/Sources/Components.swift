import SwiftUI

enum AppStyle {
    static let canvas = Color(red: 0.025, green: 0.032, blue: 0.032)
    static let surface = Color(red: 0.075, green: 0.088, blue: 0.086)
    static let surfaceRaised = Color(red: 0.105, green: 0.115, blue: 0.112)
    static let text = Color(red: 0.94, green: 0.96, blue: 0.95)
    static let secondaryText = Color(red: 0.61, green: 0.66, blue: 0.64)
    static let mint = Color(red: 0.31, green: 0.94, blue: 0.72)
    static let cyan = Color(red: 0.31, green: 0.78, blue: 0.96)
    static let amber = Color(red: 0.98, green: 0.72, blue: 0.30)
    static let coral = Color(red: 0.96, green: 0.42, blue: 0.45)
    static let violet = Color(red: 0.72, green: 0.58, blue: 0.96)

    static let background = LinearGradient(
        colors: [
            canvas,
            Color(red: 0.035, green: 0.060, blue: 0.055),
            Color(red: 0.060, green: 0.043, blue: 0.057)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func accent(for kind: DeviceKind) -> Color {
        switch kind {
        case .normalLight, .dimmerLight, .colorLight, .lightSensor:
            amber
        case .climateSensor, .airConditioner:
            cyan
        case .smartHub, .smartTV:
            violet
        case .camera:
            coral
        case .purifier:
            mint
        }
    }

    static func color(named name: String) -> Color {
        switch name.lowercased() {
        case "amber": amber
        case "blue": cyan
        case "green": mint
        case "rose": coral
        case "violet": violet
        default: text
        }
    }
}

struct AppBackground: View {
    var body: some View {
        AppStyle.background
            .ignoresSafeArea()
            .overlay {
                Rectangle()
                    .fill(Color.black.opacity(0.10))
                    .ignoresSafeArea()
            }
    }
}

struct GlassPanel<Content: View>: View {
    private let accent: Color
    private let isActive: Bool
    private let padding: CGFloat
    private let content: Content

    @State private var isHovering = false

    init(
        accent: Color = AppStyle.mint,
        isActive: Bool = false,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.isActive = isActive
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                glassBackground(
                    accent: accent,
                    emphasized: isHovering || isActive,
                    pressed: false
                )
            }
            .overlay(alignment: .topTrailing) {
                if isActive {
                    StatusDot(color: accent)
                        .padding(11)
                }
            }
            .shadow(
                color: accent.opacity(isActive ? 0.12 : (isHovering ? 0.10 : 0)),
                radius: isActive ? 13 : 10
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.16), value: isHovering)
            .animation(.easeOut(duration: 0.16), value: isActive)
    }
}

struct GlassButtonStyle: ButtonStyle {
    var accent: Color = AppStyle.mint
    var isActive = false
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        GlassButtonBody(
            configuration: configuration,
            accent: accent,
            isActive: isActive,
            cornerRadius: cornerRadius
        )
    }
}

private struct GlassButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let accent: Color
    let isActive: Bool
    let cornerRadius: CGFloat

    @Environment(\.isFocused) private var isFocused
    @State private var isHovering = false

    private var emphasized: Bool {
        isHovering || isFocused || isActive
    }

    var body: some View {
        configuration.label
            .background {
                glassBackground(
                    accent: accent,
                    emphasized: emphasized,
                    pressed: configuration.isPressed,
                    cornerRadius: cornerRadius
                )
            }
            .overlay(alignment: .topTrailing) {
                if isActive {
                    StatusDot(color: accent)
                        .padding(9)
                }
            }
            .shadow(
                color: accent.opacity(
                    configuration.isPressed
                        ? 0.08
                        : (emphasized ? 0.16 : 0)
                ),
                radius: configuration.isPressed ? 3 : 12
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: emphasized)
    }
}

@ViewBuilder
private func glassBackground(
    accent: Color,
    emphasized: Bool,
    pressed: Bool,
    cornerRadius: CGFloat = 8
) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    shape
        .fill(.ultraThinMaterial)
        .overlay {
            shape.fill(
                pressed
                    ? AppStyle.surfaceRaised.opacity(0.76)
                    : AppStyle.surface.opacity(0.68)
            )
        }
        .overlay {
            shape.stroke(
                emphasized || pressed
                    ? accent.opacity(pressed ? 0.58 : 0.42)
                    : Color.white.opacity(0.10),
                lineWidth: emphasized || pressed ? 1.15 : 0.7
            )
        }
        .overlay {
            if pressed {
                shape
                    .inset(by: 2)
                    .stroke(accent.opacity(0.16), lineWidth: 2)
                    .blur(radius: 2)
            }
        }
}

struct StatusDot: View {
    var color: Color = AppStyle.mint

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay {
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 4)
                    .blur(radius: 2)
            }
            .shadow(color: color.opacity(0.75), radius: 5)
            .accessibilityHidden(true)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppStyle.text)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Pill: View {
    let title: String
    var color: Color = AppStyle.mint

    init(_ title: String, color: Color = AppStyle.mint) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.11))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.16), lineWidth: 0.6)
            }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    var accent: Color = AppStyle.mint

    var body: some View {
        GlassPanel(accent: accent, padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.secondaryText)
                    Spacer()
                    Image(systemName: symbol)
                        .foregroundStyle(accent)
                }

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppStyle.text)
                    .monospacedDigit()

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppStyle.secondaryText)
            }
        }
    }
}

struct DeviceCard: View {
    let device: SmartDevice

    var body: some View {
        let accent = AppStyle.accent(for: device.kind)

        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                DeviceIcon(kind: device.kind, isOnline: device.isOnline)

                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(AppStyle.text)
                    Text("\(device.room) - \(device.manufacturer)")
                        .font(.caption)
                        .foregroundStyle(AppStyle.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppStyle.secondaryText)
            }

            HStack(spacing: 6) {
                ForEach(device.capabilities.prefix(3)) { capability in
                    Pill(capability.rawValue, color: accent)
                }
            }

            ReadingStrip(device: device)
        }
        .padding(15)
    }
}

struct DeviceIcon: View {
    let kind: DeviceKind
    let isOnline: Bool

    var body: some View {
        let accent = AppStyle.accent(for: kind)

        ZStack(alignment: .bottomTrailing) {
            Image(systemName: kind.symbol)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 0.7)
                }

            StatusDot(color: isOnline ? AppStyle.mint : AppStyle.secondaryText)
                .padding(1)
        }
    }
}

struct ReadingStrip: View {
    let device: SmartDevice

    var body: some View {
        HStack(spacing: 12) {
            if let brightness = device.brightness {
                Label("\(Int(brightness))%", systemImage: "sun.max")
            }
            if let colorName = device.colorName {
                Label(colorName, systemImage: "paintpalette")
            }
            if let temperature = device.temperature {
                Label(String(format: "%.1f C", temperature), systemImage: "thermometer.medium")
            }
            if let humidity = device.humidity {
                Label("\(Int(humidity))%", systemImage: "humidity")
            }
            if let lux = device.lux {
                Label("\(Int(lux)) lx", systemImage: "sun.min")
            }
            if let airQualityIndex = device.airQualityIndex {
                Label("AQI \(airQualityIndex)", systemImage: "wind")
            }
            if let batteryLevel = device.batteryLevel {
                Label("\(batteryLevel)%", systemImage: "battery.75percent")
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(AppStyle.secondaryText)
        .lineLimit(1)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppStyle.text : AppStyle.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 36)
        }
        .buttonStyle(
            GlassButtonStyle(
                accent: AppStyle.mint,
                isActive: isSelected,
                cornerRadius: 7
            )
        )
    }
}

struct TagGrid: View {
    let items: [String]
    var color: Color = AppStyle.mint

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 86), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(items, id: \.self) { item in
                Pill(item, color: color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct EnvironmentSummaryBar: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var classifier: SoundClassifierController

    private var summary: EnvironmentalSummary {
        store.environmentalSummary
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                HStack(spacing: 9) {
                    StatusDot(color: summary.isHealthy ? AppStyle.mint : AppStyle.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.healthLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppStyle.text)
                        Text("\(summary.onlineSensors) sensors online")
                            .font(.caption2)
                            .foregroundStyle(AppStyle.secondaryText)
                    }
                }
                .frame(minWidth: 148, alignment: .leading)
                .padding(.trailing, 15)

                EnvironmentDivider()

                EnvironmentMetric(
                    label: "TEMP",
                    value: summary.temperature.map { String(format: "%.1f C", $0) } ?? "--",
                    symbol: "thermometer.medium",
                    color: AppStyle.cyan
                )
                EnvironmentDivider()
                EnvironmentMetric(
                    label: "HUMIDITY",
                    value: summary.humidity.map { "\(Int($0))%" } ?? "--",
                    symbol: "humidity",
                    color: AppStyle.violet
                )
                EnvironmentDivider()
                EnvironmentMetric(
                    label: "LIGHT",
                    value: summary.illuminance.map { "\(Int($0)) lx" } ?? "--",
                    symbol: "sun.max",
                    color: AppStyle.amber
                )
                EnvironmentDivider()
                EnvironmentMetric(
                    label: "AIR",
                    value: summary.airQualityIndex.map { "AQI \($0)" } ?? "--",
                    symbol: "wind",
                    color: AppStyle.mint
                )
                EnvironmentDivider()
                EnvironmentMetric(
                    label: "SOUND",
                    value: classifier.state.isListening ? "Live" : "Ready",
                    symbol: "waveform",
                    color: classifier.state.isListening ? AppStyle.coral : AppStyle.secondaryText
                )
            }
            .padding(.horizontal, 16)
            .frame(height: 66)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(AppStyle.surface.opacity(0.82))
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.11))
                .frame(height: 0.7)
        }
        .shadow(color: AppStyle.mint.opacity(0.05), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }
}

private struct EnvironmentMetric: View {
    let label: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppStyle.secondaryText)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.text)
                    .monospacedDigit()
            }
        }
        .frame(minWidth: 94, alignment: .leading)
        .padding(.horizontal, 14)
    }
}

private struct EnvironmentDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.09))
            .frame(width: 0.7, height: 30)
    }
}

struct EmptyStateView: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        GlassPanel(accent: AppStyle.secondaryText) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(AppStyle.secondaryText)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppStyle.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
