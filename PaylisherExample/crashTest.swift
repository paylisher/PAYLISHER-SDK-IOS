//
//  crashTest.swift
//  Paylisher
//
//  Created by Yusuf Uluşahin on 18.12.2025.
//

import SwiftUI
import Paylisher

struct CrashTestView: View {
    
    private var zero: Int {
        return [Int]().count
    }
    
    var body: some View {
        VStack {
            Text("Bu ekranı görmemen lazım")
        }
        .navigationTitle("Crash Test")
        .onAppear {
            // Sayfa açıldığı anda crash
            let _ = 10 / zero
        }
    }
}
