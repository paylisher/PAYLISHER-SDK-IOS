//
//  PaylisherInAppModalViewController.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 14.02.2025.
//

import UIKit
//import Paylisher

//@available(iOSApplicationExtension, unavailable)
class PaylisherInAppModalViewController: UIViewController {

    private let titleText: String
    private let bodyText: String
    private let imageUrlString: String?
    private let actionUrlString: String?
    private let actionText: String
    private let gcmMessageID: String
    
    init(title: String,
         body: String,
         imageUrl: String?,
         actionUrl: String?,
         actionText: String,
         gcmMessageID: String)
    {
        
        self.titleText = title
        self.bodyText = body
        self.imageUrlString = imageUrl
        self.actionUrlString = actionUrl
        self.actionText = actionText
        self.gcmMessageID = gcmMessageID
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let containerView = UIView()
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 25
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.clipsToBounds = true
        view.addSubview(containerView)
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.textColor = .black
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        let bodyLabel = UILabel()
        bodyLabel.text = bodyText
        bodyLabel.textColor = .black
        bodyLabel.font = UIFont.systemFont(ofSize: 16)
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bodyLabel)
        
        let actionButton = UIButton(type: .system)
        actionButton.setTitle(actionText, for: .normal)
        actionButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.backgroundColor = UIColor.systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 8
        containerView.addSubview(actionButton)
        
        actionButton.addTarget(self, action: #selector(didTapActionButton), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 150),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            bodyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            actionButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            actionButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 80),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        
        if let imageUrlString = imageUrlString, let url = URL(string: imageUrlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        imageView.image = UIImage(data: data)
                    }
                }
            }.resume()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
          super.viewDidAppear(animated)
        
        CoreDataManager.shared.updateNotificationStatus(byMessageID: gcmMessageID, newStatus: "READ")
          print("In-App Bildirim READ olarak güncellendi!")
      }
    
    @objc func didTapActionButton() {
        
       
              dismiss(animated: true) {
#if IOS
                  if let actionUrl = self.actionUrlString, let url = URL(string: actionUrl) {
                      UIApplication.shared.open(url, options: [:], completionHandler: nil)
                  }
#endif
              }

    }

}
