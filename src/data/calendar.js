/** Gün isimleri ve ay isimleri */
export const GUNLER = [
  'Pazar',
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
]

export const AYLAR = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
]

export const HICRI_AYLAR = [
  'Muharrem',
  'Safer',
  'Rebiülevvel',
  'Rebiülahir',
  'Cemaziyelevvel',
  'Cemaziyelahir',
  'Recep',
  'Şaban',
  'Ramazan',
  'Şevval',
  'Zilkade',
  'Zilhicce',
]

/** Basit Hicri tarih dönüşümü (yaklaşık) */
export function toHicri(date) {
  const jd =
    Math.floor((1461 * (date.getFullYear() + 4800 + Math.floor((date.getMonth() + 1 - 14) / 12))) / 4) +
    Math.floor((367 * (date.getMonth() + 1 - 2 - 12 * Math.floor((date.getMonth() + 1 - 14) / 12))) / 12) -
    Math.floor((3 * Math.floor((date.getFullYear() + 4900 + Math.floor((date.getMonth() + 1 - 14) / 12)) / 100)) / 4) +
    date.getDate() -
    32075

  const l = jd - 1948440 + 10632
  const n = Math.floor((l - 1) / 10631)
  const l2 = l - 10631 * n + 354
  const j =
    Math.floor((10985 - l2) / 5316) * Math.floor((50 * l2) / 17719) +
    Math.floor(l2 / 5670) * Math.floor((43 * l2) / 15238)
  const l3 =
    l2 -
    Math.floor((30 - j) / 15) * Math.floor((17719 * j) / 50) -
    Math.floor(j / 16) * Math.floor((15238 * j) / 43) +
    29
  const m = Math.floor((24 * l3) / 709)
  const d = l3 - Math.floor((709 * m) / 24)
  const y = 30 * n + j - 30

  return {
    day: d,
    month: HICRI_AYLAR[m - 1] || HICRI_AYLAR[0],
    year: y,
  }
}

export function dayOfYear(date) {
  const start = new Date(date.getFullYear(), 0, 0)
  const diff = date - start
  return Math.floor(diff / (1000 * 60 * 60 * 24))
}

export function formatKey(date) {
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${m}-${d}`
}
