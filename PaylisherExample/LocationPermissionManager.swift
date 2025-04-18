//
//  LocationPermissionManager.swift
//  PaylisherExample
//
//  Created by Rasim Burak Kaya on 17.04.2025.
//

import CoreLocation
import SwiftUI

final class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var status: CLAuthorizationStatus = .notDetermined
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    
    func askPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    /*func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        print("Konum izni durumu → ", status.rawValue)
    }*/
}

