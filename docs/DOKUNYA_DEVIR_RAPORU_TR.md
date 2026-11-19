# DOKUNYA — kaynak güncellemesi ve devir raporu

**Tarih:** 19 Kasım 2026  
**Kaynak sürümü:** v0.1.2+3 (Flutter/Dart; derlenmiş release değil)

## Ne değişti?

- Kullanıcının onayladığı yeni ad **DOKUNYA** uygulamanın görünür markası olarak seçildi. Ad, **dokun + dünya** fikrini taşır.
- Mevcut ARTPULSE v0.1.0 → RENIZ v0.1.1 kaynak kodu korundu; sıfırdan proje oluşturulmadı.
- Flutter paketi `dokunya`, giriş/widget sınıfı `DokunyaApp`, Android/iOS/macOS/Windows/Linux/web görünür başlıkları `DOKUNYA` oldu. TV banner'ı yeni başlıkla oluşturuldu.
- Yeni export isimleri `DOKUNYA_<seed>.png` ve `DOKUNYA_<seed>.dokunya.json`.
- Eski `.artpulse.json` ve `.reniz.json` dosyalarını okuyabilen şema ve dosya seçimi korundu. ARTPULSE örnek projesini kullanan geriye dönük uyumluluk testlerine RENIZ proje testi eklendi.
- Kullanıcı veri sürekliliği için **Android applicationId `dev.artpulse.artpulse`, Apple bundle ID, `artpulse_projects` yerel klasörü, `artpulse-studio` web IndexedDB ve mevcut platform kanalları** değiştirilmedi.
- `DOKUNYA_TV` seçeneği eklendi; eski `RENIZ_TV` ve `ARTPULSE_TV` de çalışmaya devam edecek şekilde bırakıldı.
- Test ve eski sürüm kanıtları tarihsel belge olarak korundu; eski APK ve web paketleri yeniden adlandırılarak yeni sürüm sayılmadı.

## Doğrulama

- Python betiğiyle **30/30 statik kaynak tutarlılığı kontrolü geçti**. Sonuçlar `docs/DOKUNYA_STATIC_QA.json` içinde.
- XML manifest, iOS plist ve web manifest JSON parse kontrolleri geçti.
- `git diff --check` geçti.
- **Flutter/Dart SDK bu ortamda kurulu değildi. `flutter analyze`, `flutter test`, `flutter build` çalıştırılmadı.** Eklenen Dart regresyon testi henüz çalıştırılmadı.
- Gerçek Android/iPhone/Windows/macOS/TV üzerinde DOKUNYA uygulama testi yapılmadı.
- **DOKUNYA için yeni APK/IPA/EXE/web release üretilmedi ve GitHub'a push yapılmadı.**

## Önerilen devam sırası

1. Flutter 3.50.0, Dart 3.14.0 ile `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` çalıştır. Hata varsa düzelt.
2. Android ve web paketlerini gerçek build ile üret; APK imzasını eski uygulamanın imzasıyla karşılaştır. Var olan kullanıcı verisini kaybettirme. Bir önceki sürümden yükseltme riski varsa JSON yedeği yolunu açıkla.
3. Uygun platformlarda Windows/Linux/macOS/iOS derlemelerini ve cihaz testlerini ayrı doğrula.
4. En az bir eski ARTPULSE ve bir RENIZ proje JSON'unu yeni DOKUNYA sürümünde içe aktarma ve galeri açma akışını test et.
5. GitHub deposunu kullanıcı hesabında kontrol et, marka adı ve olası tescil çakışmalarını ayrıca değerlendir. Yalnızca doğrulanmış paketleri yayınla.

**Kaynak deposu için önerilen isim:** `dokunya-generative-art`. Bu isim şu an ayrılmış veya yayınlanmış olduğu anlamına gelmez.
