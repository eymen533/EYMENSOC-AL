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

function easeOutCubic(t) {
  return 1 - (1 - t) ** 3
}

function applySlideTransform(leaf, under, progress) {
  const p = Math.max(0, Math.min(1.15, progress))
  const h = Math.max(leaf.offsetHeight, 280)
  // Yukarı kayma + hafif 3D flip (üstten menteşeli takvim yaprağı)
  const slide = -p * h * 0.92
  const tilt = -p * 42
  const depth = p * 28
  const shade = 1 - Math.min(p, 1) * 0.12
  const opacity = p > 0.85 ? 1 - (p - 0.85) / 0.3 : 1

  leaf.style.transform = `translate3d(0, ${slide}px, ${depth}px) rotateX(${tilt}deg)`
  leaf.style.filter = `brightness(${shade})`
  leaf.style.opacity = String(Math.max(0, opacity))
  leaf.style.boxShadow = `0 ${8 + p * 24}px ${24 + p * 30}px rgba(40, 24, 12, ${0.25 + p * 0.2})`

  if (under) {
    const u = easeOutCubic(Math.min(1, p))
    under.style.transform = `scale(${0.97 + u * 0.03}) translateY(${(1 - u) * 10}px)`
    under.style.filter = `brightness(${0.9 + u * 0.1})`
    under.style.opacity = String(0.85 + u * 0.15)
  }
}

function clearSlideStyles(leaf, under) {
  ;[leaf, under].forEach((el) => {
    if (!el) return
    el.style.transform = ''
    el.style.filter = ''
    el.style.opacity = ''
    el.style.boxShadow = ''
    el.style.transition = ''
  })
}

function completeSlide(leaf, fromProgress = 0) {
  const under = document.getElementById('leaf-under')
  flipping = true
  setButtonsDisabled(true)
  leaf.classList.remove('dragging', 'entering', 'snap-back')
  leaf.classList.add('sliding-out')
  under?.classList.add('revealing')
  document.body.classList.add('is-flipping')

  const start = Math.max(0, fromProgress)
  const duration = 520
  const t0 = performance.now()
  let done = false

  const finishNav = () => {
    if (done) return
    done = true
    current = addDays(current, 1)
    flipping = false
    document.body.classList.remove('is-flipping')
    render({ animateEnter: true })
  }

  const tick = (now) => {
    if (done) return
    const t = Math.min(1, (now - t0) / duration)
    const p = start + (1.25 - start) * easeOutCubic(t)
    applySlideTransform(leaf, under, p)
    if (t < 1) {
      requestAnimationFrame(tick)
      return
    }
    finishNav()
  }

  leaf.style.transition = 'none'
  applySlideTransform(leaf, under, start)
  requestAnimationFrame(() => requestAnimationFrame(tick))
}

function bindFlipGesture(leaf) {
  if (!leaf) return
  const under = document.getElementById('leaf-under')

  const THRESHOLD = 0.22
  const VELOCITY = 0.45
  const COMMIT_PX = 12

  let active = false
  let dragging = false
  let startY = 0
  let startX = 0
  let lastY = 0
  let lastT = 0
  let velocity = 0
  let progress = 0
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
    progress = 0
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
      if (dy > COMMIT_PX && dy > dx * 1.1) {
        dragging = true
        leaf.classList.remove('entering', 'snap-back')
        leaf.classList.add('dragging')
        under?.classList.add('revealing')
        document.body.classList.add('is-flipping')
      } else {
        return
      }
    }

    e.preventDefault()
    const height = Math.max(leaf.offsetHeight, 280)
    // Parmakla 1:1 kayma hissi, hafif direnç
    const raw = dy / (height * 0.85)
    progress = Math.min(1.05, Math.max(0, raw))
    applySlideTransform(leaf, under, progress)
  }

  const finish = (e) => {
    if (!active) return
    if (pointerId !== null && e.pointerId !== pointerId) return
    active = false

    if (!dragging) {
      pointerId = null
      return
    }

    dragging = false
    pointerId = null
    leaf.classList.remove('dragging')

    if (progress >= THRESHOLD || velocity >= VELOCITY) {
      completeSlide(leaf, progress)
      return
    }

    // Geri yaylan
    document.body.classList.remove('is-flipping')
    leaf.classList.add('snap-back')
    under?.classList.add('snap-back')
    clearSlideStyles(leaf, under)
    under?.classList.remove('revealing')
    window.setTimeout(() => {
      leaf.classList.remove('snap-back')
      under?.classList.remove('snap-back')
    }, 380)
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
    if (leaf) completeSlide(leaf, 0)
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
