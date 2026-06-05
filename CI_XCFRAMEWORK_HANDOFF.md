# Paylisher iOS — XCFramework CI/CD Kurulumu (DevOps Handoff)

> **Hedef kitle:** DevOps mühendisi
> **Amaç:** `Paylisher.xcframework` build'ini yerel Mac'ten **GitHub Actions**'a (bulut macOS runner) taşımak.
> **Repo:** `https://github.com/paylisher/PAYLISHER-SDK-IOS`
> **Bu döküman tek başına yeterlidir** — başka bağlam gerekmez.

---

## 0. TL;DR (30 saniye)

- Bugüne kadar XCFramework, [`scripts/build_xcframework.sh`](scripts/build_xcframework.sh) ile **bir geliştiricinin Mac'inde** (Xcode 16.1, yol sabit kodlanmış) alınıyordu. O Mac artık Xcode 16.1'i çalıştıramadığı için build alınamıyor.
- Çözüm: aynı script'i **GitHub'ın bulut macOS makinesinde** çalıştırmak. Build artık kimsenin lokalinde değil, CI'da olacak.
- **Kod imzalama / sertifika / provisioning GEREKMİYOR** (static library XCFramework). Bu, CI'ın en zor kısmını eler → keychain/secret kurulumu yok.
- İki aşamalı ilerliyoruz:
  - **Aşama 1 (hazır):** Build al + `Paylisher.xcframework.zip`'i indirilebilir artifact yap. Release oluşturmaz, repoya commit atmaz → **risksiz**. Amaç: bulutta build'in geçtiğini kanıtlamak.
  - **Aşama 2 (senin kuracağın):** Tag/sürüm ile otomatik **GitHub Release + zip yükleme + `Package.swift` güncelleme**.
- **Senin başlangıç noktan:** [`.github/workflows/build-xcframework.yml`](.github/workflows/build-xcframework.yml) dosyası hazır. Bunu `main`'e koy, Actions'tan elle çalıştır, yeşil yandığını gör. Sonra Aşama 2'ye geç.

---

## 1. Neden? (Problem)

Mevcut build, geliştiricinin lokalinde şu sabit yola bağlı:

```bash
# scripts/build_xcframework.sh içinde (eski hali):
export DEVELOPER_DIR="/Volumes/Mac/Uygulama 2/Xcode.app/Contents/Developer"   # Xcode 16.1
```

Geliştiricinin macOS'u güncellenince bu Xcode 16.1 sürümü artık çalışmıyor → build alınamıyor. CI'da ise **istediğimiz Xcode sürümünü** seçebiliriz, çünkü runner'ı biz belirliyoruz; yerel makine kısıtı bizi bağlamıyor.

---

## 2. Mevcut durum — bilmen gerekenler

### 2.1 Build nasıl yapılıyor

Tek script her şeyi yapıyor: [`scripts/build_xcframework.sh`](scripts/build_xcframework.sh)

