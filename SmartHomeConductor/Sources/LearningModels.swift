import Foundation
import SwiftData

enum LearnedRecordKind: String, CaseIterable, Identifiable, Codable {
    case memoryFact = "Memory"
    case preference = "Preference"
    case routine = "Routine"
    case permission = "Permission"
    case feedback = "Feedback"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .memoryFact: "brain.head.profile"
        case .preference: "slider.horizontal.3"
        case .routine: "clock.arrow.circlepath"
        case .permission: "hand.raised"
        case .feedback: "checkmark.seal"
        }
    }
}

@Model
final class LearnedRecord {
    var id: UUID
    var kindRawValue: String
    var title: String
    var detail: String
    var source: String
    var isConfirmed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: LearnedRecordKind,
        title: String,
        detail: String,
        source: String = "User",
        isConfirmed: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.title = title
        self.detail = detail
        self.source = source
        self.isConfirmed = isConfirmed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: LearnedRecordKind {
        get { LearnedRecordKind(rawValue: kindRawValue) ?? .memoryFact }
        set { kindRawValue = newValue.rawValue }
    }
}

extension LearnedRecord {
    static let gatewayLimit = 24

    var assistantSummary: String {
        "\(kind.rawValue): \(title) - \(detail)"
    }
}

@Model
final class AssistantMessageRecord {
    var id: UUID
    var roleRawValue: String
    var content: String
    var createdAt: Date

    init(
        id: UUID,
        roleRawValue: String,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.roleRawValue = roleRawValue
        self.content = content
        self.createdAt = createdAt
    }
}
