import Foundation
import SwiftUI

private struct AssistantAPIMessage: Codable {
    let role: String
    let content: String
}

private struct AssistantDeviceContext: Codable {
    let name: String
    let room: String
    let kind: String
    let isOnline: Bool
    let isOn: Bool
}

private struct AssistantHomeContext: Codable {
    let onlineDevices: Int
    let activeDevices: Int
    let rooms: [String]
    let devices: [AssistantDeviceContext]
    let enabledRules: [String]
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
            content: "I am ready to help coordinate your devices, routines, maintenance, and energy use."
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
        if offline.isEmpty {
            return "The local snapshot looks healthy: \(context.onlineDevices) devices are online and \(context.enabledRules.count) automations are enabled."
        }
        return "The local snapshot shows \(context.onlineDevices) devices online. Offline: \(offline.joined(separator: ", "))."
    }
}

struct AssistantView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var viewModel = AssistantViewModel()
    @State private var draft = ""

    private let suggestions = [
        "What needs attention?",
        "Run focus scene",
        "Turn everything off"
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
            Text("\(store.onlineDeviceCount) devices online")
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
        if let response = store.executeLocalAssistantCommand(text) {
            viewModel.sendLocal(text, response: response)
            draft = ""
            return
        }

        if store.preferences.localProcessingOnly {
            viewModel.sendLocal(
                text,
                response: "That request does not match a local command yet. I can report status, run Arrive, Focus, Air care, switch all devices off, or control a device by name."
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
                    isOnline: $0.isOnline,
                    isOn: $0.isOn
                )
            },
            enabledRules: store.rules.filter(\.isEnabled).map(\.title)
        )

        viewModel.send(text, context: context)
        draft = ""
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
