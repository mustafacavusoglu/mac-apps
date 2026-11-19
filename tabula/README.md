# Tabula

<img src="docs/icon.png" width="96" align="right">

Windows'tan gelenlerin Finder'da aradığı sağ tık seçeneklerini ekler: **Yeni Dosya**, **Kes / Buraya Taşı** ve **Burada Terminal Aç**. macOS'ta bunlar hazır gelmez. Tabula hepsini bir Finder eklentisiyle sağlar.

## Sağ tık menüsü

| Nerede | Seçenek | Ne yapar |
|---|---|---|
| Klasörün boş yeri | **Yeni Dosya ▸** | Seçilen türde boş dosya oluşturur. |
| Klasörün boş yeri | **Burada Terminal Aç** | Terminal'i o klasörde açar. |
| Seçili dosya/klasörler | **Kes** | Öğeleri taşınmak üzere işaretler (Windows'taki Ctrl+X). |
| Klasörün boş yeri | **Kesilen N Öğeyi Buraya Taşı** | İşaretli öğeleri o klasöre taşır. Yalnız kesilmiş öğe varken görünür. Ad çakışırsa "ad 2" olur. |

## Kısayollar

Finder öndeyken:

| Kısayol | Ne yapar |
|---|---|
| **⌘X** | Seçili öğeleri keser (taşınmak üzere işaretler). |
| **⌘V** | Kesilmiş öğe varsa onları açık klasöre taşır. Yoksa normal yapıştırma çalışır. |
| **⌘C** | Kesmeyi iptal eder. |

Yeniden adlandırma veya arama gibi metin alanı odaktayken kısayollara dokunulmaz. Kısayollar için Tabula arka planda çalışır ve oturum açılınca kendiliğinden başlar. İki izin gerekir: **Erişilebilirlik** (Sistem Ayarları → Gizlilik ve Güvenlik) ve Finder'ı denetmek için **Otomasyon**. İlk ⌘X'te macOS "Tabula, Finder'ı denetlemek istiyor" diye sorar: **İzin Ver**'e basın. O ilk kesme kaybolabilir, ⌘X'i bir kez daha yapın. Sağ tık menüsü bu izinler olmadan da çalışır.

## Yeni Dosya türleri

txt, md, json (içinde `{}`), csv, html, py ve sh (`#!/bin/sh` satırıyla).

Dosya "Yeni Dosya.txt" adıyla oluşur, ad doluysa "Yeni Dosya 2.txt" olur. Finder dosyayı seçili gösterir.

## Kurulum

Deponun kökünden:

```bash
./build.sh --install tabula   # derle, /Applications'a kur ve aç
./build.sh tabula             # yalnız derle → tabula/build/Tabula.app
```

Gereksinimler ve imza sertifikası için [ana README](../README.md)'ye bakın.

Tabula'yı açın. Eklentiyi kaydeder ve Finder'ı yeniden başlatır (her sürümde bir kez). Eklentiyi kaydeder ve Finder'ı yeniden başlatır. Menü görünmezse: Sistem Ayarları → Genel → Oturum Açma Öğeleri ve Eklentiler → Finder → **Yeni Dosya**'yı açın.

## Yeni tür eklemek

[`Extension/Types.swift`](Extension/Types.swift) içindeki `types` listesine bir satır ekleyin (başlık, uzantı, ilk içerik), sonra `./build.sh --install tabula` çalıştırın.

## Nasıl çalışır

- Ana uygulama (`Sources/Tabula/`): `main.swift` eklentiyi etkinleştirir. `Sources/TabulaKit/` (kütüphane, macOne da kullanır): `Shortcuts.swift` ⌘X/⌘V'yi dinler, `Public.swift` genel API.
- `Shared/` hem uygulamada hem eklentide derlenen ortak kod: kesilenler listesi (`~/Library/Application Support/Tabula/cut.txt`) ve taşıma.
- Eklenti (`Extension/`) bir Finder Sync eklentisidir: `FinderSync.swift` menüyü kurar, `Actions.swift` işi yapar, `Files.swift` dosya yardımcılarını, `Types.swift` dosya türlerini tutar. Sandbox ister. Her klasöre yazabilmesi için `/` yolu için geçici yazma istisnası alır.
- Ana uygulama hardened runtime ile imzalanır. Finder'a AppleScript gönderebilmesi için `app.entitlements` içindeki `automation.apple-events` yetkisi ve Info.plist'teki `NSAppleEventsUsageDescription` şart. İkisinden biri eksikse macOS izin sorusunu hiç göstermeden reddeder. `build.sh` bu dosyayı kendiliğinden kullanır.
- `post-build.sh`, `build.sh` tarafından çağrılır. Eklentiyi derleyip uygulamanın içine koyar ve imzalar.
- Uygulama ağ erişimi kullanmaz.
- İkon: `swift tools/make_icon.swift` (tabula klasöründen).
