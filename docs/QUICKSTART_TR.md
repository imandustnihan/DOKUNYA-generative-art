# RENIZ — hızlı kullanım

**Android:** Daha önce üretilmiş APK, **ARTPULSE v0.1.0** adını taşır. RENIZ 0.1.1 için henüz yeni APK derlenmedi. Önce RENIZ kaynaklarından doğrulanmış paket üret. Bu ilk geliştirme paketi geliştirme anahtarıyla imzalanır. Fiziksel telefon testi yapılmadan bütün cihazlarla uyumlu olduğu söylenemez.

**Web:** Web ZIP dosyasını aç. İçindeki `web` klasörünü bir statik sunucuyla çalıştır; `index.html` dosyasına çift tıklamak yeterli değildir. Örnek: `python -m http.server 8080 --directory web`, ardından tarayıcıda `http://localhost:8080` açılır. İlk başarılı yüklemeden ve önbellek tamamlandıktan sonra çevrimdışı kullanım mümkündür.

**Linux:** Arşivdeki `bundle` klasörünü bütünlüğünü koruyarak çıkarıp `./bundle/reniz` çalıştır (yeni sürüm derlendiğinde); eski ARTPULSE v0.1.0 paketi için `./bundle/artpulse` kullan. GTK 3 ve uygun masaüstü grafik sürücüsü gerekir. Yeni sürüm için `chmod +x bundle/reniz`, eski paket için `chmod +x bundle/artpulse` kullan.

**Windows kaynakları:** Flutter 3.50.0 ve Visual Studio'nun C++ masaüstü geliştirme bileşenleri kurulu bir Windows bilgisayarda proje klasöründe `flutter pub get`, `flutter analyze` ve `flutter build windows --release` çalıştır. Oluşan `build/windows/x64/runner/Release` klasöründeki EXE, DLL ve `data` klasörü birlikte tutulmalıdır. Çalıştırmak için yönetici hakları gerekmez. Taşınabilir sürümü kaldırmak için uygulamayı kapatıp bu klasörü sil; kullanıcı projelerini silmek ayrı bir işlemdir.

Stüdyoda sanat modunu seç, tuvale çiz, renkleri ve parametreleri değiştir. İki parmakla yakınlaştır; masaüstünde fare tekerleğiyle kaydır, Ctrl + tekerlekle yakınlaştır. `0` görünümü sıfırlar. Kaydet düğmesi düzenlenebilir projeyi koleksiyona ekler. PNG dışa aktar yalnızca sanat eserini verir; proje dosyası dışa aktar ise çizgileri ve simülasyon durumunu korur.

Ayarlar ekranından Türkçe veya Azərbaycanca seçilebilir. Hareketi azalt seçeneği otomatik animasyonu durdurur. Eko kalitesi 30 kare hedefler; bu bir donanım performansı garantisi değildir. TV arayüzü ve ambiyans modu deneyseldir.
