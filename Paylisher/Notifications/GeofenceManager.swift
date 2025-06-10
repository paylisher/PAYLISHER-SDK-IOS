//
//  GeofenceManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 6.05.2025.
//

import CoreLocation
import Foundation

final class GeofenceManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = GeofenceManager()
    
    public let manager = CLLocationManager()
    private var monitoredRegions: [String: CLCircularRegion] = [:]
    private(set) var currentLocation: CLLocation?
    
    private override init() {
        super.init()
        manager.delegate = self
    }
    
    func addGeofence(latitude: Double, longitude: Double, radius: Double, geofenceId: String, trigger: String) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: geofenceId)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        monitoredRegions[geofenceId] = region
        
        print("Monitored Regions: \(monitoredRegions)")
        print("Center: \(center)")
        print("Region: \(region)")
        print("Geofence eklendi: \(geofenceId), Trigger: \(trigger)")
    }
    
    func startGeofencing() {
        // İzin kontrolü yok, "Her Zaman" izninin alındığı varsayılıyor
        startBackgroundLocationUpdates()
        print("Geofence izleme başlatıldı.")
    }
    
    func stopGeofencing() {
        for region in monitoredRegions.values {
            manager.stopMonitoring(for: region)
        }
        monitoredRegions.removeAll()
        print("Geofence izleme durduruldu.")
    }
    
    private func startBackgroundLocationUpdates() {
   
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = latest
            //print("Güncel Konum: \(latest.coordinate.latitude), \(latest.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Bölgeye girildi: \(region.identifier)")
        NotificationManager.shared.setInside(true, for: region.identifier)
        
        print("region: \(region.identifier)")
        
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Bölgeden çıkıldı: \(region.identifier)")
        if NotificationManager.shared.wasInside(region.identifier) {
            //NotificationManager.shared.setInside(false, for: region.identifier)
            print("s")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("GeofenceManager: İzin durumu değişti, ancak aksiyon alınmıyor: \(status)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofence hatası: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Konum güncelleme hatası: \(error.localizedDescription)")
    }
}
