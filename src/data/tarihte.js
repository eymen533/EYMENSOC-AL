/** Belirli tarihlerde yaşanan olaylar (MM-DD) */
export const TARIHTE = {
  '01-01': [
    'Miladi takvimin ilk günü. Yeni yılın başlangıcı kabul edilir.',
    '1926 — Türkiye’de uluslararası takvim ve saat sistemi yürürlüğe girdi.',
  ],
  '01-05': ['1920 — İstanbul, İtilaf Devletleri tarafından resmen işgal edildi.'],
  '01-27': ['1919 — Paris Barış Konferansı başladı.'],
  '02-19': ['1878 — Ahmed Vefik Paşa’nın tiyatro çevirileri Osmanlı kültüründe iz bıraktı.'],
  '02-28': ['1920 — Misak-ı Milli, son Osmanlı Mebusan Meclisi’nde kabul edildi.'],
  '03-12': ['1921 — İstiklal Marşı, TBMM’de millî marş olarak kabul edildi.'],
  '03-18': [
    '1915 — Çanakkale Deniz Zaferi. İtilaf donanması boğazı geçemedi.',
    'Çanakkale Şehitleri Anma Günü.',
  ],
  '03-21': ['Nevruz — baharın ve yenilenmenin geleneksel bayramı.'],
  '04-23': [
    '1920 — Türkiye Büyük Millet Meclisi Ankara’da açıldı.',
    'Ulusal Egemenlik ve Çocuk Bayramı.',
  ],
  '05-01': ['Emek ve Dayanışma Günü.'],
  '05-19': [
    '1919 — Mustafa Kemal Atatürk Samsun’a çıktı; Millî Mücadele’nin fiilî başlangıcı.',
    'Atatürk’ü Anma, Gençlik ve Spor Bayramı.',
  ],
  '05-29': ['1453 — Fatih Sultan Mehmet, İstanbul’u fethetti.'],
  '06-01': ['Yaz aylarının başlangıcı; tarımda sulama ve hasat hazırlıkları artar.'],
  '06-04': ['1878 — Kıbrıs’ın idaresi geçici olarak İngiltere’ye bırakıldı (Berlin süreci).'],
  '07-01': ['Kabotaj Bayramı — Türk karasularında denizcilik haklarının anıldığı gün.'],
  '07-15': ['2016 — 15 Temmuz Demokrasi ve Millî Birlik Günü.'],
  '08-26': ['1071 — Malazgirt Zaferi. Anadolu’nun Türkleşmesinde dönüm noktası.'],
  '08-30': [
    '1922 — Büyük Taarruz’un zaferle sonuçlandığı gün: Başkomutanlık Meydan Muharebesi.',
    'Zafer Bayramı.',
  ],
  '09-01': ['1923 — Atatürk, “Egemenlik kayıtsız şartsız milletindir” ilkesini sıkça vurguladı.'],
  '09-09': ['1922 — İzmir’in düşman işgalinden kurtuluşu.'],
  '09-30': ['Sonbahar takvimine geçiş; tarlada ürün kaldırma yoğunlaşır.'],
  '10-06': ['1923 — İstanbul’un düşman işgalinden kurtuluşu.'],
  '10-29': [
    '1923 — Türkiye Cumhuriyeti ilan edildi. Gazi Mustafa Kemal Atatürk ilk Cumhurbaşkanı seçildi.',
    'Cumhuriyet Bayramı.',
  ],
  '11-10': [
    '1938 — Mustafa Kemal Atatürk, İstanbul Dolmabahçe Sarayı’nda hayata gözlerini yumdu.',
    'Atatürk’ü Anma Günü — saat 09.05’te saygı duruşu.',
  ],
  '11-24': ['1934 — Mustafa Kemal’e “Atatürk” soyadı verildi. Öğretmenler Günü.'],
  '12-01': ['Kış mevsiminin başlangıcı; soba ve yakacak hazırlıkları hatırlanırdı.'],
  '12-21': ['Yılın en kısa günü — kış gündönümü.'],
  '12-31': ['Yılın son günü. Saatli Maarif Takvimi’nin son yaprağı.'],
}

/** Genel tarih bilgileri — gün indeksine göre döner */
export const GENEL_TARIH = [
  'Osmanlı’da günlük hayat, ezan saatlerine ve namaz vakitlerine göre düzenlenirdi.',
  'Tanzimat döneminde gazeteler, halkı bilgilendirmenin başlıca aracı oldu.',
  'Anadolu’da kervansaraylar, ticaret yollarının güvenli duraklarıydı.',
  'İpek Yolu üzerinden Anadolu’ya baharat, kumaş ve bilgi taşınırdı.',
  'Matbaanın Osmanlı’ya gelişi, kitap ve takvim kültürünü yaygınlaştırdı.',
  'Medreselerde astronomi ve takvim hesabı önemli bir ilimdi.',
  'Köy odalarında akşamları hikâye ve destan anlatılırdı.',
  'Hamam kültürü, temizlik kadar sosyal buluşmanın da mekânıydı.',
  'Çarşı-pazar düzeni, esnaf loncalarıyla yüzyıllarca ayakta kaldı.',
  'Türk kahvesi, UNESCO somut olmayan kültürel miras listesindedir.',
  'Ebru sanatı, suyun yüzünde renklerle yazı ve desen oluşturur.',
  'Hat sanatı, yazıyı bir güzel sanat dalına dönüştürmüştür.',
  'Minyatür, el yazması kitapları süsleyen ince işçilikli resimdir.',
  'Karagöz-Hacivat, gölge oyunu geleneğimizin simgesidir.',
  'Ortaoyunu, açık alanda oynanan geleneksel tiyatrodur.',
  'Ahilik teşkilatı, esnafta dürüstlük ve dayanışmayı öğretirdi.',
  'Selçuklu kervansarayları, yolcuya üç gün ücretsiz konaklama sağlardı.',
  'Kapadokya’da yeraltı şehirleri, tarih boyunca sığınak olmuştur.',
  'Safranbolu evleri, Osmanlı sivil mimarisinin canlı örneğidir.',
  'Çini sanatı, İznik ve Kütahya’da zirveye ulaşmıştır.',
]

export function getTarihte(date, doy) {
  const key = `${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
  if (TARIHTE[key]) return TARIHTE[key]
  return [GENEL_TARIH[doy % GENEL_TARIH.length]]
}
