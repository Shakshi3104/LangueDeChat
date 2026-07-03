import UIKit
import UniformTypeIdentifiers

/// Share extension entry point. Pulls text (and any URL) out of the shared item,
/// extracts a carrier + tracking number, and hands off to the containing app via
/// the `languedechat://add` deep link — where the user confirms in AddParcelView.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setUpProgressUI()
        Task { await run() }
    }

    private func run() async {
        let text = await extractSharedText()
        if let text, let result = TrackingNumberParser.parse(text),
           let url = TrackingNumberParser.deepLink(for: result) {
            await openContainingApp(url)
        }
        // Whether or not we found a number, dismiss the sheet. On a miss the user
        // simply lands back in Mail; nothing is added.
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - Shared content extraction

    /// Concatenates every plain-text and URL attachment across all input items so
    /// the parser sees both the message body and any tracking link.
    private func extractSharedText() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        var chunks: [String] = []
        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                chunks.append(text)
            }
            for provider in item.attachments ?? [] {
                if let text = await loadString(from: provider, type: UTType.plainText) {
                    chunks.append(text)
                } else if let text = await loadString(from: provider, type: UTType.text) {
                    chunks.append(text)
                }
                if let urlString = await loadURLString(from: provider) {
                    chunks.append(urlString)
                }
            }
        }
        let joined = chunks.joined(separator: "\n")
        return joined.isEmpty ? nil : joined
    }

    private func loadString(from provider: NSItemProvider, type: UTType) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                switch item {
                case let string as String:
                    continuation.resume(returning: string)
                case let data as Data:
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                case let attributed as NSAttributedString:
                    continuation.resume(returning: attributed.string)
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadURLString(from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                continuation.resume(returning: (item as? URL)?.absoluteString)
            }
        }
    }

    // MARK: - Open containing app

    /// Opens the app's deep link. `extensionContext.open` is the sanctioned path;
    /// the responder-chain walk is the long-standing fallback for custom schemes.
    private func openContainingApp(_ url: URL) async {
        let opened = await withCheckedContinuation { continuation in
            extensionContext?.open(url) { success in
                continuation.resume(returning: success)
            }
        }
        if !opened { openViaResponderChain(url) }
    }

    private func openViaResponderChain(_ url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector) && current != self {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }

    // MARK: - UI

    private func setUpProgressUI() {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        let label = UILabel()
        label.text = "Adding to LangueDeChat…"
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .subheadline)
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
