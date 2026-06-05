//
//  PaylisherInAppModalViewController.swift
//  Paylisher
//

import UIKit

/// "Native" in-app notification — the compact card variant. Differs from the
/// `StyleViewController` modal/fullscreen/banner family by being intentionally
/// minimal: title + body + optional action button, centered on screen, no
/// authored layout blocks, no image. Sizing is content-driven (natural wrap)
/// with a `maxHeight` cap so an unusually long body still fits on small phones.
///
/// Authoring contract (matches Studio + Android SDK):
///   - `title`, `body`            — localized strings
///   - `titleAlign` / `bodyAlign` — "left" | "center" | "right" (default: "center")
///   - `actionText`               — button label; empty ⇒ button hidden
///   - `actionUrl`                — opened on tap
class PaylisherInAppModalViewController: UIViewController {

    private let titleText: String
    private let bodyText: String
    private let titleAlignment: NSTextAlignment
    private let bodyAlignment: NSTextAlignment
    private let actionUrlString: String?
    private let actionText: String
    private let gcmMessageID: String

    // Stored so the overlay-tap gesture can check whether the touch is inside.
    private let container = UIView()

    // Native card geometry — percent-of-viewport, mirrors the Studio preview
    // (`InAppReview.tsx` native branch: cardWidth = device.width * 0.84,
    // cardMaxHeight = device.height * 0.7). Kept in sync across platforms so
    // a notification renders the same on every device + the studio mockup.
    private let cardWidthRatio: CGFloat = 0.84
    private let cardMaxHeightRatio: CGFloat = 0.7
    // Inner padding scales with the card itself, not the screen — keeps the
    // breathing room consistent at every device width. ~5% mirrors modal.
    private let cardInnerPaddingRatio: CGFloat = 0.05

