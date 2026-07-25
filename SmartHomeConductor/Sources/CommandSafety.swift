import Foundation

enum CommandOrigin: String, Codable, CaseIterable, Sendable {
    case userInterface = "User"
    case assistant = "Assistant"
    case automation = "Automation"
    case remoteSupport = "Remote support"
}

enum DeviceCommand: Hashable, Sendable {
    case setPower(Bool)
    case setBrightness(Double)
    case setColor(String)
    case setFanSpeed(Double)
    case setTargetTemperature(Double)
    case setMode(String)

    var requiredCapability: DeviceCapability {
        switch self {
        case .setPower:
            .power
        case .setBrightness:
            .brightness
        case .setColor:
            .color
        case .setFanSpeed:
            .fanSpeed
        case .setTargetTemperature, .setMode:
            .coolingMode
        }
    }

    var summary: String {
        switch self {
        case let .setPower(isOn):
            isOn ? "Turn on" : "Turn off"
        case let .setBrightness(value):
            "Set brightness to \(Int(value.rounded()))%"
        case let .setColor(value):
            "Set color to \(value)"
        case let .setFanSpeed(value):
            "Set fan speed to \(Int(value.rounded()))"
        case let .setTargetTemperature(value):
            "Set target temperature to \(value.formatted(.number.precision(.fractionLength(1)))) C"
        case let .setMode(value):
            "Set mode to \(value)"
        }
    }
}

enum CommandRisk: String, Codable, Comparable, Sendable {
    case ordinary
    case elevated
    case sensitive

    private var rank: Int {
        switch self {
        case .ordinary: 0
        case .elevated: 1
        case .sensitive: 2
        }
    }

    static func < (lhs: CommandRisk, rhs: CommandRisk) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum CommandPolicyDecision: Equatable, Sendable {
    case allow
    case requireConfirmation(String)
    case deny(String)
}

struct CommandAuthorizationPolicy: Sendable {
    func risk(for command: DeviceCommand, device: SmartDevice) -> CommandRisk {
        if device.kind == .camera {
            return .sensitive
        }
        if device.kind == .smartPlug {
            return .elevated
        }
        if case let .setTargetTemperature(value) = command, !(18...28).contains(value) {
            return .sensitive
        }
        if device.kind == .airConditioner {
            return .elevated
        }
        return .ordinary
    }

    func evaluate(
        command: DeviceCommand,
        device: SmartDevice,
        origin: CommandOrigin,
        isConfirmed: Bool,
        assistantLightControlAllowed: Bool
    ) -> CommandPolicyDecision {
        guard device.capabilities.contains(command.requiredCapability) else {
            return .deny("\(device.name) does not expose \(command.requiredCapability.rawValue).")
        }

        let commandRisk = risk(for: command, device: device)
        if commandRisk == .sensitive, !isConfirmed {
            return .requireConfirmation("This action affects a sensitive device or an HVAC extreme.")
        }

        if origin == .remoteSupport, !isConfirmed {
            return .requireConfirmation("Remote physical commands require local confirmation.")
        }

        if origin == .automation, commandRisk >= .elevated, !isConfirmed {
            return .requireConfirmation("This automation affects an elevated-risk device.")
        }

        if origin == .assistant {
            let isLight = [.normalLight, .dimmerLight, .colorLight].contains(device.kind)
            if isLight, !assistantLightControlAllowed, !isConfirmed {
                return .requireConfirmation("Assistant light control is disabled in Settings.")
            }
            if commandRisk >= .elevated, !isConfirmed {
                return .requireConfirmation("The assistant needs confirmation for this device.")
            }
        }

        return .allow
    }
}

enum CommandAuditOutcome: String, Codable, Sendable {
    case localStateUpdated = "Local state updated"
    case deviceConfirmed = "Device confirmed"
    case confirmationRequired = "Confirmation required"
    case rejected = "Rejected"
    case transportUnavailable = "Transport unavailable"
}

struct CommandAuditRecord: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var deviceID: UUID
    var deviceName: String
    var command: String
    var origin: CommandOrigin
    var risk: CommandRisk
    var outcome: CommandAuditOutcome
    var detail: String
    var timestamp = Date.now
}

struct CommandExecutionResult: Equatable, Sendable {
    var outcome: CommandAuditOutcome
    var message: String

    var succeededLocally: Bool {
        outcome == .localStateUpdated || outcome == .deviceConfirmed
    }
}

struct SceneExecutionReport: Equatable, Sendable {
    var scene: ScenePreset
    var eligibleDevices: Int
    var updatedDevices: Int
    var blockedDevices: Int

    var message: String {
        if eligibleDevices == 0 {
            return "\(scene.rawValue) was not run because no compatible devices are connected."
        }
        if updatedDevices == 0, blockedDevices > 0 {
            return "\(scene.rawValue) could not reach \(blockedDevices) connected endpoint\(blockedDevices == 1 ? "" : "s"). No device state was changed."
        }
        if blockedDevices > 0 {
            return "\(scene.rawValue) confirmed \(updatedDevices) endpoint\(updatedDevices == 1 ? "" : "s") and blocked \(blockedDevices)."
        }
        return "\(scene.rawValue) confirmed \(updatedDevices) connected endpoint\(updatedDevices == 1 ? "" : "s")."
    }
}
