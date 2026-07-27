# KÖKLER

**KÖKLER**, Godot 4 ile geliştirilen erken aşama bir 2.5D dungeon / roguelike prototipidir.

Oyun şu an final bir ürün değil.  
Ama artık sadece “boş sahnede karakter gezdirme” aşamasını geçti. Temel oynanış iskeleti oluşmaya başladı:

```text
Keşfet → savaş → loot topla → silah değiştir → anahtarı bul → çıkışa ulaş
```

Bu repo şu an küçük bir ekip prototipi olarak ilerliyor. Öncelik, fikrin oynanabilir olup olmadığını görmek ve sistemleri yavaş yavaş birbirine bağlamak.

---

## Oyun ne anlatıyor?

Oyuncu, kayıp bir haritacının kızı olan **Asha**’yı kontrol eder.

Asha’nın babası, dağların altında gömülü olduğu söylenen kadim şehir **Kökaltı**’nı ararken kaybolmuştur. Geriye sadece yarım kalmış bir harita ve kısa bir not kalır:

> Kökaltı gerçek. İnme. Geri dön.

Asha yine de iner.

Kökaltı klasik bir zindan gibi yalnızca öldürmeye çalışan bir yer değil.  
Burası yönünü bozan, odalarını değiştiren, bazı yolları unutturan ve her koşuda oyuncuyu biraz daha tanıyan bir labirent gibi tasarlanıyor.

Ana his şu:

> Burada sadece oda temizlemiyoruz. Bizi hatırlayan bir yere iniyoruz.

---

## Şu anki durum

Bu depo, **Godot 4.6 üzerinde çalışan güncel geliştirme build’idir**. Ayrı bir semantik oyun sürümü ilan etmez.

Mevcut oynanış omurgası:

- 2.5D ana menü ve koşu akışı
- hareket, dash, combo ve charged attack
- en fazla iki aktif silah slotu; yakın ve menzilli saldırılar
- prosedürel odalar, değişken koridorlar ve oda-temizleme ödülleri
- dört ana katman, mikro katlar, anahtar/çıkış ilerlemesi ve boss karşılaşmaları
- düşman can barları, loot ve Kök Parçaları
- Kök Sunakları ve koşu içi harcama seçenekleri
- keşif/shift durumlarını gösteren minimap
- upgrade kartları, envanter, pause ve ölüm özeti

Görsel taraf hâlâ erken aşamada. Modeller ve çevre çoğunlukla primitive meshlerden oluşuyor. Ama hedef, assetsiz bile oyunun atmosferini ve sistemlerini anlaşılır hale getirmek.

---

## Teknik bilgi

Proje:

```text
Godot 4.6
GDScript
2.5D / 3D sahne
CanvasLayer / Control UI
```

Mevcut teknik yön:

- Player ve düşmanlar: `CharacterBody3D`
- Hitbox, pickup, trigger sistemleri: `Area3D`
- UI: `CanvasLayer / Control`
- Görseller: primitive mesh + basit materyaller
- Ana akış: `res://scenes/main_menu.tscn` → `res://scenes/main_2_5d.tscn`

Eski 2D prototip artık aktif değildir.

---

## Görsel temel

Ortam dili artık küçük bir paylaşımlı temel üzerinden ilerlemelidir:

- Paylaşımlı materyaller: `res://environment/materials/`
- Oda görsel profilleri: `res://data/room_visual_profiles/`
- Prop kategori notları: `res://environment/PROP_CATEGORIES.md`

Bu katman sadece görsel sunumu yönlendirir. Oda grafiği, düşmanlar, anahtar, çıkış ve softlock güvenliği hâlâ mevcut 2.5D oyun sistemlerinde kalır.

Katman duvarları için `res://textures/wall_layer1.png` ile `wall_layer4.png` arasında dört isteğe bağlı texture hook’u vardır. Bu dosyalar şu anda depoda bulunmaz; oyun güvenli biçimde düz-renk materyallere düşer. Dokulu duvarların şu anda görünür olduğu varsayılmamalıdır.

---

## Ana sahne akışı

Play / F5 şu menü sahnesini çalıştırmalıdır:

```text
res://scenes/main_menu.tscn
```

Menüdeki `Yeni Koşu` butonu aktif oyun sahnesini açar:

```text
res://scenes/main_2_5d.tscn
```

Godot içinde kontrol etmek için:

```text
Project → Project Settings → Application → Run → Main Scene
```

Burada ana sahne şu olmalı:

```text
res://scenes/main_menu.tscn
```

Eğer eski `main.tscn` açılmaya çalışırsa bu yanlıştır. Eski 2D dosyalar artık aktif oyun hattının parçası değil.

