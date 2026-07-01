#!/bin/bash

# ./scripts/bump-version.sh <new version>
# eg ./scripts/bump-version.sh "1.8.7"   /   "3.0.0-alpha.1"
#
# TEK KAYNAK ilkesi: SDK sürümü iki dosyada görünür; bu script ikisini de BİRLİKTE günceller:
#   1) Paylisher/Paylisher/PaylisherVersion.swift -> paylisherVersion
#      (PaylisherSDK.sdkVersion() bunu döndürür => $lib_version VE $sdk_package_version buradan gelir)
#   2) Paylisher.podspec -> s.version
# Sonunda her iki değişikliği DOĞRULAR. Yol/regex bozulursa sessizce geçmez, FAIL eder.
# (Önceki sürümün hatası buydu: yanlış dosya yolu + tek/çift tırnak uyuşmazlığı -> sessiz no-op.)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

if [ "$#" -lt 1 ] || [ -z "${1:-}" ]; then
  echo "Kullanım: ./scripts/bump-version.sh <yeni-surum>   (ör. 1.8.7)" >&2
  exit 1
fi
NEW_VERSION="$1"

VERSION_FILE="Paylisher/Paylisher/PaylisherVersion.swift"
PODSPEC_FILE="Paylisher.podspec"

[ -f "$VERSION_FILE" ] || { echo "HATA: $VERSION_FILE bulunamadı" >&2; exit 1; }
[ -f "$PODSPEC_FILE" ] || { echo "HATA: $PODSPEC_FILE bulunamadı" >&2; exit 1; }

# 1) paylisherVersion (çift tırnaklı Swift literal)
perl -pi -e "s/paylisherVersion = \".*\"/paylisherVersion = \"$NEW_VERSION\"/" "$VERSION_FILE"

# 2) podspec s.version (tek VEYA çift tırnak, değişken boşluk) -> tek tırnaklı yazar
perl -pi -e "s/(s\.version\s*=\s*)['\"].*?['\"]/\${1}'$NEW_VERSION'/" "$PODSPEC_FILE"

# 3) DOĞRULA — sessiz no-op'a asla izin verme
grep -q "paylisherVersion = \"$NEW_VERSION\"" "$VERSION_FILE" \
  || { echo "HATA: $VERSION_FILE güncellenemedi (paylisherVersion = \"$NEW_VERSION\" bulunamadı)" >&2; exit 1; }
grep -Eq "s\.version[[:space:]]*=[[:space:]]*['\"]${NEW_VERSION}['\"]" "$PODSPEC_FILE" \
  || { echo "HATA: $PODSPEC_FILE güncellenemedi (s.version = $NEW_VERSION bulunamadı)" >&2; exit 1; }

echo "✅ Sürüm $NEW_VERSION olarak ayarlandı ve doğrulandı:"
echo "   - $VERSION_FILE  (paylisherVersion -> \$lib_version & \$sdk_package_version)"
echo "   - $PODSPEC_FILE  (s.version)"
