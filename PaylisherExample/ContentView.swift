//
//  ContentView.swift
//  PaylisherExample
//
//  Created by Ben White on 10.01.23.
//

import AuthenticationServices
import Paylisher
import SwiftUI

class SignInViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    // MARK: - ASWebAuthenticationPresentationContextProviding
/*
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    func triggerAuthentication() {
        guard let authURL = URL(string: "https://example.com/auth") else { return }
        let scheme = "exampleauth"

        // Initialize the session.
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
            if callbackURL != nil {
                print("URL", callbackURL!.absoluteString)
            }
            if error != nil {
                print("Error", error!.localizedDescription)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true

        session.start()
    }*/
    
    private var authSession: ASWebAuthenticationSession?

        func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
            return UIApplication.shared.windows.first!
        }

        func triggerAuthentication() {
            guard let authURL = URL(string: "https://example.com/auth") else { return }
            let scheme = "exampleauth"

            authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { [weak self] callbackURL, error in defer { self?.authSession = nil }
                if let callbackURL = callbackURL {
                    print("URL", callbackURL.absoluteString)
                }
                if let error = error {
                    print("Error", error.localizedDescription)
                }

                self?.authSession = nil
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = true

            authSession?.start()
        }
    
}

class FeatureFlagsModel: ObservableObject {
    @Published var boolValue: Bool?
    @Published var stringValue: String?
    @Published var payloadValue: [String: String]?
    @Published var isReloading: Bool = false

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloaded), name: PaylisherSDK.didReceiveFeatureFlags, object: nil)
    }

    @objc func reloaded() {
        boolValue = PaylisherSDK.shared.isFeatureEnabled("4535-funnel-bar-viz")
        stringValue = PaylisherSDK.shared.getFeatureFlag("multivariant") as? String
        payloadValue = PaylisherSDK.shared.getFeatureFlagPayload("multivariant") as? [String: String]
    }

    func reload() {
        isReloading = true

        PaylisherSDK.shared.reloadFeatureFlags {
            self.isReloading = false
        }
    }
}

