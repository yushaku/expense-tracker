import SwiftUI

struct VoiceTransactionCaptureSection: View {
    @Binding var transcript: String

    var body: some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                VoiceTransactionCaptureControls(transcript: $transcript)
            } else {
                unavailableNotice
            }
        #else
            unavailableNotice
        #endif
    }

    private var unavailableNotice: some View {
        Label(
            "On-device voice capture requires iOS 26. Type the transaction below instead.",
            systemImage: "iphone.slash"
        )
        .font(.caption)
        .foregroundStyle(MonMonTheme.textSecondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            MonMonTheme.field,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

#if os(iOS)
    @available(iOS 26.0, *)
    private struct VoiceTransactionCaptureControls: View {
        @Binding var transcript: String
        @Environment(\.locale) private var locale
        @Environment(\.openURL) private var openURL
        @State private var capture = VoiceTransactionCapture()
        @State private var didAutoStart = false

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 40, height: 40)
                        .background(
                            iconColor.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .font(.subheadline.weight(.semibold))

                        Text(statusDetail)
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    if showsProgress {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(statusTitle)
                    }
                }

                if capture.status == .microphoneDenied {
                    Button("Open microphone settings", systemImage: "gearshape") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        openURL(url)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("voice-capture-open-settings")
                } else if showsCaptureButton {
                    Button(action: toggleCapture) {
                        Label(
                            capture.isListening ? "Stop listening" : "Listen again",
                            systemImage: buttonIcon
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(capture.isListening ? MonMonTheme.danger : MonMonTheme.accent)
                    .accessibilityIdentifier("voice-capture-toggle")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                MonMonTheme.field,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .task {
                guard !didAutoStart else {
                    return
                }
                didAutoStart = true
                await capture.start(locale: locale)
            }
            .onChange(of: capture.transcript) { _, newValue in
                transcript = newValue
            }
            .onDisappear {
                Task { await capture.cancel() }
            }
        }

        private var statusTitle: LocalizedStringKey {
            switch capture.status {
            case .idle:
                "Ready to listen"
            case .preparing:
                "Preparing microphone"
            case .downloadingModel:
                "Preparing on-device language"
            case .listening:
                "Listening…"
            case .finishing:
                "Finishing transcript"
            case .finished:
                "Transcript added"
            case .microphoneDenied:
                "Microphone access is off"
            case .unsupportedLanguage:
                "This language is not available on device"
            case .failed:
                "Voice capture isn’t available"
            }
        }

        private var statusDetail: LocalizedStringKey {
            switch capture.status {
            case .idle:
                "Tap Listen again when you are ready."
            case .preparing:
                "MonMon is starting private, on-device transcription."
            case .downloadingModel:
                "iPhone is downloading Apple’s on-device language model."
            case .listening:
                "Say one transaction, for example: cafe 50k."
            case .finishing:
                "The final words will appear below."
            case .finished:
                "Review or edit the text below before saving."
            case .microphoneDenied:
                "Allow microphone access, then return and try again."
            case .unsupportedLanguage:
                "Type the transaction below instead. Audio was not uploaded."
            case .failed:
                "Type below or tap Listen again. Audio was not uploaded."
            }
        }

        private var statusIcon: String {
            switch capture.status {
            case .listening:
                "waveform"
            case .finished:
                "checkmark.circle.fill"
            case .microphoneDenied, .unsupportedLanguage, .failed:
                "exclamationmark.triangle.fill"
            default:
                "mic.fill"
            }
        }

        private var iconColor: Color {
            switch capture.status {
            case .listening:
                MonMonTheme.danger
            case .finished:
                MonMonTheme.accent
            case .microphoneDenied, .unsupportedLanguage, .failed:
                MonMonTheme.credit
            default:
                MonMonTheme.textSecondary
            }
        }

        private var showsProgress: Bool {
            switch capture.status {
            case .preparing, .downloadingModel, .finishing:
                true
            default:
                false
            }
        }

        private var showsCaptureButton: Bool {
            switch capture.status {
            case .listening, .finished, .failed, .unsupportedLanguage:
                true
            default:
                false
            }
        }

        private var buttonIcon: String {
            capture.isListening ? "stop.fill" : "mic.fill"
        }

        private func toggleCapture() {
            Task {
                if capture.isListening {
                    await capture.stop()
                } else {
                    await capture.start(locale: locale)
                }
            }
        }
    }
#endif
