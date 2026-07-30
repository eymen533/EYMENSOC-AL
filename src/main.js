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

function addDays(date, delta) {
  return startOfDay(new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta))
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

      <div class="swipe-hint" aria-hidden="true">
        <span class="swipe-arrow">↑</span>
        Yukarı kaydır — sonraki yaprak
      </div>
    </div>
  `
}

function render(options = {}) {
  const { animateEnter = false } = options
  const c = buildContent(current)
  const next = buildContent(addDays(current, 1))

  app.innerHTML = `
    <div class="brand-bar">
      <h1>Saatli Maarif Takvimi</h1>
      <p>Her güne bir yaprak</p>
    </div>

    <div class="calendar-stage" id="stage">
      <div class="pad-back" aria-hidden="true"></div>
      <div class="binding" aria-hidden="true">
        <div class="binding-bar"></div>
        ${Array.from({ length: 8 }, () => '<div class="hole"></div>').join('')}
      </div>
      <article class="leaf leaf-under" id="leaf-under" aria-hidden="true">
        ${leafHTML(next)}
      </article>
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

    <p class="footer-note">Yaprak üzerinde yukarı kaydırarak çevirin</p>
  `

  document.getElementById('btn-prev').addEventListener('click', () => shiftDay(-1, false))
  document.getElementById('btn-today').addEventListener('click', goToday)
  document.getElementById('btn-next').addEventListener('click', () => shiftDay(1, true))
  bindFlipGesture(document.getElementById('leaf'))
}

function setButtonsDisabled(disabled) {
  ;['btn-prev', 'btn-today', 'btn-next'].forEach((id) => {
    const el = document.getElementById(id)
    if (el) el.disabled = disabled
  })
}

function applyFlipTransform(leaf, progress) {
  const p = Math.max(0, Math.min(1, progress))
  const angle = -p * 118
  const lift = p * 36
  const shade = 1 - p * 0.22
  const opacity = 1 - Math.max(0, p - 0.72) / 0.28
  leaf.style.transform = `rotateX(${angle}deg) translateY(${lift}px) scale(${1 - p * 0.04})`
  leaf.style.filter = `brightness(${shade})`
  leaf.style.opacity = String(opacity)
}

function clearFlipStyles(leaf) {
  leaf.style.transform = ''
  leaf.style.filter = ''
  leaf.style.opacity = ''
}

function completeTear(leaf) {
  flipping = true
  setButtonsDisabled(true)
  leaf.classList.remove('dragging', 'entering', 'snap-back')
  leaf.classList.add('flipping')
  clearFlipStyles(leaf)

  window.setTimeout(() => {
    current = addDays(current, 1)
    flipping = false
    render({ animateEnter: true })
  }, 680)
}

function bindFlipGesture(leaf) {
  if (!leaf) return

  const THRESHOLD = 0.32
  const VELOCITY = 0.55
  const COMMIT_PX = 18

  let active = false
  let dragging = false
  let startY = 0
  let startX = 0
  let lastY = 0
  let lastT = 0
  let velocity = 0
  let pointerId = null

  const onDown = (e) => {
    if (flipping || e.button === 2) return
    active = true
    dragging = false
    pointerId = e.pointerId
    startY = e.clientY
    startX = e.clientX
    lastY = e.clientY
    lastT = performance.now()
    velocity = 0
    leaf.setPointerCapture?.(e.pointerId)
  }

  const onMove = (e) => {
    if (!active || flipping) return
    if (pointerId !== null && e.pointerId !== pointerId) return

    const dy = startY - e.clientY
    const dx = Math.abs(e.clientX - startX)
    const now = performance.now()
    const dt = Math.max(1, now - lastT)
    velocity = (lastY - e.clientY) / dt
    lastY = e.clientY
    lastT = now

    if (!dragging) {
      if (dy > COMMIT_PX && dy > dx * 1.15) {
        dragging = true
        leaf.classList.remove('entering', 'snap-back')
        leaf.classList.add('dragging')
        document.body.classList.add('is-flipping')
      } else {
        return
      }
    }

    e.preventDefault()
    const height = Math.max(leaf.offsetHeight, 280)
    const progress = Math.min(1, Math.max(0, dy / (height * 0.72)))
    applyFlipTransform(leaf, progress)
  }

  const finish = (e) => {
    if (!active) return
    if (pointerId !== null && e.pointerId !== pointerId) return
    active = false
    document.body.classList.remove('is-flipping')

    if (!dragging) {
      pointerId = null
      return
    }

    const dy = startY - e.clientY
    const height = Math.max(leaf.offsetHeight, 280)
    const progress = Math.min(1, Math.max(0, dy / (height * 0.72)))
    dragging = false
    pointerId = null

    if (progress >= THRESHOLD || velocity >= VELOCITY) {
      completeTear(leaf)
      return
    }

    leaf.classList.remove('dragging')
    leaf.classList.add('snap-back')
    clearFlipStyles(leaf)
    window.setTimeout(() => leaf.classList.remove('snap-back'), 320)
  }

  leaf.addEventListener('pointerdown', onDown)
  leaf.addEventListener('pointermove', onMove, { passive: false })
  leaf.addEventListener('pointerup', finish)
  leaf.addEventListener('pointercancel', finish)
}

function shiftDay(delta, tear) {
  if (flipping) return

  if (tear && delta > 0) {
    const leaf = document.getElementById('leaf')
    if (leaf) completeTear(leaf)
    return
  }

  current = addDays(current, delta)
  render({ animateEnter: true })
}

function goToday() {
  if (flipping) return
  current = startOfDay(new Date())
  render({ animateEnter: true })
}

render()
