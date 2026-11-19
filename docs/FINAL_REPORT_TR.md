# ARTPULSE v0.1.0 — sonuç ve teslim raporu

Tarih: 19 Kasım 2026. Durum: çalışan ilk geliştirme sürümü. Sanat motoru, yerel projeler ve dışa aktarma tamamlandı; Android, web ve Linux paketleri üretildi. GitHub'da yeni depo oluşturma/yayınlama adımı oturum açılmasını bekliyor.

## 1. Araştırma ve teknoloji seçimi

Flutter 3.50.0 ve beraberindeki Dart 3.14.0 kullanıldı. Resmî platform tablosu, adaptif arayüz, Canvas/CustomPainter, fragment shader, Impeller/Skia, web kaynakları, dosya seçiciler ve TV araç zincirleri incelendi. Ayrıntılı karşılaştırma ve kaynaklar kaynak paketindeki `docs/RESEARCH.md` dosyasındadır.

Ana çizim yolu Canvas/CustomPainter'dır. Liquid Light için isteğe bağlı bir GLSL ışık alanı ve çalışan Canvas yedeği vardır. Rust/C++ hesaplama modülü, sunucu, hesap, Firebase, reklam veya ücretli servis eklenmedi. Küçük yerel platform kodu yalnızca TV algılama ve masaüstü pencere/tam ekran işlemleri içindir.

