#!/bin/sh
# Uygulamaları derler, .app paketine koyar ve sabit sertifikayla imzalar.
#   ./build.sh                     tüm uygulamalar
#   ./build.sh alt-tab             yalnız biri
#   ./build.sh --install mac-clear derle + /Applications'a kur + aç
#
# Neden sabit sertifika: ad-hoc imza her derlemede değişir, macOS da verilen izinleri
# (Erişilebilirlik, Ekran Kaydı, Tam Disk Erişimi) unutur. Sertifika aynı kaldıkça izinler korunur.
set -e
cd "$(dirname "$0")"
CERT="mac-apps Dev"

if ! security find-certificate -c "$CERT" >/dev/null 2>&1; then
  echo "İmza sertifikası oluşturuluyor: $CERT (yalnız ilk seferde)"
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$CERT" -keyout "$T/k.pem" -out "$T/c.pem" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
  openssl pkcs12 -export -legacy -inkey "$T/k.pem" -in "$T/c.pem" -out "$T/c.p12" -passout pass:tmp
  # -x: özel anahtar anahtar zincirinden dışarı aktarılamaz; -T: yalnız codesign sorusuz kullanabilir.
  security import "$T/c.p12" -k ~/Library/Keychains/login.keychain-db -P tmp -x -T /usr/bin/codesign
fi

INSTALL=; [ "$1" = "--install" ] && { INSTALL=1; shift; }
[ $# -gt 0 ] || set -- */Info.plist
for d in "$@"; do
  d=${d%/Info.plist}; d=${d%/}
  exe=$(plutil -extract CFBundleExecutable raw "$d/Info.plist")
  name=$(plutil -extract CFBundleName raw "$d/Info.plist")
  app="$d/build/$name.app"

  swift build -c release --package-path "$d"
  pkill -x "$exe" || true  # eski süreç yeni imzalı dosyayla uyuşmaz → tekrar tekrar izin sorar
  rm -rf "$app"; mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$d/.build/release/$exe" "$app/Contents/MacOS/"
  cp "$d/Info.plist" "$app/Contents/"
  cp "$d/Resources/AppIcon.icns" "$app/Contents/Resources/" 2>/dev/null || true
  [ -x "$d/post-build.sh" ] && "$d/post-build.sh" "$app"  # eklentili uygulamalar (finder-plus, macone)
  # --options runtime: DYLD_INSERT_LIBRARIES ile koda enjeksiyon yapılıp uygulamanın izinleri ödünç alınamaz.
  ent=; [ -f "$d/app.entitlements" ] && ent="--entitlements $d/app.entitlements"  # isteğe bağlı yetkiler (finder-plus, macone)
  codesign --force --options runtime $ent --sign "$CERT" "$app"
  echo "Hazır: $app"

  if [ -n "$INSTALL" ]; then
    rm -rf "/Applications/$name.app"; cp -R "$app" /Applications/
    open "/Applications/$name.app"; echo "Kuruldu: /Applications/$name.app"
  fi
done
