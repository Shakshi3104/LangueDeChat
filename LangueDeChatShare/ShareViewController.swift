import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Share extension entry point. Pulls text (and any URL) out of the shared item,
/// extracts a carrier + tracking number, and shows a small confirmation form
/// hosted right in the share sheet. On "Add" the parcel is written to the App
/// Group queue; the main app imports it the next time it comes to the front.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task {
            let text = await extractSharedText()
            let parsed = text.flatMap(TrackingNumberParser.parse)
            presentForm(carrier: parsed?.carrier, trackingNumber: parsed?.trackingNumber ?? "")
        }
    }

    private func presentForm(carrier: String?, trackingNumber: String) {
        let form = ShareFormView(
            initialCarrier: carrier,
            initialTrackingNumber: trackingNumber,
            onAdd: { [weak self] carrierRaw, trackingNumber, nickname in
                SharedStore.insertParcel(
                    carrierRaw: carrierRaw,
                    trackingNumber: trackingNumber,
                    nickname: nickname
                )
                self?.extensionContext?.completeRequest(returningItems: nil)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(
                    withError: NSError(domain: "com.shakshi.LangueDeChat.share", code: 0)
                )
            }
        )
        let host = UIHostingController(rootView: form)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
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
}
