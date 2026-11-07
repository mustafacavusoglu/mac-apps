#!/bin/sh
# build.sh çağırır: Finder eklentisini derleyip uygulamanın içine koyar ve imzalar. Kullanım: post-build.sh <App.app>
set -e
app=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")  # cd'den önce mutlak yap
cd "$(dirname "$0")"
CERT="mac-apps Dev"
x="$app/Contents/PlugIns/NewFileFinder.appex"
mkdir -p "$x/Contents/MacOS"
swiftc -O -parse-as-library -application-extension -module-name NewFileFinder -framework FinderSync \
  -Xlinker -e -Xlinker _NSExtensionMain -o "$x/Contents/MacOS/NewFileFinder" Extension/FinderSync.swift
cp Extension/Info.plist "$x/Contents/"
codesign --force --options runtime --entitlements Extension/ext.entitlements --sign "$CERT" "$x"