struct YeniSayfaView: View {
    var body: some View {
        VStack {
            Text("Bu yeni bir sayfa!")
                .font(.largeTitle)
                .padding()
            
            
                

            NavigationLink(destination: ContentView()) {
                Text("Ana Sayfaya Dön")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .navigationTitle("Yeni Sayfa")
        
        /*.onAppear {
                   // sayfa göründüğünde targetName’e göre in-app mesajı kontrol et
                   NotificationManager.shared.showTargetInAppNotifications(
                       matching: "Yeni Sayfa"
                   )
               }*/
      
    }
}

struct ContentView: View {
    @State var counter: Int = 0
    @State private var name: String = "Max"
    @State private var showingSheet = false
    @State private var showingRedactedSheet = false
    @StateObject var api = Api()
    @State private var deepLinkDestination: String?
    @StateObject var signInViewModel = SignInViewModel()
    @StateObject var featureFlagsModel = FeatureFlagsModel()
    @StateObject private var locationManager = LocationManager()
        

    func incCounter() {
        counter += 1
    }
    
  /*  func showTargetNotifications(matching targetName: String) {
        let center  = UNUserNotificationCenter.current()
        let targets = CoreDataManager.shared.fetchTargetNotifications()

        for entity in targets {
            guard
                let payloadStr = entity.payload,
                let data       = payloadStr.data(using: .utf8),
                let topJson    = try? JSONSerialization.jsonObject(with: data, options: []),
                let topDict    = topJson as? [String:Any]
            else { continue }

            // condition JSON'u ayrıştır
            guard
                let condRaw    = topDict["condition"] as? String,
                let condData   = condRaw.data(using: .utf8),
                let condJson   = try? JSONSerialization.jsonObject(with: condData, options: []),
                let condDict   = condJson as? [String:Any],
                let target     = condDict["target"] as? String,
                target == targetName  // sadece buton adıyla eşleşene devam
            else { continue }
            
            let id = entity.gcmMessageID
            
            center.removePendingNotificationRequests(withIdentifiers: [id])

            // ... şimdi bildirim gösterme kodun ...
            let content = UNMutableNotificationContent()
            content.userInfo = topDict
            // title / body için actionBasedNotification zincirine devretmek istersen:
            NotificationManager.shared.customNotification(
                windowScene: nil,
                with:        content,
                for:         UNNotificationRequest(
                                 identifier: entity.gcmMessageID,
                                 content: content,
                                 trigger: nil
                             )
            ) { _ in
                CoreDataManager.shared.updateNotificationStatus(
                    byMessageID: entity.gcmMessageID,
                    newStatus:   "READ"
                )
            }

            // eğer sadece tek bir bildirim göstereceksen break
        }
    }*/


    func triggerIdentify() {
        PaylisherSDK.shared.identify(name, userProperties: [
            "name": name,
        ])
        
        PaylisherSDK.shared.screen("İkinci Ekran")
        
        PaylisherSDK.shared.capture("buttonClick", properties: ["name": "Trigger identify!", "screen_name": "İkinci Ekran"])
    }

    func triggerAuthentication() {
        PaylisherSDK.shared.screen("Test Ekranı")
        
        PaylisherSDK.shared.capture("buttonClick", properties: ["name": "Trigger fake authentication!", "screen_name": "Test Ekranı"])
        
        signInViewModel.triggerAuthentication()
    }

    func triggerFlagReload() {
        featureFlagsModel.reload()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    NavigationLink {
                        ContentView()
                    } label: {
                        Text("Infinite navigation")
                    }
                    .paylisherMask()

                    Button("Test Error") {
//                        throw NSError(domain: "com.example.test", code: 1, userInfo: [NSLocalizedDescriptionKey: "This is a test error event!"])
                       // let array = [1, 2, 3]
                        //let outOfBoundsValue = array[5]
                        
                        testErrorLogging()
                    }
                    
                    Button("Show Sheet") {
                        showingSheet.toggle()
                        PaylisherSDK.shared.screen("Splash")
                        PaylisherSDK.shared.capture("buttonClick", properties: ["name": "Show Sheet", "screen_name": "Splash"])
                    }
                    .sheet(isPresented: $showingSheet) {
                        ContentView()
                            .paylisherScreenView("ContentViewSheet")
                    }
                    Button("Show redacted view") {
                        showingRedactedSheet.toggle()
                        PaylisherSDK.shared.screen("İlk Ekran")
                        PaylisherSDK.shared.capture("buttonClick", properties: ["name": "Show redacted view", "screen_name": "İlk Ekran"])
                        
                       
                        //NotificationManager.shared.showTargetNotifications(matching: "Test Ekranı")
                        
                        
                        
                    }
                    .sheet(isPresented: $showingRedactedSheet) {
                        RepresentedExampleUIView()
                    }

                    Text("Sensitive text!!").paylisherMask()
                    Button(action: incCounter) {
                        Text(String(counter))
                    }
                    .paylisherMask()

                    TextField("Enter your name", text: $name)
                        .paylisherMask()
                    Text("Hello, \(name)!")
                    Button(action: triggerAuthentication) {
                        Text("Trigger fake authentication!")
                    }
                    Button(action: triggerIdentify) {
                        Text("Trigger identify!")
                    }.paylisherViewSeen("Trigger identify")
                }
                
                Section("Navigasyon") {
                  
                    NavigationLink(destination: YeniSayfaView(), tag: "YeniSayfaView", selection: $deepLinkDestination) {
                                        Text("Yeni Sayfaya Git")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color.green)
                                            .cornerRadius(10)
                                    }
                                }

                Section("Feature flags") {
                    HStack {
                        Text("Boolean:")
                        Spacer()
                        Text("\(featureFlagsModel.boolValue?.description ?? "unknown")")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("String:")
                        Spacer()
                        Text("\(featureFlagsModel.stringValue ?? "unknown")")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Payload:")
                        Spacer()
                        Text("\(featureFlagsModel.payloadValue?.description ?? "unknown")")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Button(action: triggerFlagReload) {
                            Text("Reload flags")
                        }
                        Spacer()
                        if featureFlagsModel.isReloading {
                            ProgressView()
                        }
                    }
                }

                Section("Paylisher beers") {
                    if !api.beers.isEmpty {
                        ForEach(api.beers) { beer in
                            HStack(alignment: .center) {
                                Text(beer.name)
                                Spacer()
                                Text("First brewed")
                                Text(beer.first_brewed).foregroundColor(Color.gray)
                            }
                        }
                    } else {
                        HStack {
                            Text("Loading beers...")
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            }
            .navigationTitle("Paylisher")
        }.onAppear {
            api.listBeers(completion: { beers in
                api.beers = beers
            })
            
            //locationPerm.requestWhenInUsePermission()
            //locationPerm.requestAlwaysPermissionIfNeeded()
            
            
        }
        
        .onOpenURL { url in
                   handleDeepLink(url: url)
               }
    }
    
    func handleDeepLink(url: URL) {
           print("Açılan Deep Link: \(url)")
           if url.scheme == "PaylisherExample", url.host == "yeniSayfa" {
               deepLinkDestination = "YeniSayfaView"
           }
        
       }
    
    // Define custom errors
    enum CustomError: Error {
        case invalidOperation
        case valueOutOfRange
    }

    // Function that throws errors
    func performOperation(shouldThrow: Bool) throws {
        if shouldThrow {
            throw CustomError.invalidOperation
        }
        print("Operation performed successfully.")
    }
    
    // Testing function
    func testErrorLogging() {
        do {
            // Intentionally triggering an error
            try performOperation(shouldThrow: true)
        } catch {
            // Create error properties
            let properties: [String: Any] = [
                "message": error.localizedDescription,
                "cause": (error as NSError).userInfo["NSUnderlyingError"] ?? "None",
                "stackTrace": Thread.callStackSymbols.joined(separator: "\n")
            ]
            print("testErrorLogging catch")
            // Log the error
            PaylisherSDK.shared.capture("Error", properties: properties)
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
