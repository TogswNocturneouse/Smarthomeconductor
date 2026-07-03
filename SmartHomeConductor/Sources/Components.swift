import SwiftUI

enum AppStyle {
    static let background = LinearGradient(
        colors: [Color(red: 0.96, green: 0.95, blue: 0.91), Color(red: 0.91, green: 0.95, blue: 0.94)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let card = Color.white.opacity(0.84)
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Pill: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.teal.opacity(0.12))
            .foregroundStyle(.teal)
            .clipShape(Capsule())
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: symbol)
                    .foregroundStyle(.teal)
            }

            Text(value)
                .font(.title2.weight(.bold))

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DeviceRow: View {
    let device: SmartDevice

    var body: some View {
        HStack(spacing: 12) {
            DeviceIcon(kind: device.kind, isOnline: device.isOnline)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                Text("\(device.kind.rawValue) - \(device.room)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: device.isOn ? "power.circle.fill" : "power.circle")
                .foregroundStyle(device.isOn ? .green : .secondary)
                .font(.title3)
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DeviceCard: View {
    let device: SmartDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DeviceIcon(kind: device.kind, isOnline: device.isOnline)
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.headline)
                    Text("\(device.room) - \(device.manufacturer)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(device.capabilities.prefix(4)) { capability in
                    Pill(capability.rawValue)
                }
            }

            ReadingStrip(device: device)
        }
        .padding()
        .background(AppStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct DeviceIcon: View {
    let kind: DeviceKind
    let isOnline: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: kind.symbol)
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 44, height: 44)
                .background(Color.teal.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Circle()
                .fill(isOnline ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
    }
}

struct ReadingStrip: View {
    let device: SmartDevice

    var body: some View {
        HStack {
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
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.teal : Color.white.opacity(0.8))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
    }
}
