import Speech

class Conversation: NSObject, ObservableObject, SFSpeechRecognitionTaskDelegate,
    AVSpeechSynthesizerDelegate
{
    struct Interaction: Equatable, Hashable, Identifiable {
        let id = UUID()

        var request: String
        var response: String

        init(request: String, response: String) {
            self.request = request
            self.response = response
        }
    }

    struct BeginContext {
        private let inner: Conversation

        init(inner: Conversation) {
            self.inner = inner
        }

        func say(_ message: String) {
            inner.stopListening()
            inner.say(message)
        }
    }

    enum Request {
        case Draft
    }

    typealias StartedListeningHandler = (BeginContext) -> Void
    typealias HeardHandler = (String) -> (String, String?)

    @Published var isEnabled: Bool
    @Published var isListening: Bool = false
    @Published var isTalking: Bool = false
    @Published var currentRequest: String = ""
    @Published var pastInteractions: [Interaction]
    var isOngoing: Bool {
        return isListening || isTalking
    }

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(
        locale: Locale(identifier: "en-US"))!
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var heard: HeardHandler?
    private var startedListening: StartedListeningHandler?

    init(
        enabled: Bool = false, currentRequest: String = "",
        pastInteractions: [Interaction] = []
    ) {
        self.isEnabled = enabled
        self.currentRequest = currentRequest
        self.pastInteractions = pastInteractions
    }

    func enableSpeech(
        startedListening: @escaping StartedListeningHandler,
        _ heard: @escaping HeardHandler
    ) {
        self.heard = heard
        self.startedListening = startedListening
        speechSynthesizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                DispatchQueue.main.async {
                    self.isEnabled = true
                }
            case .denied:
                PopAI.log("Denied access to speech recognition")
            case .restricted:
                PopAI.log("Speech recognition restricted on this device")
            case .notDetermined:
                PopAI.log("Speech recognition not yet authorized")
            @unknown default:
                PopAI.log("Unknown issue with speech recognition")
            }
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [
                    .duckOthers,
                    .defaultToSpeaker,
                ])
            try audioSession.setActive(
                true, options: .notifyOthersOnDeactivation)
        } catch {
            PopAI.log("Failed to configure audio session: \(error)")
        }
    }

    func toggleListening() {
        if isTalking {
            isTalking = false
        } else if isListening {
            stopListening()
        } else {
            do {
                try startListening()
                if let handler = startedListening {
                    handler(BeginContext(inner: self))
                }
            } catch {
                PopAI.log("Failed to start listening: \(error)")
            }
        }
    }

    private func startListening() throws {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError(
                "Unable to created a SFSpeechAudioBufferRecognitionRequest object"
            )
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        recognitionTask = speechRecognizer.recognitionTask(
            with: recognitionRequest, delegate: self)

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(
            onBus: 0, bufferSize: 1024, format: recordingFormat
        ) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }

    private func say(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        PopAI.log("Saying '\(message)'")
        isTalking = true
        self.speechSynthesizer.speak(utterance)
    }

    // MARK: SFSpeechRecognitionTaskDelegate

    func speechRecognitionTask(
        _ task: SFSpeechRecognitionTask,
        didHypothesizeTranscription: SFTranscription
    ) {
        let (request, response) = heard!(
            didHypothesizeTranscription.formattedString)
        currentRequest = request
        if let response = response {
            pastInteractions.append(
                Interaction(request: currentRequest, response: response))
            currentRequest = ""
            stopListening()
            say(response)
        }
    }

    // MARK: AVSpeechSynthesizerDelegate

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        log("Finished saying '\(utterance.speechString)'")
        guard isTalking else {
            return
        }

        isTalking = false
        do {
            try startListening()
        } catch {
            PopAI.log("Failed to re-start listening: \(error)")
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        log("Canceled saying '\(utterance.speechString)'")
        guard isTalking else {
            return
        }

        isTalking = false
        do {
            try startListening()
        } catch {
            PopAI.log("Failed to re-start listening: \(error)")
        }
    }
}
