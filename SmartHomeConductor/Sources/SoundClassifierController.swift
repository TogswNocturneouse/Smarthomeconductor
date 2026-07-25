@preconcurrency import AVFAudio
@preconcurrency import CoreML
@preconcurrency import SoundAnalysis
import Foundation

struct ClassifierReading: Identifiable, Equatable, Sendable {
    let id = UUID()
    let label: String
    let confidence: Double
    let timestamp = Date()
}

enum ClassifierState: Equatable, Sendable {
    case idle
    case requestingPermission
    case listening
    case permissionDenied
    case unavailable(String)

    var title: String {
        switch self {
        case .idle: "Ready"
        case .requestingPermission: "Requesting microphone"
        case .listening: "Listening locally"
        case .permissionDenied: "Microphone denied"
        case .unavailable: "Unavailable"
        }
    }

    var isListening: Bool {
        self == .listening
    }
}

@MainActor
final class SoundClassifierController: NSObject, ObservableObject {
    @Published private(set) var state: ClassifierState = .idle
    @Published private(set) var latestReading: ClassifierReading?
    @Published private(set) var knownLabels: [String] = []

    private let audioEngine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?

    var modelIsBundled: Bool {
        Bundle.main.url(forResource: "MySoundClassifier", withExtension: "mlmodelc") != nil
    }

    func toggleListening() {
        state.isListening ? stop() : start()
    }

    func start() {
        guard !state.isListening else { return }
        state = .requestingPermission

        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                state = .permissionDenied
                return
            }

            do {
                try startAudioAnalysis()
                state = .listening
            } catch {
                stopAudioEngine()
                state = .unavailable(error.localizedDescription)
            }
        }
    }

    func stop() {
        stopAudioEngine()
        state = .idle
    }

    func emitDemoReading() {
        let labels = knownLabels.isEmpty
            ? ["0-999", "1000-1999", "2000-2999"]
            : knownLabels
        let index = Int.random(in: labels.indices)
        latestReading = ClassifierReading(
            label: labels[index],
            confidence: Double.random(in: 0.72...0.97)
        )
    }

    private func startAudioAnalysis() throws {
        guard
            let modelURL = Bundle.main.url(
                forResource: "MySoundClassifier",
                withExtension: "mlmodelc"
            )
        else {
            throw ClassifierError.modelMissing
        }

        let model = try MLModel(contentsOf: modelURL)
        let classificationRequest = try SNClassifySoundRequest(mlModel: model)
        classificationRequest.overlapFactor = 0.5

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw ClassifierError.audioInputUnavailable
        }

        let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        try streamAnalyzer.add(classificationRequest, withObserver: self)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 8_192,
            format: format
        ) { buffer, time in
            streamAnalyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }

        analyzer = streamAnalyzer
        request = classificationRequest
        knownLabels = classificationRequest.knownClassifications
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        analyzer?.completeAnalysis()
        analyzer?.removeAllRequests()
        analyzer = nil
        request = nil
    }
}

extension SoundClassifierController: SNResultsObserving {
    nonisolated func request(_ request: SNRequest, didProduce result: SNResult) {
        guard
            let classification = result as? SNClassificationResult,
            let best = classification.classifications.first
        else {
            return
        }

        let reading = ClassifierReading(
            label: best.identifier,
            confidence: best.confidence
        )
        Task { @MainActor [weak self] in
            self?.latestReading = reading
        }
    }

    nonisolated func request(_ request: SNRequest, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.stopAudioEngine()
            self?.state = .unavailable(error.localizedDescription)
        }
    }

    nonisolated func requestDidComplete(_ request: SNRequest) {
        Task { @MainActor [weak self] in
            guard self?.state.isListening == true else { return }
            self?.state = .idle
        }
    }
}

private enum ClassifierError: LocalizedError {
    case modelMissing
    case audioInputUnavailable

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            "MySoundClassifier.mlmodel is not bundled."
        case .audioInputUnavailable:
            "No microphone input is available."
        }
    }
}
