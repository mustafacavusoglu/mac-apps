#!/bin/sh
# build.sh çağırır: Finder eklentisini (tabula kaynağından) ve Stats'ı uygulamanın içine koyar, imzalar.
# Kullanım: post-build.sh <macOne.app>
set -e
app=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")  # cd'den önce mutlak yap
cd "$(dirname "$0")"
CERT="mac-apps Dev"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# 1) Finder eklentisi: Tabula ile aynı kaynak, aynı kimlik.
x="$app/Contents/PlugIns/NewFileFinder.appex"
mkdir -p "$x/Contents/MacOS"
swiftc -O -parse-as-library -application-extension -module-name NewFileFinder -framework FinderSync \
  -Xlinker -e -Xlinker _NSExtensionMain -o "$x/Contents/MacOS/NewFileFinder" ../tabula/Extension/*.swift ../tabula/Shared/*.swift
cp ../tabula/Extension/Info.plist "$x/Contents/"
codesign --force --options runtime --entitlements ../tabula/Extension/ext.entitlements --sign "$CERT" "$x"

# 2) Stats: vendor/stats'tan derlenir, uygulamanın Resources klasörüne konur.
./tools/build-stats.sh "$T"
rm -rf "$app/Contents/Resources/Stats.app"
cp -R "$T/Stats.app" "$app/Contents/Resources/"
# İçten dışa imza (önce iç paketler, en son uygulama); --deep çerçeveleri yeniden imzalamıyordu.
# Kendinden imzalı sertifikada Team ID olmadığı için Stats'a stats.entitlements verilir (bkz. dosya).
s="$app/Contents/Resources/Stats.app"
find "$s/Contents" -depth \( -name "*.framework" -o -name "*.appex" -o -name "*.app" -o -name "*.xpc" -o -name "*.dylib" \) \
  -exec codesign --force --options runtime --sign "$CERT" {} \;
codesign --force --options runtime --entitlements stats.entitlements --sign "$CERT" "$s"