Başlıca kaynaklar: [Flutter platformları](https://docs.flutter.dev/reference/supported-platforms), [adaptif tasarım](https://docs.flutter.dev/ui/adaptive-responsive), [shader belgeleri](https://docs.flutter.dev/ui/design/graphics/fragment-shaders), [performans](https://docs.flutter.dev/perf), [Android TV](https://developer.android.com/training/tv/get-started/create), [Flutter-Tizen](https://github.com/flutter-tizen/flutter-tizen), [Flutter-webOS](https://github.com/lg-flutter-webos/flutter-webos), [topluluk tvOS aracı](https://fluttertv.dev/).

ARTPULSE adı küresel olarak benzersiz değildir. Depo için `artpulse-generative-art` adı seçildi; mağaza adı rezervasyonu veya marka tescili yapılmış gibi gösterilmedi.

## 2. Tamamlanan özellikler

| Alan | Çalışan davranış |
| --- | --- |
| Neon Flow | Canlı ışık çizgileri, hareket/basınç etkili kullanıcı izleri |
| Particle Galaxy | Sınırlı parçacık havuzu, çekim, yayılma ve dokunma patlamaları |
| Symmetry Lab | 2/4/6/8/12 yönlü radyal simetri ve döndürme |
| Liquid Light | Etkileşimli renk alanı; GLSL ve düşük maliyetli Canvas yolu |
| Geometry Pulse | Hareketli çokgenler ve etkileşim merkezli geometriler |
| Stüdyo | 10 preset, 6 palet, 4 arka plan, yoğunluk/hız/iz ayarları |
| Kontroller | Dokunma, fare, uygun kalemde basınç; iki parmakla yakınlaştırma, kaydırma ve klavye kısayolları |
| Kayıt | Yerel galeri, sürümlü JSON, gerçek çizgi ve parçacık durumuyla yeniden açma |
| Dışa aktarma | Yalnızca sanat içeren PNG; düzenlenebilir proje JSON'u |
| Arayüz | Telefon, yatay telefon, tablet, masaüstü ve deneysel TV düzenleri |
| Dil / erişim | Türkçe, Azərbaycanca, English; odak kontrolleri, etiketler, hareket azaltma |
| Kalite | Eco/Low/Medium/High/Ultra/Auto; gerçek iş yükü farkları ve kare süresinden uyarlama |

Uygulama reklam/analitik içermez. Android üretim manifestinde internet veya geniş depolama izni yoktur. Web'de çekirdek kaynaklar ve varsayılan yazı tipi yereldir. Projeler kullanıcı istemeden sunucuya gönderilmez.

## 3. Üretilen dosyalar

- `ARTPULSE_v0.1.0_Source.zip`: tam Flutter kaynakları, altı resmî platformun runner dosyaları, testler, dokümantasyon, ekran görüntüleri ve CI tanımları.
- `ARTPULSE_v0.1.0_Android_DevSigned.apk`: gerçekten derlenmiş, geliştirme sertifikasıyla imzalanmış Android APK.
- `ARTPULSE_v0.1.0_Web.zip`: statik web/PWA paketi; HTTP/HTTPS üzerinden sunulmalıdır.
- `ARTPULSE_v0.1.0_Linux_x64.tar.gz`: gerçek Linux x64 release bundle.
- Bu rapor ve SHA256 özet dosyası.

APK minimum Android API 24, hedef/derleme API 36 kullanır. Geliştirme imzası mağaza yayını veya uzun süreli güncelleme anahtarı yerine geçmez. Windows EXE ve iPhone IPA oluşturulmadı; olmayan dosyalar için indirme bağlantısı verilmedi.

## 4. Test sonuçları

**38 Flutter test vakası geçti:** 17 motor/format, 4 kayıt/depolama, 17 widget/çizim vakası. Bunların içinde yedi ekran boyutu/metin ölçeği için golden karşılaştırmaları ve beş motorun gerçek PNG üretimi vardır. Kod analizi temizdir; biçim kontrolü geçmiştir.

**Chrome 158.0.8127.36 üzerinde dokuz gerçek tarayıcı akışı geçti.** Fareyle çizim, palet ve kalıcı IndexedDB kaydı, beş mod, PNG indirme, JSON indirme, sayfa yenileme sonrasında galeriden açma, bozuk dosya hatası ve üç dilin davranışları doğrulandı. 47 kaynak önbelleğe alındıktan sonra tarayıcının interneti kapatıldı: uygulama yeniden açıldı, kayıtlı çalışma ve Azerbaycanca dil tercihi korundu. Test oturumunda dış sunucu isteği ve yakalanmamış sayfa hatası görülmedi.

APK imzası ve ZIP bütünlüğü doğrulandı. Linux bağlantı kontrolünde bu derleme ortamında eksik kütüphane bulunmadı. Gerçek telefon/TV testleri ve Linux pencere etkileşimi bu sonuçlarla karıştırılmadı.

78 kilitli Pub paketi OSV ile sorgulandı; bilinen güvenlik bildirimi eşleşmesi çıkmadı. 86 paket/SDK lisans bildirimi bulundu; eksik lisans bildirimi görülmedi. Bu kontroller kusursuz güvenlik garantisi değildir.

## 5. Platform durumu

| Hedef | Doğrulanan durum |
| --- | --- |
| Android | APK derlendi ve paket/imza doğrulandı; fiziksel cihaz testi yapılmadı |
| Web / PWA | Release derlendi; Chrome'da gerçek kayıt/indirme/çevrimdışı akışlar geçti |
| Linux x64 | Release bundle derlendi; grafik masaüstü oturumu ayrıca doğrulanmalı |
| Windows | Native C++ runner, kaynak ve CI işi hazır; bu Linux ortamında EXE üretilmedi |
| iOS / iPadOS | Ortak Flutter motoru ve Xcode kaynakları hazır; Simulator/IPA derlemesi yapılmadı |
| macOS | Swift runner ve kaynak hazır; macOS/Xcode derlemesi yapılmadı |
| Android TV / Google TV | Leanback manifesti, banner, TV algılama, büyük arayüz ve ambiyans kaynakları var; gerçek kumanda testi yok |
| Fire TV | Android kaynak yolu aday; model bazında test yok |
| Tizen / webOS / tvOS | Resmî/topluluk araç zincirleri araştırıldı; doğrulanmış port veya paket yok |

Safari/Firefox, katlanabilir cihaz menteşeleri, 4K TV, gerçek kalem basıncı, 90/120 Hz ekran ve çoklu monitör testi yapılmış sayılmadı.

## 6. Performans kanıtı

Beş kalite profiliyle AOT CPU simülasyon ölçümü yapıldı: profil başına 1.200 ısınma ve 3.600 ölçülen adım. Ham veriler `docs/evidence/performance.json`, açıklamalar `docs/PERFORMANCE.md` içindedir. Paylaşılan Linux sanal ortamı kullanıldığı için zamanlama sıçramaları raporda korunmuştur.

Bu ölçüm çizim/GPU/pil/ısı testi değildir ve cihaz FPS'sine dönüştürülmedi. Auto kalitesi gerçek kare iş süresini kullanır. Parçacık sayısı, eğri örnekleri, geometri ayrıntısı ve glow/shader kullanımı değişir. Arka planda ve hareket azaltmada animasyon durur. Dinamik raster çözünürlüğü ve termal API entegrasyonu ilk sürümde yoktur.

## 7. Bulunan ve düzeltilen sorunlar

- Yatay telefon üst çubuğu taşması ve küçülen tuval: dar yükseklikte yan gezinme ve erişilebilir kayıt/dosya araçları.
- Döndürme sırasında aktif işaretçi durumu: çizgi korunarak geçici işaretçiler temizlenir.
- Yeni Material yüzey/TV metin ölçeği hataları: uygun Material yüzeyi ve güvenli metin ölçeklemesi.
- Duraklama sonrası zaman damgası başlangıcı: sıfır yerine boş başlangıç durumu kullanılarak ticker devamı düzeltildi.
- Web tamsayı hassasiyeti: noise hash'inde taşınabilir 32-bit çarpma.
- Her animasyon karesinde yeniden kurulan çizim bileşeni: retained painter ve ayrı repaint bildirimi.
- Çevrimdışıyken dış font isteği: yerel web kaynakları, varsayılan Roboto ve aynı kaynak alanındaki fallback yolu.
- Native açılışın açık renk kaynakları: Android ve iOS açılış kaynakları koyu temaya uyarlandı; cihazdaki görsel davranış ayrıca doğrulanmalıdır.

## 8. GitHub ve yayın

Kaynaklar yerel Git deposunda aşamalı commitlerle hazırdır. Analiz/test ve Android/web/Linux/Windows/Apple derlemelerini doğru işletim sistemlerinde çalıştıracak GitHub Actions dosyaları eklendi. Etiketli release yalnızca başarılı build matrisinden sonra mevcut paketleri yayınlayacak şekilde düzenlendi; Pages için ayrı workflow vardır.

**GitHub deposu ve release henüz yayımlanmadı.** Bağlı GitHub aracında yeni depo oluşturma işlemi bulunmuyor; tarayıcıdaki yeni depo sayfası oturum açılmasını istiyor. Bu nedenle gerçek bir depo/release URL'si uydurulmadı. Yayınlama için bu oturumun tamamlanması gerekiyor.

## 9. Kullanım ve sınırlar

Android'de APK kurulabilir. Web ZIP içindeki `web` klasörünü örneğin `python -m http.server 8080 --directory web` ile sunup `http://localhost:8080` aç. PWA için HTTPS veya localhost gerekir; ilk başarılı yükleme/worker kurulumu tamamlanmalıdır. Linux arşivindeki `bundle` klasörünü bütünlüğüyle çıkarıp `./bundle/artpulse` çalıştır. Windows derlemesi için Flutter ve Visual Studio C++ masaüstü iş yükü gereklidir.

Tarayıcı depolaması silinebilir; önemli çalışmalar için JSON yedeği al. Ani uygulama kapanışında son açık kayıttan sonraki kaydedilmemiş hareketler garanti edilmez. Geri al/yinele çizgilere uygulanır; tam katman/zaman çizelgesi geçmişi değildir. Liquid Light fiziksel sıvı çözücüsü değildir.

## 10. Sonraki adımlar

GitHub oturumunu tamamlayıp herkese açık depoyu yayınlamak; uygun Windows/macOS/Xcode runner'larında paketleri üretmek; ardından temsilî Android telefon ve TV Box'ta profil, depolama/paylaşma, kumanda, pil ve uzun oturum testleri. Daha sonra video/GIF, katmanlar ve özel TV portları değerlendirilebilir. Bunlar tamamlanmış özellikler olarak gösterilmedi.
