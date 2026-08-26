import Foundation

struct VoiceTranscriptBuffer: Equatable, Sendable {
    private var finalizedSegments: [String] = []
    private var volatileSegment = ""

    var text: String {
        (finalizedSegments + [volatileSegment])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    mutating func receive(_ result: String, isFinal: Bool) {
        let normalized = result.trimmingCharacters(in: .whitespacesAndNewlines)

        if isFinal {
            if !normalized.isEmpty {
                finalizedSegments.append(normalized)
            }
            volatileSegment = ""
        } else {
            volatileSegment = normalized
        }
    }

    mutating func reset() {
        finalizedSegments.removeAll(keepingCapacity: true)
        volatileSegment = ""
    }
}

#if os(iOS)
    @preconcurrency import AVFAudio
    import Observation
    import Speech

    @available(iOS 26.0, *)
    @MainActor
    @Observable
    final class VoiceTransactionCapture {
        enum Status: Equatable {
            case idle
            case preparing
            case downloadingModel
            case listening
            case finishing
            case finished
            case microphoneDenied
            case unsupportedLanguage
            case failed
        }

        private(set) var status: Status = .idle
        private(set) var transcript = ""

        private var transcriptBuffer = VoiceTranscriptBuffer()
        private let audioEngine = AVAudioEngine()
        private var analyzer: SpeechAnalyzer?
        private var audioPipeline: VoiceAudioPipeline?
        private var forwardingTask: Task<Void, Never>?
        private var resultsTask: Task<Void, Never>?
        private var autoStopTask: Task<Void, Never>?
        private var hasAudioTap = false

        var isListening: Bool {
            status == .listening
        }

