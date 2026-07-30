//
//  Hedgelog.swift
//  Paylisher
//
//  Created by Ben White on 07.02.23.
//

import Foundation

var hedgeLogEnabled = false

func toggleHedgeLog(_ enabled: Bool) {
    hedgeLogEnabled = enabled
}

// Meant for internally logging Paylisher related things
func hedgeLog(_ message: String) {
    if !hedgeLogEnabled { return }
    Swift.print("[Paylisher] \(message)")
}

/// Hata ayıklama bayrağına bağlı `print`.
///
/// Swift ad çözümlemesi modül düzeyindeki bildirimi standart kütüphanenin
/// üzerinde tercih eder, bu yüzden Paylisher modülü içindeki her `print(...)`
/// çağrısı çağrı yeri değiştirilmeden bu fonksiyona düşer. `hedgeLogEnabled`
/// kapalıyken hiçbir şey yazılmaz.
///
/// Gerekçe: `print` çıktısı yapılandırmadan bağımsız olarak cihaz konsoluna
/// gider ve release derlemesinde de kalır; SDK'nın işlediği bildirim içeriği ve
/// kayıt kimlikleri bu yolla görünür olabilir (CWE-532, MASVS-STORAGE-3).
///
/// Bu bildirim `internal`'dır, yani yalnızca bu modülün derlenmesini etkiler.
/// SDK'yı entegre eden uygulamanın kendi `print` çağrıları standart kütüphaneye
/// gitmeye devam eder.
///
/// Koşulsuz yazmak gerekirse `Swift.print(...)` açıkça çağrılır.
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if !hedgeLogEnabled { return }
    Swift.print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
}
