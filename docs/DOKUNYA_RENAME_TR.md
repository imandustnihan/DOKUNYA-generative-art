# DOKUNYA — ad değişikliği ve uyumluluk (19 Kasım 2026)

Kullanıcı onayıyla mevcut proje **DOKUNYA** oldu (dokun + dünya). İlk geliştirme adı **ARTPULSE** idi; güncel görünür marka **DOKUNYA**'dır. Proje sıfırdan yeniden oluşturulmadı; Flutter sanat motoru ve beş mod korundu.

## Görünür ve teknik değişiklikler

- Flutter/Dart paket adı `dokunya`, Dart importları `package:dokunya/...`, uygulama sınıfı `DokunyaApp`.
- Android, iOS, macOS, Windows, Linux ve web'de görünür ad `DOKUNYA`.
- Yeni PNG dışa aktarma `DOKUNYA_*`; düzenlenebilir dosyalar `.dokunya.json`.
- **Önceki sürümlerin `.json` projeleri okunabilmeye devam eder.** `schemaVersion` ve `ProjectCodec` değiştirilmedi.
- Android applicationId / Kotlin paketi `dev.artpulse.artpulse`, iOS/macOS bundle ID `dev.artpulse.artpulse` ve Linux application ID aynı kaldı. Bunlar uygulama güncellemesi sırasında kimlik ve mevcut verilere erişimi korumak için önemlidir.
- Yerel `artpulse_projects` kayıt dizini, tarayıcı `artpulse-studio` IndexedDB adı, mevcut web PWA `id` / `scope` ve platform kanalları değiştirilmedi.
- `DOKUNYA_TV` güncel TV derleme seçeneğidir. `ARTPULSE_TV` eski betikler için desteklenmeye devam eder.
- Önceki ARTPULSE v0.1.0 test kanıtları yeniden çalıştırılmış DOKUNYA testleri olarak sunulmaz.

## Paket ve doğrulama

Bu çalışma ortamında Flutter/Dart SDK mevcut olmadığından `flutter analyze`, `flutter test` ve yeni platform derlemeleri çalıştırılamadı. Önceki Android APK, web/PWA ve Linux paketi **ARTPULSE v0.1.0** markasını taşır; DOKUNYA paketleri değildir. Yeni APK ile yerinde yükseltme için önceki kurulumun imza anahtarıyla aynı anahtar gerekir. İmza değişiyorsa JSON yedeği alınmalı, veri kaybı riski açıklanmalıdır.

## Kontrol komutları

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --release
flutter build web --release --no-web-resources-cdn
```

İmzalama ve platform kuralları ayrıca doğrulanmalıdır. Marka/tescil uygunluğu yayın öncesinde incelenmelidir.