---

## Nasıl çalıştırılır?

1. Godot 4’ü aç.
2. Bu projeyi import et.
3. Ana sahnenin `main_menu.tscn` olduğundan emin ol.
4. Play / F5’e bas.
5. Menüden `Yeni Koşu` seç.

Yerel proje yolu örnek:

```text
C:/Users/Berat Sağır/Documents/Projects/kokler_godot
```

---

## Kontroller

| Eylem | Tuş |
|---|---|
| Hareket | W / A / S / D |
| Dash | Space |
| Slot 1 saldırı | J veya sol mouse |
| Slot 2 saldırı | K veya sağ mouse |
| Silah slotu seçme | 1 - 2 |
| Envanter | I |
| Kök Sunağı / etkileşim | E |
| Sahneyi çalıştırma | F5 |
| Açık sahneyi test etme | F6 |

---

## Mevcut sistemler

### Oyuncu

- Asha hareket eder.
- Dash atabilir.
- Silah kullanabilir.
- Farklı silahlar farklı hasar / menzil / hız hissi verir.
- Can sistemi vardır.
- Ölünce sahne yeniden başlatılır.

### Silahlar

Şu anki yapı en fazla iki aktif silah slotuna dayanıyor. Slotlar `1` ve `2` ile seçilir; sol/J ve sağ/K saldırıları ilgili slotu kullanır.

Mevcut / hedeflenen silah tipleri:

- Haritacı Bıçağı
- Taş Tokmak
- Kemik Mızrak
- Kor Çubuğu
- Mantar Sapanı

Silahlar loot olarak düşebilir veya sahnede pickup olarak bulunabilir.

### Düşmanlar

Şu an kullanılan düşman tipleri:

- Kör Sıçan
- Mantar Adam
- Taş Bekçi

Her düşmanda temel can sistemi ve can barı bulunur. Davranışlar hâlâ erken prototip seviyesinde.

### Loot

Düşmanlardan veya odalardan loot alınabilir.

Mevcut loot yapısı:

- Kök Parçası
- Silah pickup’ları

Kök Parçaları şu an koşu içi değer olarak kullanılıyor. Kalıcı meta-progression sistemi henüz tam eklenmedi.

### Dungeon / Oda Sistemi

Koşu dört ana katman ve her katmandaki prosedürel mikro katlar üzerinden ilerler. Oda grafiği start, key ve exit erişilebilirliğini korur; savaş odaları temizlenince hedef, minimap durumu ve tek seferlik ödül akışı güncellenir. Katman geçişleri ayrı zemin/duvar renkleri, köşe dekorları ve boss karşılaşmalarıyla ayrılır.

İlk katmanın görsel kimliği hâlâ `KAT I — Kök Tüneli` etrafındadır: toprak, kökler, eski insan izleri ve okunabilir fakat baskılı yeraltı mekanları.

---

## Kökaltı’nın mevcut yönü

Kökaltı’nın şu anki prototip hedefleri:

- Her koşuda farklı his veren oda yapısı
- Oyuncuyu boğmayan ama yön hissi veren labirent
- Keşfedildikçe açılan minimap
- Bazı yolların değişmesi
- Değişen alanların minimap’te tekrar belirsizleşmesi
- Hikâyenin sadece README’de değil, oyunun içinde de verilmesi

Bu sistemler henüz tamamlanmış değil. Ama projenin ana yönü bu.

---

## Hikâye entegrasyonu

Hikâye şimdilik kısa mesajlar ve oda içi işaretlerle verilecek.

Kullanılan / kullanılabilecek örnek cümleler:

```text
KAT I — Kök Tüneli
```

```text
Toprak nefes almıyor. Dinliyor.
```

```text
Kökaltı gerçek. İnme. Geri dön.
```

```text
Duvarlar yerini hatırlamıyor.
```

```text
Kökaltı yer değiştirdi.
```

```text
Bazı kapılar açılmaz. Seni bekler.
```

```text
Şimdilik kaçtın. Ama Kökler seni hatırlıyor.
```

Amaç uzun diyalog yazmak değil.  
Kısa, atmosferik, oyun akışını bölmeyen parçalarla hikâyeyi oyuncunun önüne çıkarmak.

---

## Klasör yapısı

Yaklaşık yapı:

