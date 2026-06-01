//
//  PaylisherFontRegistry.swift
//  Paylisher
//
//  Created by Codex on 2026-05-18.
//
//  Runtime registration + lookup for the bundled Inter font face.
//  The SDK ships Inter (Regular / Bold / Italic / BoldItalic) inside
//  `Paylisher/Resources/Fonts/` so the iOS render path can measure +
//  wrap text with the same font metrics as the Android SDK and the
//  Studio preview — both of which also ship the SAME TTFs.
//
//  Without a shared font, the three layers fall back to platform
//  defaults (SF Pro on iOS / Roboto on Android / Segoe-UI-or-whatever
//  on the host browser) — same authored text wraps at a slightly
//  different word on each platform, which is exactly the symptom the
//  product team has been hunting.
//

import Foundation
import UIKit
import CoreText

/// Loads the bundled Inter font face into the iOS font system on first
/// use, then hands back `UIFont` instances by weight / style / size.
///
/// Registration is idempotent and threadsafe — `dispatch_once`-style
/// flag guards the CTFontManager calls so a second invocation is a
/// no-op even if it races with the first.
public enum PaylisherFontRegistry {

    /// One-shot guard so we only register the TTFs once per process.
    private static var didRegister = false
    private static let registerQueue = DispatchQueue(label: "com.paylisher.fontRegistry")

    /// Name → file mapping. Matches the PostScript name embedded in the
    /// .ttf (verified with `file Inter-Regular.ttf`) so `UIFont(name:)`
    /// resolves correctly after registration.
    private static let interVariants: [(psName: String, fileName: String)] = [
        ("Inter-Regular",    "Inter-Regular"),
        ("Inter-Bold",       "Inter-Bold"),
        ("Inter-Italic",     "Inter-Italic"),
        ("Inter-BoldItalic", "Inter-BoldItalic"),
    ]

    /// Register all Inter TTFs with CTFontManager. Safe to call from
    /// any thread; the first call performs the work, subsequent calls
    /// return immediately. Calls itself lazily from `interFont(...)`.
    public static func registerInterFontsIfNeeded() {
        registerQueue.sync {
            guard !didRegister else { return }
            didRegister = true

            // Look the framework bundle up by anchor type — works whether
            // the SDK is statically linked, dynamically linked, or
            // installed via SPM/CocoaPods/Carthage (the bundle of
            // `PaylisherFontRegistry.self` resolves to whichever .framework
            // / .bundle currently owns this class).
            let bundle = Bundle(for: BundleAnchor.self)

            for variant in interVariants {
                // Try `Fonts/<name>.ttf` first (production layout),
                // then `<name>.ttf` at bundle root (fallback for
                // hand-imported single-file copies).
                let candidates: [URL?] = [
                    bundle.url(forResource: variant.fileName, withExtension: "ttf", subdirectory: "Fonts"),
                    bundle.url(forResource: variant.fileName, withExtension: "ttf"),
                ]
                guard let url = candidates.compactMap({ $0 }).first else {
                    print("PAYLISHER_FONT | Inter variant missing in bundle: \(variant.fileName).ttf")
                    continue
                }

                var error: Unmanaged<CFError>?
                let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
                if !ok {
                    // `kCTFontManagerErrorAlreadyRegistered` (105) is benign —
                    // it just means a previous run / another framework already
                    // registered the same face. Anything else, log loudly.
                    let cfErr = error?.takeRetainedValue()
                    let code = (cfErr.map { CFErrorGetCode($0 as CFError) }) ?? -1
                    if code == 105 {
                        print("PAYLISHER_FONT | Inter \(variant.psName) already registered (process scope) — ok")
                    } else {
                        print("PAYLISHER_FONT | Failed to register \(variant.psName) — code=\(code)")
                    }
                } else {
                    print("PAYLISHER_FONT | Registered \(variant.psName) from \(url.lastPathComponent)")
                }
            }
        }
    }

    /// Resolve an Inter `UIFont` for the requested weight + italic +
    /// size combination. Triggers registration on first call. Falls
    /// back to the system font of the same weight if the Inter face
    /// cannot be loaded (e.g. host app stripped the TTFs from the
    /// bundle) — so the SDK never crashes on missing assets, it just
    /// degrades to the host platform default.
    public static func interFont(
        size: CGFloat,
        bold: Bool = false,
        italic: Bool = false
    ) -> UIFont {
        registerInterFontsIfNeeded()
        let psName: String
        switch (bold, italic) {
        case (true,  true):  psName = "Inter-BoldItalic"
        case (true,  false): psName = "Inter-Bold"
        case (false, true):  psName = "Inter-Italic"
        case (false, false): psName = "Inter-Regular"
        }
        if let f = UIFont(name: psName, size: size) {
            return f
        }
        // Fallback to system font with the matching weight + italic
        // descriptor so layout doesn't collapse if the asset is missing.
        let weight: UIFont.Weight = bold ? .bold : .regular
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if italic, let descriptor = base.fontDescriptor.withSymbolicTraits(
            base.fontDescriptor.symbolicTraits.union(.traitItalic)
        ) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    // MARK: - Private anchor

    /// Empty class used solely so `Bundle(for:)` resolves to the
    /// framework that hosts this file. A free function would force us
    /// to use `Bundle.main`, which is the HOST app bundle when the
    /// SDK is consumed as a framework — wrong place to look for our
    /// Resources/Fonts directory.
    private final class BundleAnchor {}
}
