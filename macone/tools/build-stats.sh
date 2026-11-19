#!/bin/sh
# exelban/stats uygulamasını Release derler ve <çıktı-klasörü>/Stats.app olarak kopyalar.
# İmzalama dış build betiğinde yapılır; burada imzasız derlenir.
# Kullanım: build-stats.sh <output-dir>
set -e
cd "$(dirname "$0")/.."

[ -n "$1" ] || { echo "Kullanım: $0 <output-dir>" >&2; exit 1; }
OUT="$1"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# Yeni klonda alt modül boş gelir
[ -f vendor/stats/Stats.xcodeproj/project.pbxproj ] || git submodule update --init vendor/stats

# Türetilmiş veri sabit yerde durur: tekrar çalıştırmada artımlı derleme hızlı olur
DD="${TMPDIR:-/tmp}/macone-stats-dd"

xcodebuild -project vendor/stats/Stats.xcodeproj -scheme Stats \
  -configuration Release -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO build -quiet

APP="$DD/Build/Products/Release/Stats.app"
[ -d "$APP" ] || { echo "Stats.app bulunamadı: $APP" >&2; exit 1; }

rm -rf "$OUT/Stats.app"
cp -R "$APP" "$OUT/Stats.app"
echo "Hazır: $OUT/Stats.app"
