#if os(iOS)
    import AVFoundation
    import SwiftUI

    struct SyncQRScanner: View {
        let completion: (String?) -> Void
        @State private var allowed: Bool?

        var body: some View {
            NavigationStack {
                Group {
                    if allowed == true {
                        SyncCameraView(completion: completion)
                    } else if allowed == false {
                        ContentUnavailableView(
                            "Camera access needed", systemImage: "camera",
                            description: Text(
                                "Allow camera access in Settings, or enter the pairing code manually."
                            ))
                    } else {
                        ProgressView()
                    }
                }
                .navigationTitle("Scan pairing code")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { completion(nil) }
                    }
                }
                .task { allowed = await AVCaptureDevice.requestAccess(for: .video) }
            }
        }
    }

    private struct SyncCameraView: UIViewControllerRepresentable {
        let completion: (String?) -> Void
        func makeUIViewController(context: Context) -> SyncCameraController {
            SyncCameraController(completion: completion)
        }
        func updateUIViewController(_ controller: SyncCameraController, context: Context) {}
        static func dismantleUIViewController(_ controller: SyncCameraController, coordinator: ()) {
            controller.capture.stop()
        }
    }

    private final class SyncCameraController: UIViewController,
        AVCaptureMetadataOutputObjectsDelegate
    {
        let capture = SyncCameraCapture()
        private let completion: (String?) -> Void
        private var preview: AVCaptureVideoPreviewLayer?
        private var delivered = false

        init(completion: @escaping (String?) -> Void) {
            self.completion = completion
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { nil }
        override func viewDidLoad() {
            super.viewDidLoad()
            let preview = AVCaptureVideoPreviewLayer(session: capture.session)
            preview.videoGravity = .resizeAspectFill
            self.preview = preview
            view.layer.addSublayer(preview)
            capture.start(delegate: self)
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
        }
        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            let value = objects.compactMap {
                ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue
            }.first
            guard let value else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.delivered else { return }
                self.delivered = true
                self.capture.stop()
                self.completion(value)
            }
        }
    }

    /// Session configuration/start/stop are serialized off the UI thread.
    private final class SyncCameraCapture: @unchecked Sendable {
        let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "monmon.p2p.camera")
        func start(delegate: SyncCameraController) {
            queue.async { [self] in
                guard let camera = AVCaptureDevice.default(for: .video),
                    let input = try? AVCaptureDeviceInput(device: camera),
                    session.canAddInput(input)
                else { return }
                session.beginConfiguration()
                session.addInput(input)
                let output = AVCaptureMetadataOutput()
                guard session.canAddOutput(output) else {
                    session.commitConfiguration()
                    return
                }
                session.addOutput(output)
                output.setMetadataObjectsDelegate(delegate, queue: .main)
                output.metadataObjectTypes = [.qr]
                session.commitConfiguration()
                session.startRunning()
            }
        }
        func stop() { queue.async { [self] in session.stopRunning() } }
    }
#endif