| Adım | Ne yapar |
|---|---|
| 1 | `xcodebuild clean` + eski çıktıyı yedekler |
| 2 | SPM paketlerini resolve eder (`-resolvePackageDependencies`) |
| 3 | **iOS device** archive (`-sdk iphoneos`, `SKIP_INSTALL=NO`) |
| 4 | **iOS simulator** archive (`-sdk iphonesimulator`) |
| 5 | İkisini `xcodebuild -create-xcframework` ile birleştirir |
| 6 | Doğrulama (swiftinterface var mı, `_WebKit_SwiftUI` import'u **yok** mu, static lib mi) |
| 7 | `build/Paylisher.xcframework.zip` üretir + **checksum** hesaplar |

Önemli noktalar:
- Build, **`Paylisher.xcodeproj` + `Paylisher` şeması** üzerinden yapılıyor (SPM `Package.swift` üzerinden DEĞİL).
- `Paylisher` şeması **paylaşılmış (shared)** → CI runner görebilir. ✓ (`Paylisher.xcodeproj/xcshareddata/xcschemes/Paylisher.xcscheme`)
- Framework tipi: **static library** (`MACH_O_TYPE = staticlib`), "Build Libraries for Distribution" açık (library evolution → `.swiftinterface` üretir).
- Script `swift6` / `swift5` toolchain seçenekleri de barındırıyor (geriye dönük uyumluluk için). **CI'da gerekmiyor** — varsayılan Xcode toolchain'i yeterli.

### 2.2 Bağımlılıklar — Firebase build'i ETKİLEMİYOR (doğrulandı)

`Paylisher.xcodeproj`, `firebase-ios-sdk`'yı **Package Dependencies** olarak tanımlasa da, **hiçbir hedef (target) Firebase ürünü link'lemiyor** — `Paylisher` framework hedefi dâhil, örnek uygulamalar dâhil. Doğrulama:
- Xcode → Paylisher target → Build Phases → **Link Binary With Libraries = 0 items**.
- `project.pbxproj` → tüm hedeflerin `packageProductDependencies`'inde **Firebase = 0**.
- SDK kaynağında aktif Firebase `import`/kullanımı **yok** (hepsi yorum/doküman).

**Sonuç:** Firebase **derlenmiyor**. `Paylisher` framework yalnızca kendi ~89 Swift kaynağını derliyor, dışarıya hiçbir şey linklemiyor → build **hafif**. (Eski "~20–40 dk Firebase derlemesi" beklentisi **geçersiz**.)

**Geriye kalan tek pürüz:** `firebase-ios-sdk` paketi hâlâ *tanımlı* olduğu için, CI'ın **paket çözümleme (resolve)** adımı onu (+ geçişli abseil/gRPC/leveldb/GoogleAppMeasurement…) hiçbir hedef kullanmasa bile **indirir/klonlar**. Bu bir *derleme* değil *indirme* maliyetidir (cache'lenebilir).

