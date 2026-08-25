import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
    /// The app group this build stages into, set per configuration in the
    /// xcconfigs. Dev and prod carry different groups, so a statement shared
    /// into one build never appears in the other.
    private nonisolated static var appGroupIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "MonMonAppGroupIdentifier") as? String
    }

    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let messageLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private var hasStarted = false
    private var shouldCompleteRequest = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true
        receivePDF()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        messageLabel.text = "Đang nhận sao kê…"
        messageLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        closeButton.configuration = .filled()
        closeButton.configuration?.title = "Đóng"
        closeButton.isHidden = true
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

        activityIndicator.startAnimating()
        let stack = UIStackView(arrangedSubviews: [activityIndicator, messageLabel, closeButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
    }

    private func receivePDF() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        guard
            providers.count == 1,
            let provider = providers.first,
            provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
        else {
            showFailure("Hãy chia sẻ đúng một file PDF.")
            return
        }
        let suggestedFilename = provider.suggestedName

        provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) {
            [weak self] sourceURL, error in
            guard let self else { return }
            guard error == nil, let sourceURL else {
                Task { @MainActor in
                    self.showFailure("MonMon không thể đọc file này.")
                }
                return
            }

            let result = Result {
                guard
                    let groupIdentifier = Self.appGroupIdentifier,
                    let rootURL = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier: groupIdentifier
                    )
                else {
                    throw StatementIntakeError.appGroupUnavailable
                }
                let filename = suggestedFilename ?? sourceURL.lastPathComponent
                return try StatementIntakeStore(rootURL: rootURL).stagePDF(
                    at: sourceURL,
                    originalFilename: filename
                )
            }
            Task { @MainActor in
                switch result {
                case .success:
                    self.showSuccess()
                case .failure(let error):
                    self.showFailure(self.message(for: error))
                }
            }
        }
    }

    private func showSuccess() {
        shouldCompleteRequest = true
        activityIndicator.stopAnimating()
        messageLabel.text = "Đã gửi sao kê tới MonMon."
        closeButton.isHidden = false
    }

    private func showFailure(_ message: String) {
        shouldCompleteRequest = false
        activityIndicator.stopAnimating()
        messageLabel.text = message
        closeButton.isHidden = false
    }

    private func message(for error: Error) -> String {
        switch error {
        case StatementIntakeError.oversizedFile:
            "File vượt quá giới hạn 25 MB."
        case StatementIntakeError.unsupportedPDF:
            "File được chọn không phải PDF hợp lệ."
        default:
            "Chưa thể gửi sao kê tới MonMon. Vui lòng thử lại."
        }
    }

    @objc private func close() {
        if shouldCompleteRequest {
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            extensionContext?.cancelRequest(withError: ShareIntakeDisplayError.failed)
        }
    }
}

private enum ShareIntakeDisplayError: LocalizedError {
    case failed

    var errorDescription: String? {
        "MonMon chưa thể nhận sao kê."
    }
}
