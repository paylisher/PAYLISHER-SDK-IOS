//
//  PaylisherInAppModalViewController.swift
//  Paylisher
//

import UIKit

class PaylisherInAppModalViewController: UIViewController {

    private let titleText: String
    private let bodyText: String
    private let imageUrlString: String?
    private let actionUrlString: String?
    private let actionText: String
    private let gcmMessageID: String

    // Stored so the overlay-tap gesture can check whether the touch is inside
    private let container = UIView()

    init(title: String,
         body: String,
         imageUrl: String?,
         actionUrl: String?,
         actionText: String,
         gcmMessageID: String) {
        self.titleText      = title
        self.bodyText       = body
        self.imageUrlString = imageUrl
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

        // Dimmed background — tap outside card to dismiss
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap(_:)))
        view.addGestureRecognizer(tap)

        // Card container
        container.backgroundColor  = .white
        container.layer.cornerRadius = 8
        container.clipsToBounds    = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
        ])

        // ── Image (top, full-width, 80pt) ─────────────────────────────────────
        var contentTopAnchor: NSLayoutYAxisAnchor = container.topAnchor
        var contentTopConstant: CGFloat = 16

        if let urlStr = imageUrlString, !urlStr.isEmpty {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: container.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                imageView.heightAnchor.constraint(equalToConstant: 80),
            ])
            contentTopAnchor   = imageView.bottomAnchor
            contentTopConstant = 12

            if let url = URL(string: urlStr) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let img = UIImage(data: data) {
                        DispatchQueue.main.async { imageView.image = img }
                    }
                }.resume()
            }
        }

        // ── Content stack (title · body · button) ────────────────────────────
        let stack = UIStackView()
        stack.axis        = .vertical
        stack.alignment   = .center
        stack.spacing     = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentTopAnchor, constant: contentTopConstant),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])

        // Title
        if !titleText.isEmpty {
            let label = UILabel()
            label.text          = titleText
            label.textColor     = .black
            label.font          = .boldSystemFont(ofSize: 20)
            label.numberOfLines = 0
            label.textAlignment = .center
            stack.addArrangedSubview(label)
        }

        // Body
        if !bodyText.isEmpty {
            let label = UILabel()
            label.text          = bodyText
            label.textColor     = .black
            label.font          = .systemFont(ofSize: 16, weight: .semibold)
            label.numberOfLines = 0
            label.textAlignment = .center
            stack.addArrangedSubview(label)
        }

        // Spacer between text and button (only when there is text above)
        if !titleText.isEmpty || !bodyText.isEmpty {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            stack.addArrangedSubview(spacer)
        }

        // Action button — always shown
        let btn = UIButton(type: .system)
        btn.setTitle(actionText.isEmpty ? "Open" : actionText, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.backgroundColor  = UIColor(red: 29/255, green: 78/255, blue: 216/255, alpha: 1)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 4
        btn.contentEdgeInsets  = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        btn.addTarget(self, action: #selector(didTapActionButton), for: .touchUpInside)
        stack.addArrangedSubview(btn)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CoreDataManager.shared.updateNotificationStatus(byMessageID: gcmMessageID, newStatus: "READ")
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