> 🔧 **Önerilen temizlik (SDK sahibinin işi, DevOps'un değil):** Xcode → Project → Package Dependencies → `firebase-ios-sdk` → (−). Hiçbir hedef kullanmadığı için **güvenli**; resolve'u tamamen hafifletir. Doğrulama: `grep -c firebase-ios-sdk Paylisher.xcodeproj/project.pbxproj` → `0`. Yapılırsa build daha da hızlanır.

### 2.3 Dağıtım kanalları

| Kanal | Kaynak | Durum |
|---|---|---|
| **CocoaPods** | `Paylisher.podspec` (`source_files`, Firebase `dependency`'leri ile) | Birincil görünüyor; sürüm `1.8.4` |
| **SPM (kaynak)** | `Package.swift` → `Paylisher` target (`path: "Paylisher"`) | Çalışıyor |
| **SPM (binary)** | `Package.swift` → `PaylisherFramework` **binaryTarget** → GitHub release zip + checksum | **1.1.2'de takılı** (güncel değil) |

### 2.4 İmzalama GEREKMİYOR ✅

Static library XCFramework üretmek Apple sertifikası / provisioning profile / keychain istemez. `xcodebuild -create-xcframework` imzasız çalışır. **CI'da hiçbir Apple secret'ı kurmana gerek yok.** (Aşama 2'de GitHub Release için sadece repo'nun kendi `GITHUB_TOKEN`'ı yeterli.)

---

## 3. Hedef mimari

```
Geliştirici push/tag ──▶ GitHub Actions (bulut macOS runner)
                              │
                              ├─ Xcode 16.1 seç (setup-xcode)
                              ├─ scripts/build_xcframework.sh çalıştır
                              │     └─ SPM resolve + 2 archive (device+sim) + create-xcframework
                              ├─ Paylisher.xcframework.zip + checksum
                              │
                  Aşama 1 ────┴─▶ Artifact olarak yükle (indir)
                  Aşama 2 ──────▶ GitHub Release + zip + Package.swift güncelle
```

- **Runner:** GitHub-hosted `macos-15` (veya `macos-14`). İçinde Xcode hazır gelir.
- **Tetikleyici (kararlaştırıldı):** Manuel (`workflow_dispatch`) + git tag push (`1.8.5` gibi).

---

## 4. AŞAMA 1 — Build doğrulama (ÖNCE BU)

> Amaç: SDK'nın **güncel** kodunun bu tarifle bulutta hâlâ derlendiğini kanıtlamak. (Tarif, eskiden çalışan build ile birebir aynı — bkz. Bölüm 7.4 — ama güncel kod bu script'le henüz xcframework'e build edilmedi.)

### 4.1 Hazır gelenler (zaten uygulandı)

İki değişiklik repoda hazır; inceleyip değiştirebilirsin:

**(a) Workflow:** [`.github/workflows/build-xcframework.yml`](.github/workflows/build-xcframework.yml)
- `workflow_dispatch` (elle buton) + tag push tetikleyicisi
- `macos-15` runner, `setup-xcode` ile **Xcode 16.1** pin'li
- SwiftPM cache adımı
- `scripts/build_xcframework.sh` çalıştırır
- Çıktıyı `Paylisher-xcframework` artifact'ı + `build-logs`'u yükler

**(b) Script düzeltmesi:** [`scripts/build_xcframework.sh`](scripts/build_xcframework.sh) — sabit `DEVELOPER_DIR` artık **yalnızca o yol lokalde varsa** devreye giriyor; CI'da runner'ın Xcode'una dokunmuyor. **Yerel kullanım birebir aynı kalır.** Yeni hâli:

```bash
LOCAL_XCODE="/Volumes/Mac/Uygulama 2/Xcode.app/Contents/Developer"
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "$LOCAL_XCODE" ]; then
    export DEVELOPER_DIR="$LOCAL_XCODE"
fi
```
> İstersen Xcode seçimini farklı yöntemle de yapabilirsin (ör. workflow'da `DEVELOPER_DIR`'i explicit `export` etmek). Bu değişiklik minimal ve geriye dönük uyumlu olduğu için bırakıldı; senin alanın.

### 4.2 Senin yapacakların (Aşama 1)

1. **Workflow'u `main`'e koy.** ⚠️ Kritik: `workflow_dispatch` "Run workflow" butonu **yalnızca workflow dosyası default branch'te (`main`) ise** Actions UI'da görünür. Şu an dosya `version-1.8.5` dalında. Branch'i merge et ya da en azından bu `.yml`'i `main`'e taşı.
2. **Actions** sekmesi → **"Build XCFramework"** → **"Run workflow"** → branch seç → **Run**.
3. Build'i izle. **İlk run ~5–15 dk** (Firebase derlenmiyor; süre çoğunlukla SPM resolve + 2 archive). Yeşil yanmasını bekle.
4. Run sayfasının altından **Artifacts → `Paylisher-xcframework`**'ü indir, içindeki `Paylisher.xcframework.zip`'i bir test projesinde import et.

### 4.3 Kabul kriteri (Aşama 1 "bitti" demek)

- [ ] Workflow yeşil tamamlanıyor.
- [ ] `Paylisher-xcframework` artifact'ı iniyor ve içinde geçerli bir `Paylisher.xcframework` var.
- [ ] Script'in doğrulama adımları geçiyor (swiftinterface var, `_WebKit_SwiftUI` yok, static lib).
- [ ] (İdeal) Artifact bir örnek projeye import edilip derleniyor.

### 4.4 İlk run'da göz kulak olunacaklar

| Belirti | Olası sebep / çözüm |
|---|---|
| `setup-xcode` "version not found" | Runner image'ında 16.1 yok. `.yml`'de `xcode-version`'ı listelenen bir 16.x'e (ör. `16.2`) çek. Library-evolution sayesinde yeni 16.x tüketiciler için güvenli. Mevcut sürümler: [actions/runner-images](https://github.com/actions/runner-images). |
| Firebase resolve hatası / "duplicate package" | `firebase-ios-sdk` hâlâ tanımlı (ve birden çok yinelenen referansı var) ama hiçbir hedef kullanmıyor. En temiz çözüm: paketi komple kaldır (Bölüm 2.2). Resolve hatası ortadan kalkar. |
| Build beklenenden uzun | `timeout-minutes` 30'a ayarlı (bol bol yeter; Firebase derlenmiyor). Süre uzarsa SPM cache'i (Bölüm 6.2) ekle. |
| `Paylisher.framework not found in archive` | Şema/derived data sorunu; build loglarını (`build-logs` artifact) incele. |

---

## 5. AŞAMA 2 — Release otomasyonu (senin kuracağın)

> Aşama 1 yeşil yandıktan **sonra**. Hedef: tek tetiklemeyle build → GitHub Release → zip yükle → `Package.swift` güncelle.

### 5.1 Hedef akış

```
bump version ─▶ build (zip + checksum) ─▶ Package.swift güncelle
   ─▶ commit ─▶ tag (checksum'lı commit'e!) ─▶ GitHub Release + zip yükle
```

### 5.2 ⚠️ KRİTİK: Checksum "yumurta-tavuk" problemi

SPM binary dağıtımında ince bir tuzak var:
- Tüketici `X.Y.Z` tag'inden paketi çözerken, **o tag'deki `Package.swift`** içindeki `binaryTarget` checksum'ı, **o tag'den build edilen zip'in** checksum'ı ile eşleşmek zorunda.
- Ama zip'in checksum'ı ancak build **bittikten sonra** belli olur — yani tag oluştuktan sonra. Klasik yumurta-tavuk.

**Çözüm: sıralamayı doğru kur.** Tag'i, checksum'ı içeren commit'e işaret edecek şekilde **build'den SONRA** at:

> bump → **build → checksum → Package.swift güncelle → commit → tag → release+upload**

Bu yüzden Aşama 2'yi **tag push ile değil**, `workflow_dispatch` (sürüm input'u ile) çalıştırmak daha temizdir; workflow tag'i kendisi atar.

### 5.3 ⚠️ KRİTİK: İsim uyuşmazlığı (karar verilmeli)

Şu an tutarsızlık var:
- Script `Paylisher.xcframework.zip` üretiyor (şema adı `Paylisher`).
- `Package.swift`'teki binaryTarget ise `PaylisherFramework.xcframework.zip` bekliyor (ve `1.1.2`'de sabit; `PaylisherFramework` adında paylaşılmış şema **yok**).

**Aşama 2'den önce netleştirilmeli (SDK sahibi + sen):** binary SPM ürünü hangi isimle dağıtılacak?
- **Seçenek A:** Script çıktısını `PaylisherFramework.xcframework.zip` yap (binaryTarget'a uyacak şekilde) ve binaryTarget URL+checksum'ını her sürümde güncelle.
- **Seçenek B:** binaryTarget'ı `Paylisher.xcframework.zip`'e repoint et / yeniden adlandır.
- **Seçenek C:** Binary SPM kanalı şimdilik kullanılmıyorsa (birincil dağıtım CocoaPods kaynak), Aşama 2 yalnızca Release'e zip ekler, `Package.swift` güncellemesini sonraya bırakır.

### 5.4 Referans workflow (uyarlanacak — `release-xcframework.yml`)

```yaml
name: Release XCFramework
on:
  workflow_dispatch:
    inputs:
      version:
        description: "Sürüm (ör. 1.8.5)"
        required: true

permissions:
  contents: write          # Release oluşturmak + Package.swift commit'lemek için

jobs:
  release:
    runs-on: macos-15
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
        with: { ref: main }

      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: '16.1' }

      # 1) Sürüm bump (podspec + PaylisherVersion.swift)
      #    NOT: scripts/bump-version.sh içindeki PaylisherVersion.swift YOLUNU doğrula —
      #    dosya gerçekte Paylisher/Paylisher/PaylisherVersion.swift altında.
      - run: ./scripts/bump-version.sh "${{ inputs.version }}"

      # 2) Build (zip + checksum üretir)
      - run: |
          chmod +x scripts/build_xcframework.sh
          ./scripts/build_xcframework.sh

      # 3) Checksum'ı oku
      - id: cs
        run: echo "checksum=$(swift package compute-checksum build/Paylisher.xcframework.zip)" >> "$GITHUB_OUTPUT"

      # 4) Package.swift güncelle (binaryTarget url + checksum)
      #    Bölüm 5.3'teki isim kararına göre URL/dosya adını ayarla.
      - run: |
          VER="${{ inputs.version }}"
          URL="https://github.com/paylisher/PAYLISHER-SDK-IOS/releases/download/${VER}/Paylisher.xcframework.zip"
          perl -0pi -e "s|url: \"[^\"]*\"|url: \"$URL\"|" Package.swift
          perl -0pi -e "s|checksum: \"[^\"]*\"|checksum: \"${{ steps.cs.outputs.checksum }}\"|" Package.swift

      # 5) Commit + tag (tag, checksum'lı commit'e işaret etsin!)
      - run: |
          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Package.swift Paylisher.podspec Paylisher/Paylisher/PaylisherVersion.swift
          git commit -m "release: ${{ inputs.version }}"
          git tag "${{ inputs.version }}"
          git push origin HEAD:main --tags

      # 6) GitHub Release + zip yükle
      - uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ inputs.version }}
          files: build/Paylisher.xcframework.zip
          generate_release_notes: true
```

> Bu bir **referans iskelet**tir — secret yok, sadece `GITHUB_TOKEN` (otomatik). İsim kararına (5.3), checksum sırasına (5.2) ve bump-version yoluna göre uyarlamak senin işin.

### 5.5 CocoaPods (opsiyonel)

Birincil dağıtım CocoaPods ise, release sonrası `pod trunk push` da otomatikleştirilebilir (`make releaseCocoaPods` zaten var). Bunun için `pod trunk` oturum token'ı **secret** olarak gerekir (`COCOAPODS_TRUNK_TOKEN`). İstenirse ayrı bir adım/iş olarak eklenir.

---

## 6. Script'e olası eklemeler / ayarlar (senin alanın)

Script "eski" — CI'a göre ince ayar gerekebilir. Öncelik sırasıyla:

| # | Konu | Öneri |
|---|---|---|
| 1 | **DEVELOPER_DIR** | ✅ Zaten yapıldı (4.1.b). CI'da runner Xcode'unu kullanır. |
| 2 | **Caching (resolve süresi)** | `firebase-ios-sdk` kaldırılmazsa resolve onu hâlâ klonlar. `xcodebuild`'e **`-clonedSourcePackagesDirPath .spm-cache`** ekleyip o klasörü `actions/cache` ile cache'le → tekrar klonlamaz. (Firebase paketi kaldırılırsa büyük ölçüde gereksizleşir; Quick/Nimble için yine de faydalı.) |
| 3 | **İsim uyuşmazlığı** | Bölüm 5.3 — SDK sahibiyle karara bağla. |
| 4 | **Kullanılmayan Firebase paketi** | `firebase-ios-sdk` (ve yinelenen referansları) projede tanımlı ama **hiçbir hedef kullanmıyor**. En temizi komple kaldırmak (Bölüm 2.2) — güvenli ve resolve'u hızlandırır. Bu bir Xcode/SDK işi (DevOps değil). |
| 5 | **`BUILD_LIBRARY_FOR_DISTRIBUTION`** | Şu an proje ayarından geliyor (çalışıyor). İstersen `xcodebuild archive`'a explicit `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` geçip garanti altına al. |
| 6 | **bump-version.sh yolu** | `Paylisher/PaylisherVersion.swift` yazıyor ama dosya `Paylisher/Paylisher/PaylisherVersion.swift` altında — **doğrula/düzelt** (Aşama 2 için). |
| 7 | **`set -euo pipefail`** | Script `set -e` kullanıyor. CI'da hata yakalamayı sıkılaştırmak için `set -o pipefail` eklenebilir (loglar `tee`'ye pipe'lanıyor; gerçek exit code maskelenebilir). |

---

## 7. Tuzaklar / SSS

**7.1 "Run workflow" butonu görünmüyor.**
Workflow dosyası default branch'te (`main`) değil. `main`'e koy.

**7.2 macOS runner maliyeti.**
- Repo **public** ise GitHub Actions (macOS dâhil) **ücretsiz/sınırsız**.
- Repo **private** ise macOS dakikaları **10× çarpanla** sayılır (ücretsiz kotayı hızlı tüketir). Bu yüzden tetikleyici "her push" değil, **manuel + tag**. Repo görünürlüğünü kontrol et: `gh repo view paylisher/PAYLISHER-SDK-IOS --json visibility`.

**7.3 Neden imzalama yok?**
Static library XCFramework imzasız üretilir; consumer kendi uygulamasını imzalar. CI'da Apple cert/keychain kurulumuna gerek yok.

**7.4 "Build gerçekten çalışacak mı?" — kanıt durumu.**
Bu build tarifi (script + şema + static-framework target + Xcode 16.1), eskiden çalışan **`PAYLISHER-FW-IOS`** reposundaki build ile **birebir aynı** (script byte-byte aynı, şema aynı). Fark: `PAYLISHER-SDK-IOS` daha yeni (3 ek kaynak dosya, sürüm 1.8.x). Her iki repoda da Firebase hiçbir hedefe link'li **değil** — yani Firebase build'i hiç etkilemiyor. Tarif kanıtlı; Aşama 1 sadece *güncel kodun* da bu tarifle derlendiğini teyit eder.

**7.5 Toolchain (swift5/swift6) seçenekleri?**
Script'te var ama CI'da gereksiz. Runner'ın varsayılan Xcode 16.1 toolchain'i yeterli. `-t` parametresi vermiyoruz.

---

## 8. Maliyet & runner özeti

| Öğe | Değer |
|---|---|
| Runner | `macos-15` (GitHub-hosted) |
| Xcode | 16.1 (`setup-xcode` ile pin) |
| Tahmini build süresi | İlk: ~5–15 dk (Firebase derlenmiyor), cache sonrası: daha kısa |
| Tetikleme sıklığı | Manuel + tag (sürüm başına ~1 build) |
| Secret ihtiyacı | Aşama 1: **yok**. Aşama 2: sadece otomatik `GITHUB_TOKEN` (+ opsiyonel CocoaPods token) |

---

## 9. Referans dosyalar

| Dosya | Açıklama |
|---|---|
| [`.github/workflows/build-xcframework.yml`](.github/workflows/build-xcframework.yml) | Aşama 1 workflow (hazır) |
| [`scripts/build_xcframework.sh`](scripts/build_xcframework.sh) | Ana build script (DEVELOPER_DIR düzeltmesi uygulandı) |
| `Paylisher.xcodeproj/xcshareddata/xcschemes/Paylisher.xcscheme` | Build'i süren paylaşılmış şema |
| [`Package.swift`](Package.swift) | SPM; `PaylisherFramework` binaryTarget (1.1.2'de sabit — Aşama 2'de güncellenecek) |
| [`Paylisher.podspec`](Paylisher.podspec) | CocoaPods; sürüm 1.8.4 |
| [`scripts/bump-version.sh`](scripts/bump-version.sh) | Sürüm bump (yol doğrulanmalı — Bölüm 6.6) |
| [`RELEASING.md`](RELEASING.md) | Mevcut (elle) release prosedürü |

---

### Özet — ilk gün ne yap?

1. Bu dökümanı oku.
2. [`.github/workflows/build-xcframework.yml`](.github/workflows/build-xcframework.yml)'i `main`'e taşı.
3. Actions → Build XCFramework → Run workflow → yeşil yanana kadar izle (Bölüm 4.4'teki tabloyla sorun gider).
4. Artifact'ı indir, doğrula → **Aşama 1 bitti.**
5. Caching'i ekle (Bölüm 6.2), sonra Aşama 2 release otomasyonunu kur (Bölüm 5).