```text
kokler_godot/
├─ project.godot
├─ README.md
├─ CODEX_TASK.md
├─ scenes/
│  ├─ main_2_5d.tscn
│  ├─ blind_rat_2_5d.tscn
│  ├─ mushroom_man_2_5d.tscn
│  ├─ stone_guard_2_5d.tscn
│  ├─ root_fragment_pickup_2_5d.tscn
│  ├─ weapon_pickup_2_5d.tscn
│  ├─ spore_projectile_2_5d.tscn
│  └─ pause_menu.tscn
├─ scripts/
│  ├─ player_2_5d.gd
│  ├─ blind_rat_2_5d.gd
│  ├─ mushroom_man_2_5d.gd
│  ├─ stone_guard_2_5d.gd
│  ├─ mini_story_map_2_5d.gd
│  ├─ camera_follow_2_5d.gd
│  ├─ weapon_data.gd
│  ├─ weapon_manager_2_5d.gd
│  ├─ inventory_2_5d.gd
│  ├─ health_bar_3d.gd
│  ├─ minimap_2_5d.gd
│  ├─ root_fragment_pickup_2_5d.gd
│  ├─ weapon_pickup_2_5d.gd
│  ├─ spore_projectile_2_5d.gd
│  └─ ui.gd
└─ icon.svg
```

Dosya isimleri geliştirme sırasında değişebilir. Önemli olan F5 akışının `main_menu.tscn`, aktif oyun sahnesinin ise `main_2_5d.tscn` olmasıdır.

---

## Git çalışma düzeni

Küçük ekip olduğu için şimdilik basit ilerliyoruz.

Başlamadan önce:

```powershell
git status
git pull origin main
```

Değişiklik yaptıktan sonra:

```powershell
git add .
git commit -m "Kısa ve net commit mesajı"
git push origin main
```

Daha büyük ve riskli işler için branch açmak daha sağlıklı:

```powershell
git checkout -b feature/ozellik-adi
```

Ama küçük hızlı prototip değişikliklerinde direkt `main` ile ilerlenebilir. Yine de aynı dosyaya iki kişinin aynı anda girmemesi gerekiyor.

---

## Dikkat edilmesi gereken dosyalar

Bu dosyalar projenin ana damarlarıdır:

```text
project.godot
scenes/main_2_5d.tscn
scripts/player_2_5d.gd
scripts/mini_story_map_2_5d.gd
scripts/ui.gd
scripts/weapon_manager_2_5d.gd
scripts/inventory_2_5d.gd
```

Buralarda değişiklik yaparken dikkatli olunmalı.  
Özellikle `main_2_5d.tscn` ve `mini_story_map_2_5d.gd` kolayca sahne kırabilir.

---

## Codex / Claude Code kullanımı

Projede AI araçları yardımcı olarak kullanılıyor.

Kural basit:

```text
AI bütün projeyi kafasına göre yeniden yazmamalı.
AI küçük ve net görevlerle kullanılmalı.
```

İyi görev örneği:

```text
Loot pickup sistemini mevcut 2.5D yapıya entegre et.
Sadece gerekli dosyalara dokun.
F5 akışını main_menu.tscn → main_2_5d.tscn olarak koru.
```

Kötü görev örneği:

```text
Oyunu geliştir.
```

Bu tarz geniş komutlar bazen çalışan sistemleri bozabilir.

---

## Şu an eklenmemesi gerekenler

Bunlar daha sonra:

- tam save sistemi
- meta-progression kampı
- shop
- gelişmiş animasyon sistemi
- dış asset paketi
- Steam/export işleri

Önce oynanabilir çekirdek sağlamlaşmalı.

---

## Yakın hedefler

Sıradaki işler mevcut sistemlerin stabilitesi, deterministik regresyon testleri, katman/oda okunabilirliği ve kontrollü denge doğrulamasıdır.

---

## Bilinen eksikler

- Görsel kalite hâlâ placeholder seviyesinde.
- Oda üretimi ve koridor ritmi geliştirilmeli.
- Minimap sistemi daha okunur hale getirilmeli.
- Düşman AI basit.
- Animasyonlar erken prototip.
- Silah dengesi oturmuş değil.
- Loot oranları test edilmeli.
- Hikâye entegrasyonu hâlâ yüzeysel.
- Katman ve mikro-kat dengesi daha fazla koşu testi gerektiriyor.

---

## Projenin hedef hissi

KÖKLER’in iyi çalışması için oyuncunun şunu hissetmesi gerekiyor:

> “Bu sadece bir dungeon değil. Burası beni hatırlayan bir yer.”

O yüzden en önemli şey sadece daha fazla sistem eklemek değil.  
Odaların, kapıların, loot’un, minimap’in ve hikâye parçalarının aynı fikre hizmet etmesi gerekiyor:

```text
Kökaltı canlı değil.
Ama sanki canlıymış gibi davranıyor.
```
