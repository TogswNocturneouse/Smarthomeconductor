import Foundation
import SwiftData
import SwiftUI

private struct AssistantAPIMessage: Codable {
    let role: String
    let content: String
}

private struct AssistantDeviceContext: Codable {
    let name: String
    let room: String
    let kind: String
    let manufacturer: String
    let protocols: [String]
    let capabilities: [String]
    let isOnline: Bool
    let isOn: Bool
}

private struct AssistantHomeContext: Codable {
    let onlineDevices: Int
    let activeDevices: Int
    let rooms: [String]
    let devices: [AssistantDeviceContext]
    let enabledRules: [String]
    let learnedRecords: [String]
    let platformKnowledge: [String]
}

private struct AssistantRequest: Codable {
    let messages: [AssistantAPIMessage]
    let homeContext: AssistantHomeContext
}

private struct AssistantResponse: Codable {
    let id: String
    let model: String
    let message: String
}

private struct AssistantErrorResponse: Codable {
    let error: String
}

private enum AssistantServiceError: LocalizedError {
    case invalidGatewayURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidGatewayURL:
            "The AI gateway URL is missing or invalid."
        case .invalidResponse:
            "The AI gateway returned an unreadable response."
        case .server(let message):
            message
        }
    }
}

private struct HomeConductorAssistantService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(
        messages: [AssistantMessage],
        context: AssistantHomeContext
    ) async throws -> AssistantResponse {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "AI_GATEWAY_URL") as? String,
            let url = URL(string: value),
            ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            throw AssistantServiceError.invalidGatewayURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 65
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AssistantRequest(
                messages: messages.suffix(20).map {
                    AssistantAPIMessage(role: $0.role.rawValue, content: $0.content)
                },
                homeContext: context
            )
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AssistantServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = try? JSONDecoder().decode(AssistantErrorResponse.self, from: data)
            throw AssistantServiceError.server(
                serverError?.error ?? "The Home Conductor assistant is unavailable."
            )
        }

        do {
            return try JSONDecoder().decode(AssistantResponse.self, from: data)
        } catch {
            throw AssistantServiceError.invalidResponse
        }
    }
}

private struct AssistantMessage: Identifiable {
    enum Role: String {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let content: String
}

@MainActor
private final class AssistantViewModel: ObservableObject {
    @Published private(set) var messages: [AssistantMessage] = [
        AssistantMessage(
            role: .assistant,
            content: "I can inspect your inventory, start a nearby device scan, explain connection routes, and control endpoints only after they are genuinely connected."
        )
    ]
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let service = HomeConductorAssistantService()

    func sendLocal(_ text: String, response: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        messages.append(AssistantMessage(role: .user, content: trimmedText))
        messages.append(AssistantMessage(role: .assistant, content: response))
        errorMessage = nil
    }

    func send(_ text: String, context: AssistantHomeContext) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isSending else { return }

        messages.append(AssistantMessage(role: .user, content: trimmedText))
        isSending = true
        errorMessage = nil

        Task {
            do {
                let response = try await service.send(messages: messages, context: context)
                messages.append(AssistantMessage(role: .assistant, content: response.message))
            } catch {
                messages.append(
                    AssistantMessage(
                        role: .assistant,
                        content: localFallback(context: context)
                    )
                )
                errorMessage = "Gateway unavailable. Response generated from local home state."
            }
            isSending = false
        }
    }

    private func localFallback(context: AssistantHomeContext) -> String {
        let offline = context.devices.filter { !$0.isOnline }.map(\.name)
        if context.devices.isEmpty {
            return "Your inventory is empty. Ask me to scan nearby devices, import Apple Home, or add an inventory record manually."
        }
        if offline.isEmpty {
            return "The local snapshot looks healthy: \(context.onlineDevices) devices are online and \(context.enabledRules.count) automations are enabled."
        }
        return "The local snapshot shows \(context.onlineDevices) devices online. Offline: \(offline.joined(separator: ", "))."
    }
}

