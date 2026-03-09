//
//  PaylisherScreenMapper.swift
//  Paylisher
//
//  Created by Paylisher on 02.02.26.
//

import Foundation

class PaylisherScreenMapper {
    static let shared = PaylisherScreenMapper()
    
    private var screenMap: [String: String] = [:]
    private var isLoaded = false
    
    private init() {}
    
    private func loadMapping() {
        if isLoaded { return }
        
        defer { isLoaded = true }
        
        guard let path = Bundle.main.path(forResource: "paylisher_screens", ofType: "json") else {
            print("[Paylisher] ℹ️ paylisher_screens.json not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                screenMap = json
                print("[Paylisher] ✅ Loaded \(screenMap.count) screen mappings.")
            }
        } catch {
            print("[Paylisher] ⚠️ Error loading paylisher_screens.json: \(error.localizedDescription)")
        }
    }
    
    func screenName(for className: String) -> String? {
        loadMapping()
        return screenMap[className]
    }
}
