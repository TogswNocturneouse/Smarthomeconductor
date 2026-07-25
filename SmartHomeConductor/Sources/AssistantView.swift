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
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

struct AssistantView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var viewModel = AssistantViewModel()
    @State private var draft = ""

    private let suggestions = [
        "What needs attention?",
        "Reduce energy use",
        "Plan my evening"
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
                                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding()
                    }
                    .background(AppStyle.background.ignoresSafeArea())
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
        }
    }

    private var connectionStrip: some View {
        HStack {
            Label("Secure gateway", systemImage: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)
            Spacer()
            Text("\(store.onlineDeviceCount) devices online")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .background(Color.teal.opacity(0.08))
    }

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        send(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                    .disabled(viewModel.isSending)
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask Home Conductor...", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .submitLabel(.send)
                .onSubmit {
                    send(draft)
                }

            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .accessibilityLabel("Send message")
        }
        .padding()
        .background(.bar)
    }

    private func send(_ text: String) {
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
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(message.role == .user ? Color.teal : AppStyle.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
    }
}
