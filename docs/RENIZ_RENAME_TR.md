# RENIZ — marka geçişi ve veri uyumluluğu (19 Kasım 2026)

**Ad:** RENIZ = renk + iz. Anlamı: “Renklerle iz bırak”. Kısa, iki heceli ve Türkçe/Azerbaycanca kolay okunur. Arama sonuçları tescil veya benzersizlik garantisi değildir.

## Mevcut projenin korunması

Bu değişiklik ARTPULSE v0.1.0 kaynaklarının devamıdır; sıfırdan yazılmış yeni uygulama değildir.

- Flutter paket adı `reniz` olur. Dart `package:reniz/` importları yenilenmiştir.
- Görünür ad: Android, iOS, macOS, Windows, Linux, web/PWA ve uygulama içi metinlerde RENIZ.
- Görsel marka: var olan orijinal dalga simgesi korunur, TV banner yazısı yeniden oluşturulur.
- Yeni JSON/PNG dışa aktarma adları RENIZ ile başlar. Yeni JSON uzantısı `.reniz.json` olur.
- Eski `.artpulse.json` dosyaları JSON dosya seçicisinden açılabilir; `ProjectCodec` şema 1 değişmemiştir.
- **Android applicationId ve Kotlin package `dev.artpulse.artpulse` değişmez**. Android güncellemede kayıt korunmasına yardımcı olmak içindir. Aynı imza anahtarı yine gereklidir.
- **iOS/macOS bundle identifier `dev.artpulse.artpulse` değişmez**. Uygulama adının değişmesi yeni uygulama kurulumunu zorunlu kılmasın diye.
- **Kayıt dizini `artpulse_projects`, web IndexedDB `artpulse-studio`, kanal isimleri `dev.artpulse/...` değişmez.** Adlar uygulama içinde kullanıcıya görünmez; otomatik veri taşıma/kaybı riski yaratmamak için korunur.
- Web PWA `id` ve `scope` değişmez; önceki offline service worker yolu şimdilik korunur.
- Proje JSON şeması ve beş sanat modu aynıdır.

## Doğrulama durumu

Kaynak dosyalarına statik tutarlılık kontrolü yapıldı. Bu ortamda Flutter/Dart SDK bulunmadığından `flutter analyze`, `flutter test` veya Android/Windows/iOS yeni paket derlemeleri **çalıştırılmadı**. `docs/evidence` önceki ARTPULSE v0.1.0 kanıtlarıdır; RENIZ test kanıtı olarak sunulmaz.

## Yeni sürüm çıkarmadan önce

1. Flutter 3.50.0 SDK üzerinde `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`.
2. Android APK ve web/PWA build; sürüm 0.1.1+2. iOS/macOS ve Windows/Linux ayrı CI işleri.
3. Android eski kurulum varsa imza karşılaştırması; eski APK geliştirme imzasının yeniden kullanımı veya temiz kurulum öncesi JSON yedek.
4. Bir eski ARTPULSE JSON dosyasını RENIZ'e içe aktar; eski galeri ve ayarlar görünür mü doğrula.
5. App Store/Google Play ve marka tescilinde RENIZ adını ayrıca kontrol et.
6. GitHub repo adını `reniz-generative-art` olarak değerlendir. Kullanıcı kararı ve gerçek yetkilendirme olmadan repo/release yayınlandı deme.
