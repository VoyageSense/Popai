import Speech

class Conversation: NSObject, ObservableObject, SFSpeechRecognitionTaskDelegate
{
    class Interaction: Identifiable {
        let id = UUID()

        var request: String
        var response: String

        init(request: String, response: String) {
            self.request = request
            self.response = response
        }
    }

    enum Request {
        case Draft
    }

    typealias RequestHandler = (Request) -> String

    @Published var isEnabled: Bool
    @Published var isListening: Bool = false
    @Published var currentRequest: String = ""
    @Published var pastInteractions: [Interaction]
    var listeningForFirst: Bool {
        currentRequest.isEmpty && pastInteractions.isEmpty && isListening
    }

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(
        locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var requestHandler: RequestHandler?

    init(
        enabled: Bool = false, currentRequest: String = "",
        pastInteractions: [Interaction] = []
    ) {
        self.isEnabled = enabled
        self.currentRequest = currentRequest
        self.pastInteractions = pastInteractions
    }

    func enableSpeech(_ handler: @escaping RequestHandler) {
        requestHandler = handler
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                DispatchQueue.main.async {
                    self.isEnabled = true
                }
            case .denied:
                print("denied access to speech recognition")
            case .restricted:
                print("speech recognition restricted on this device")
            case .notDetermined:
                print("speech recognition not yet authorized")
            @unknown default:
                print("unknown issue with speech recognition")
            }
        }
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            do {
                try startListening()
            } catch {
                print("failed to start listening: \(error)")
            }
        }
    }

    private func startListening() throws {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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

    private func parseSpeech(_ transcription: SFTranscription) -> (
        String, String?
    ) {
        let normalSpeech = transcription.formattedString.lowercased()
        guard normalSpeech.contains("popeye") || normalSpeech.contains("papa")
        else {
            return (transcription.formattedString, nil)
        }

        let correctedRequest = transcription.formattedString
            .replacingOccurrences(of: "Popeye", with: "PopAI,")
            .replacingOccurrences(of: "Papa", with: "PopAI,")

        if normalSpeech.contains("depth") || normalSpeech.contains("draft") {
            return (correctedRequest, requestHandler!(Request.Draft))
        } else {
            return (correctedRequest, nil)
        }
    }

    private func say(_ message: String) {
        print("saying '\(message)'")
    }

    // MARK: SFSpeechRecognitionTaskDelegate

    func speechRecognitionTask(
        _ task: SFSpeechRecognitionTask,
        didHypothesizeTranscription: SFTranscription
    ) {
        let (request, response) = parseSpeech(didHypothesizeTranscription)
        currentRequest = request
        if let response = response {
            pastInteractions.append(
                Interaction(request: currentRequest, response: response))
            currentRequest = ""
            stopListening()
            say(response)
            do {
                try startListening()
            } catch {
                print("failed to re-start listening: \(error)")
            }
        }
    }
}