        func start(locale: Locale) async {
            guard !isListening, status != .preparing, status != .downloadingModel else {
                return
            }

            await cancel()
            status = .preparing
            transcriptBuffer.reset()
            transcript = ""

            guard await AVAudioApplication.requestRecordPermission() else {
                status = .microphoneDenied
                return
            }

            do {
                guard
                    let supportedLocale = await DictationTranscriber.supportedLocale(
                        equivalentTo: locale
                    )
                else {
                    status = .unsupportedLanguage
                    return
                }

                let transcriber = DictationTranscriber(
                    locale: supportedLocale,
                    preset: .progressiveShortDictation
                )

                if let installation = try await AssetInventory.assetInstallationRequest(
                    supporting: [transcriber]
                ) {
                    status = .downloadingModel
                    try await installation.downloadAndInstall()
                }

                let analyzer = SpeechAnalyzer(modules: [transcriber])
                let inputNode = audioEngine.inputNode
                let naturalFormat = inputNode.outputFormat(forBus: 0)
                guard
                    let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                        compatibleWith: [transcriber],
                        considering: naturalFormat
                    )
                else {
                    throw VoiceCaptureError.audioFormatUnavailable
                }

                let audioPipeline = try VoiceAudioPipeline(
                    inputFormat: naturalFormat,
                    outputFormat: analyzerFormat
                )

                self.analyzer = analyzer
                self.audioPipeline = audioPipeline

                resultsTask = Task { [weak self] in
                    do {
                        for try await result in transcriber.results {
                            guard let self else {
                                return
                            }
                            transcriptBuffer.receive(
                                String(result.text.characters),
                                isFinal: result.isFinal
                            )
                            transcript = transcriptBuffer.text
                        }
                    } catch is CancellationError {
                        return
                    } catch {
                        guard let self, status != .finishing else {
                            return
                        }
                        autoStopTask?.cancel()
                        stopAudioInput()
                        forwardingTask?.cancel()
                        status = .failed
                    }
                }

                forwardingTask = Task.detached(priority: .userInitiated) {
                    await audioPipeline.forwardAudio()
                }

                try configureAudioSession()
                inputNode.installTap(
                    onBus: 0,
                    bufferSize: 2_048,
                    format: naturalFormat
                ) { buffer, _ in
                    audioPipeline.yield(buffer)
                }
                hasAudioTap = true
                audioEngine.prepare()
                try audioEngine.start()
                try await analyzer.start(inputSequence: audioPipeline.analyzerStream)

                status = .listening
                autoStopTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(15))
                    guard !Task.isCancelled else {
                        return
                    }
                    await self?.stop()
                }
            } catch {
                await fail()
            }
        }

        func stop() async {
            guard status == .listening else {
                return
            }

            status = .finishing
            autoStopTask?.cancel()
            stopAudioInput()

            do {
                try await analyzer?.finalizeAndFinishThroughEndOfInput()
                await forwardingTask?.value
                await resultsTask?.value
                finishSession()
                status = .finished
            } catch {
                await fail()
            }
        }

        func cancel() async {
            autoStopTask?.cancel()
            stopAudioInput()
            forwardingTask?.cancel()
            resultsTask?.cancel()
            await analyzer?.cancelAndFinishNow()
            finishSession()

            if status != .microphoneDenied && status != .unsupportedLanguage {
                status = .idle
            }
        }

        private func fail() async {
            stopAudioInput()
            forwardingTask?.cancel()
            resultsTask?.cancel()
            await analyzer?.cancelAndFinishNow()
            finishSession()
            status = .failed
        }

        private func configureAudioSession() throws {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }

        private func stopAudioInput() {
            if audioEngine.isRunning {
                audioEngine.stop()
            }

            if hasAudioTap {
                audioEngine.inputNode.removeTap(onBus: 0)
                hasAudioTap = false
            }
            audioPipeline?.finishAudio()
        }

        private func finishSession() {
            audioPipeline?.finish()
            audioPipeline = nil
            analyzer = nil
            forwardingTask = nil
            resultsTask = nil
            autoStopTask = nil
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }

    }

    @available(iOS 26.0, *)
    private enum VoiceCaptureError: Error {
        case audioFormatUnavailable
    }

    @available(iOS 26.0, *)
    /// The audio tap only yields buffers. Conversion is confined to the one
    /// forwarding task, while AsyncStream continuations provide the thread-safe
    /// handoff between those two execution contexts.
    private final class VoiceAudioPipeline: @unchecked Sendable {
        let analyzerStream: AsyncStream<AnalyzerInput>

        private let audioStream: AsyncStream<AVAudioPCMBuffer>
        private let audioContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation
        private let analyzerContinuation: AsyncStream<AnalyzerInput>.Continuation
        private let converter: AVAudioConverter
        private let outputFormat: AVAudioFormat

        init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) throws {
            guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                throw VoiceCaptureError.audioFormatUnavailable
            }

            let analyzerPipe = AsyncStream.makeStream(
                of: AnalyzerInput.self,
                bufferingPolicy: .bufferingNewest(8)
            )
            let audioPipe = AsyncStream.makeStream(
                of: AVAudioPCMBuffer.self,
                bufferingPolicy: .bufferingNewest(8)
            )

            analyzerStream = analyzerPipe.stream
            analyzerContinuation = analyzerPipe.continuation
            audioStream = audioPipe.stream
            audioContinuation = audioPipe.continuation
            self.converter = converter
            self.outputFormat = outputFormat
        }

        func yield(_ buffer: AVAudioPCMBuffer) {
            audioContinuation.yield(buffer)
        }

        func finishAudio() {
            audioContinuation.finish()
        }

        func finish() {
            audioContinuation.finish()
            analyzerContinuation.finish()
        }

        func forwardAudio() async {
            for await buffer in audioStream {
                guard let converted = convert(buffer) else {
                    continue
                }
                analyzerContinuation.yield(AnalyzerInput(buffer: converted))
            }
            analyzerContinuation.finish()
        }

        private func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
            let ratio = outputFormat.sampleRate / input.format.sampleRate
            let capacity = AVAudioFrameCount(
                max(1, ceil(Double(input.frameLength) * ratio) + 32)
            )
            guard
                let output = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: capacity
                )
            else {
                return nil
            }

            let source = VoiceConverterInput(buffer: input)
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) {
                _, inputStatus in
                source.next(status: inputStatus)
            }

            guard status != .error, conversionError == nil, output.frameLength > 0 else {
                return nil
            }
            return output
        }
    }

    @available(iOS 26.0, *)
    /// AVAudioConverter invokes this provider synchronously; the box prevents a
    /// mutable local from crossing the converter's `@Sendable` callback.
    private final class VoiceConverterInput: @unchecked Sendable {
        private var buffer: AVAudioPCMBuffer?

        init(buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }

        func next(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
            guard let buffer else {
                status.pointee = .noDataNow
                return nil
            }

            self.buffer = nil
            status.pointee = .haveData
            return buffer
        }
    }
#endif