struct AssistantView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var discovery: LocalDiscoveryController
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LearnedRecord.updatedAt, order: .reverse) private var learnedRecords: [LearnedRecord]
    @StateObject private var viewModel = AssistantViewModel()
    @State private var draft = ""

    private let suggestions = [
        "Scan for devices",
        "Remember studio means upstairs office",
        "How should I connect Tapo?",
        "What needs attention?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionStrip

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            suggestionRow

                            ForEach(viewModel.messages) { message in
                                AssistantBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isSending {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Conductor is thinking...")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }

                            if let errorMessage = viewModel.errorMessage {
                                Label(errorMessage, systemImage: "network.slash")
                                    .font(.footnote)
                                    .foregroundStyle(AppStyle.amber)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(AppStyle.amber.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                        }
                        .padding()
                    }
                    .background(Color.clear)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        guard let lastID = viewModel.messages.last?.id else { return }
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }

                composer
            }
            .navigationTitle("Home Assistant")
            .background(Color.clear)
        }
    }

    private var connectionStrip: some View {
        HStack {
            Label("Secure gateway", systemImage: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppStyle.violet)
            Spacer()
            Text(
                discovery.isScanning
                    ? "\(discovery.candidates.count) candidates found"
                    : "\(store.onlineDeviceCount) devices online"
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .background(AppStyle.violet.opacity(0.07))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.7)
        }
    }

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        send(suggestion)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppStyle.text)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .buttonStyle(GlassButtonStyle(accent: AppStyle.violet))
                    .disabled(viewModel.isSending)
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask Home Conductor...", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppStyle.surface.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.11), lineWidth: 0.7)
                }
                .submitLabel(.send)
                .onSubmit {
                    send(draft)
                }

            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppStyle.text)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(GlassButtonStyle(accent: AppStyle.violet, cornerRadius: 8))
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .accessibilityLabel("Send message")
        }
        .padding()
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 0.7)
        }
    }

    private func send(_ text: String) {
        let normalized = text.lowercased()
        if normalized.contains("scan") || normalized.contains("discover") || normalized.contains("find device") {
            discovery.scanNearby()
            viewModel.sendLocal(
                text,
                response: "Scanning Bluetooth advertisements and Bonjour services on your local network now. Open Devices, tap Add, then Discover to review and add candidates. Detection alone does not authorize control."
            )
            draft = ""
            return
        }

        if let response = teachConductor(text) {
            viewModel.sendLocal(text, response: response)
            draft = ""
            return
        }

        if let response = store.executeLocalAssistantCommand(text) {
            viewModel.sendLocal(text, response: response)
            draft = ""
            return
        }

        if let advice = store.connectionAdvice(for: text) {
            viewModel.sendLocal(text, response: advice)
            draft = ""
            return
        }

        if store.preferences.localProcessingOnly {
            viewModel.sendLocal(
                text,
                response: "I can scan for nearby devices, explain connection routes for your brands, report inventory and connection health, run scenes when endpoints are connected, or control a connected device by name."
            )
            draft = ""
            return
        }

        let context = AssistantHomeContext(
            onlineDevices: store.onlineDeviceCount,
            activeDevices: store.activeDeviceCount,
            rooms: store.rooms,
            devices: store.devices.prefix(30).map {
                AssistantDeviceContext(
                    name: $0.name,
                    room: $0.room,
                    kind: $0.kind.rawValue,
                    manufacturer: $0.manufacturer,
                    protocols: $0.protocols.map(\.rawValue),
                    capabilities: $0.capabilities.map(\.rawValue),
                    isOnline: $0.isOnline,
                    isOn: $0.isOn
                )
            },
            enabledRules: store.rules.filter(\.isEnabled).map(\.title),
            learnedRecords: learnedRecords
                .filter(\.isConfirmed)
                .prefix(LearnedRecord.gatewayLimit)
                .map(\.assistantSummary),
            platformKnowledge: [
                "Never claim a disconnected inventory device was controlled.",
                "HomeKit import reads accessories already authorized in Apple Home.",
                "Matter accessories require commissioning before cluster control.",
                "Bluetooth or Bonjour detection does not imply authentication.",
                "SmartThings production linking uses OAuth with scoped device permissions.",
                "Confirmed memory records may guide personalization; unconfirmed suggestions must not be treated as user policy.",
                "Read-only operations can run automatically; physical actions require permission policies and extra confirmation for cameras, heating extremes, locks, alarms, and electrical equipment.",
                "Use retrieval, structured tools, feedback, and offline evals for improvement instead of uncontrolled self-training.",
                "Prefer local processing and local transports when capability and security permit."
            ]
        )

        viewModel.send(text, context: context)
        draft = ""
    }

    private func teachConductor(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        let kind: LearnedRecordKind
        let prefix: String

        if normalized.hasPrefix("remember ") {
            kind = .memoryFact
            prefix = "remember "
        } else if normalized.hasPrefix("prefer ") {
            kind = .preference
            prefix = "prefer "
        } else if normalized.hasPrefix("never ") {
            kind = .permission
            prefix = "never "
        } else if normalized.hasPrefix("feedback ") {
            kind = .feedback
            prefix = "feedback "
        } else {
            return nil
        }

        let body = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            return "Give me the detail after \(prefix.trimmingCharacters(in: .whitespaces))."
        }

        let title = body.count > 52 ? "\(body.prefix(49))..." : body
        modelContext.insert(
            LearnedRecord(
                kind: kind,
                title: title,
                detail: body,
                source: "Assistant chat",
                isConfirmed: true
            )
        )
        try? modelContext.save()

        switch kind {
        case .memoryFact:
            return "Remembered. You can inspect or delete it in Teach."
        case .preference:
            return "Preference saved. I will include it in future assistant context."
        case .permission:
            return "Safety preference saved. I will treat this as a restriction unless you change it in Teach."
        case .feedback:
            return "Feedback recorded for the improvement log."
        case .routine:
            return "Routine saved."
        }
    }
}

private struct AssistantBubble: View {
    let message: AssistantMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
            }

            Text(message.content)
                .font(.body)
                .foregroundStyle(AppStyle.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            message.role == .user
                                ? AppStyle.violet.opacity(0.34)
                                : AppStyle.surface.opacity(0.78)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    message.role == .user
                                        ? AppStyle.violet.opacity(0.42)
                                        : Color.white.opacity(0.10),
                                    lineWidth: 0.7
                                )
                        }
                }

            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
    }
}