    init(title: String,
         body: String,
         titleAlign: String,
         bodyAlign: String,
         actionUrl: String?,
         actionText: String,
         gcmMessageID: String) {
        self.titleText      = title
        self.bodyText       = body
        self.titleAlignment = Self.resolveAlignment(titleAlign)
        self.bodyAlignment  = Self.resolveAlignment(bodyAlign)
        self.actionUrlString = actionUrl
        self.actionText     = actionText
        self.gcmMessageID   = gcmMessageID
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Dimmed background — tap outside card to dismiss.
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap(_:)))
        view.addGestureRecognizer(tap)

        // ── Card container ───────────────────────────────────────────────
        container.backgroundColor = .white
        container.layer.cornerRadius = 8
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let screenSize = UIScreen.main.bounds
        // No height constraint by design — the stack inside drives the card's
        // intrinsic height (doğal wrap). The maxHeight constraint below caps
        // it so a wildly long body still fits the viewport.
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: cardWidthRatio),
            container.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: cardMaxHeightRatio),
        ])

        // Inner padding — scales with the card width so denser devices keep
        // the same visual breathing room as the studio preview.
        let cardWidth = screenSize.width * cardWidthRatio
        let innerPadding = cardWidth * cardInnerPaddingRatio

        // Body fontSize % of CARD width (the only stable axis here because
        // height is content-driven). Mirrors modal's percent-of-container
        // intent: a fixed pt value would look giant on small phones + tiny
        // on big ones. ~5.5% on a 343pt card ≈ ~19pt — same visual weight as
        // the legacy 16pt on an iPhone-13.
        let titleFontSize = cardWidth * 0.06
        let bodyFontSize  = cardWidth * 0.045
        let buttonFontSize = cardWidth * 0.04

        // ── Content stack (title · body · button) ────────────────────────
        // The stack lives DIRECTLY inside the container (no UIScrollView
        // wrapper). A UIScrollView's intrinsic content size is `.zero`, so
        // wrapping the stack in one removed the upward pressure that
        // pushes the container tall enough to display content — and the
        // card collapsed to a 0-height white sliver (the bug Yusuf hit).
        //
        // With the stack anchored top/bottom directly to the container,
        // the stack's intrinsic content height pushes the container open
        // up to the `≤ 70% screen` max constraint. If body text exceeds
        // that cap, the label truncates — acceptable for a compact native
        // card; the design contract is "doğal wrap", not "novel-length
        // scrollable body".
        let stack = UIStackView()
        stack.axis = .vertical
        // Stretch each row to the full card width; per-row
        // `textAlignment` handles left / center / right per-field.
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: innerPadding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -innerPadding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: innerPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -innerPadding),
        ])

        // Title — only added when non-empty. Renders with bundled Inter Bold
        // so the native card's text metrics match Studio preview + Android
        // SDK exactly (same wrap points on identical strings).
        if !titleText.isEmpty {
            let label = UILabel()
            label.text          = titleText
            label.textColor     = .black
            label.font          = PaylisherFontRegistry.interFont(size: titleFontSize, bold: true, italic: false)
            label.numberOfLines = 0
            label.textAlignment = titleAlignment
            stack.addArrangedSubview(label)
            print("PAYLISHER_NATIVE | title: text='\(titleText)' align=\(titleAlignment.rawValue) fontSize=\(Int(titleFontSize)) weight=bold font=Inter-Bold")
        }

        // Body — only added when non-empty.
        // Weight is REGULAR (not semibold) — body is supporting copy under
        // the title, so a lighter weight reads cleanly. Matches Studio
        // preview (default fontWeight) and Android XML
        // (no `textStyle="bold"` on `@id/messageBody`).
        if !bodyText.isEmpty {
            let label = UILabel()
            label.text          = bodyText
            label.textColor     = .black
            label.font          = PaylisherFontRegistry.interFont(size: bodyFontSize, bold: false, italic: false)
            label.numberOfLines = 0
            label.textAlignment = bodyAlignment
            stack.addArrangedSubview(label)
            let bodyPreview = bodyText.count > 40 ? String(bodyText.prefix(40)) + "…" : bodyText
            print("PAYLISHER_NATIVE | body: text='\(bodyPreview)' align=\(bodyAlignment.rawValue) fontSize=\(Int(bodyFontSize)) weight=regular font=Inter-Regular")
        }

        // Spacer between text + button only when there's text above it.
        let hasTextAbove = !titleText.isEmpty || !bodyText.isEmpty
        let showButton = !actionText.isEmpty

        if hasTextAbove && showButton {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            stack.addArrangedSubview(spacer)
        }

        // Action button — ONLY added when the author supplied a label.
        // Mirrors the Studio preview + Android SDK contract: empty
        // `actionText` ⇒ no button (previously iOS fell back to "Open" and
        // Android always showed it; now both hide).
        if showButton {
            // Wrap the button so the stackView's `.fill` alignment doesn't
            // stretch a centered button row to the full card width.
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false

            let btn = UIButton(type: .system)
            btn.setTitle(actionText, for: .normal)
            // Action button uses Inter Bold (medium isn't shipped — bold is
            // the closest matching weight in our 4-variant bundle) so the
            // CTA matches the body face. Keeps the card visually cohesive
            // + parity with Studio preview / Android render.
            btn.titleLabel?.font = PaylisherFontRegistry.interFont(size: buttonFontSize, bold: true, italic: false)
            btn.backgroundColor  = UIColor(red: 29/255, green: 78/255, blue: 216/255, alpha: 1)
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 4
            btn.contentEdgeInsets  = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.addTarget(self, action: #selector(didTapActionButton), for: .touchUpInside)

            row.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: row.topAnchor),
                btn.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                btn.centerXAnchor.constraint(equalTo: row.centerXAnchor),
                btn.leadingAnchor.constraint(greaterThanOrEqualTo: row.leadingAnchor),
                btn.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),
            ])
            stack.addArrangedSubview(row)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Render-complete log — mirrors Android InAppMessageHelper's
        // "In-App sent!" trailing line at the end of the native path.
        print("FCM | InApp | In-App Native sent! locale=\(Locale.current.identifier) gcmMessageId=\(gcmMessageID)")
        CoreDataManager.shared.updateNotificationStatus(byMessageID: gcmMessageID, newStatus: "READ")
    }

    // MARK: - Helpers

    private static func resolveAlignment(_ raw: String) -> NSTextAlignment {
        switch raw.lowercased() {
        case "left":   return .left
        case "right":  return .right
        case "center": return .center
        default:       return .center
        }
    }

    // MARK: - Actions

    @objc private func handleOverlayTap(_ sender: UITapGestureRecognizer) {
        let loc = sender.location(in: view)
        if !container.frame.contains(loc) {
            dismiss(animated: true)
        }
    }

    @objc private func didTapActionButton() {
        dismiss(animated: true) {
            if let urlStr = self.actionUrlString, !urlStr.isEmpty,
               let url = URL(string: urlStr) {
                UIApplication.shared.open(url)
            }
        }
    }
}
