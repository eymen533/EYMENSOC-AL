import './style.css'
import { GUNLER, AYLAR, toHicri, dayOfYear, formatKey } from './data/calendar.js'
import { YEMEKLER } from './data/yemekler.js'
import { getTarihte } from './data/tarihte.js'
import { ATASOZLeri, OZLU_SOZLER } from './data/atasozleri.js'
import { BILGILER, ISIM_GUNLERI } from './data/bilgiler.js'

const app = document.querySelector('#app')

function startOfDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}

let current = startOfDay(new Date())
let flipping = false

function pick(list, index) {
  return list[((index % list.length) + list.length) % list.length]
}

function buildContent(date) {
  const doy = dayOfYear(date)
  const hicri = toHicri(date)
  const yemek = pick(YEMEKLER, doy + date.getFullYear())
  const tarih = getTarihte(date, doy)
  const atasozu = pick(ATASOZLeri, doy * 3 + 7)
  const ozlu = pick(OZLU_SOZLER, doy * 2 + 3)
  const bilgi = pick(BILGILER, doy + 11)
  const isimler = pick(ISIM_GUNLERI, doy + date.getMonth())

  return {
    gunAdi: GUNLER[date.getDay()],
    gun: date.getDate(),
    ay: AYLAR[date.getMonth()],
    yil: date.getFullYear(),
    hicri,
    isimler,
    tarih,
    atasozu,
    ozlu,
    yemek,
    bilgi,
    key: formatKey(date),
  }
}

function leafHTML(c) {
  const tarihItems = c.tarih.map((t) => `<li>${t}</li>`).join('')

  return `
    <div class="leaf-inner">
      <header class="leaf-header">
        <div class="series">Günün Yaprakları</div>
        <div class="title-tr">SAATLİ MAARİF TAKVİMİ</div>
      </header>

      <div class="date-block">
        <div class="date-main">
          <div class="day-name">${c.gunAdi}</div>
          <div class="day-number">${c.gun}</div>
          <div class="month-year">${c.ay} ${c.yil}</div>
        </div>
        <div class="date-side">
          <div>
            <span class="label">Hicrî</span>
            <strong>${c.hicri.day} ${c.hicri.month} ${c.hicri.year}</strong>
          </div>
          <div>
            <span class="label">İsim günü</span>
            <strong>${c.isimler}</strong>
          </div>
        </div>
      </div>

      <section class="section">
        <h2 class="section-title">Bugün tarihte</h2>
        <ul>${tarihItems}</ul>
      </section>

      <section class="section">
        <h2 class="section-title">Günün sözü</h2>
        <p class="proverb">« ${c.atasozu} »</p>
      </section>

      <section class="section">
        <h2 class="section-title">Günün yemeği</h2>
        <div class="recipe-name">${c.yemek.ad}</div>
        <div class="recipe-meta">
          <span>Malzemeler</span>
          <p>${c.yemek.malzemeler}</p>
        </div>
        <div class="recipe-meta">
          <span>Yapılışı</span>
          <p>${c.yemek.yapilis}</p>
        </div>
      </section>

      <section class="section">
        <h2 class="section-title">${c.bilgi.baslik}</h2>
        <p>${c.bilgi.metin}</p>
      </section>

      <section class="section">
        <h2 class="section-title">Özlü söz</h2>
        <p class="proverb">${c.ozlu}</p>
      </section>
    </div>
  `
}

function render(options = {}) {
  const { animateEnter = false } = options
  const c = buildContent(current)

  app.innerHTML = `
    <div class="brand-bar">
      <h1>Saatli Maarif Takvimi</h1>
      <p>Her güne bir yaprak</p>
    </div>

    <div class="calendar-stage">
      <div class="pad-back" aria-hidden="true"></div>
      <div class="binding" aria-hidden="true">
        <div class="binding-bar"></div>
        ${Array.from({ length: 8 }, () => '<div class="hole"></div>').join('')}
      </div>
      <article class="leaf${animateEnter ? ' entering' : ''}" id="leaf" aria-live="polite">
        ${leafHTML(c)}
      </article>
    </div>

    <div class="controls">
      <button type="button" class="btn-prev" id="btn-prev" ${flipping ? 'disabled' : ''}>
        ← Önceki gün
      </button>
      <button type="button" class="btn-today" id="btn-today" ${flipping ? 'disabled' : ''}>
        Bugün
      </button>
      <button type="button" class="btn-next" id="btn-next" ${flipping ? 'disabled' : ''}>
        Sonraki yaprak →
      </button>
    </div>

    <p class="footer-note">Yaprak çevirerek günleri gezinin</p>
  `

  document.getElementById('btn-prev').addEventListener('click', () => shiftDay(-1, false))
  document.getElementById('btn-today').addEventListener('click', goToday)
  document.getElementById('btn-next').addEventListener('click', () => shiftDay(1, true))
}

function setButtonsDisabled(disabled) {
  ;['btn-prev', 'btn-today', 'btn-next'].forEach((id) => {
    const el = document.getElementById(id)
    if (el) el.disabled = disabled
  })
}

function shiftDay(delta, tear) {
  if (flipping) return

  if (tear && delta > 0) {
    flipping = true
    setButtonsDisabled(true)
    const leaf = document.getElementById('leaf')
    leaf.classList.remove('entering')
    leaf.classList.add('flipping')

    window.setTimeout(() => {
      current = startOfDay(new Date(current.getFullYear(), current.getMonth(), current.getDate() + delta))
      flipping = false
      render({ animateEnter: true })
    }, 680)
    return
  }

  current = startOfDay(new Date(current.getFullYear(), current.getMonth(), current.getDate() + delta))
  render({ animateEnter: true })
}

function goToday() {
  if (flipping) return
  current = startOfDay(new Date())
  render({ animateEnter: true })
}

render()
