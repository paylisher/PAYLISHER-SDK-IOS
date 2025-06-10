//
//  LocationManager.swift
//  PaylisherExample
//
//  Created by Rasim Burak Kaya on 6.05.2025.
//

import CoreLocation
import SwiftUI

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()
    
    public override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.status = status
            print("Konum izni durumu değişti: \(status)")
        }
        
        switch status {
        case .notDetermined:
            
            break
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("Her Zaman izni alındı, geofence izleme için hazır.")
        case .denied, .restricted:
            print("Konum izni reddedildi veya kısıtlı: \(status)")
        @unknown default:
            break
        }
    }
}
