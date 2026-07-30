import './style.css'
import { GUNLER, AYLAR, toHicri, dayOfYear } from './data/calendar.js'
import { YEMEKLER } from './data/yemekler.js'
import { getTarihte } from './data/tarihte.js'
import { ATASOZLeri, OZLU_SOZLER } from './data/atasozleri.js'
import { BILGILER, ISIM_GUNLERI } from './data/bilgiler.js'

const app = document.querySelector('#app')
const STRIPS = 22

function startOfDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}
function addDays(date, delta) {
  return startOfDay(new Date(date.getFullYear(), date.getMonth(), date.getDate() + delta))
}
function pick(list, index) {
  return list[((index % list.length) + list.length) % list.length]
}

let current = startOfDay(new Date())
let flipping = false
let version = localStorage.getItem('maarif-version') || 'classic'

function buildContent(date) {
  const doy = dayOfYear(date)
  return {
    gunAdi: GUNLER[date.getDay()],
    gun: date.getDate(),
    ay: AYLAR[date.getMonth()],
    yil: date.getFullYear(),
    hicri: toHicri(date),
    isimler: pick(ISIM_GUNLERI, doy + date.getMonth()),
    tarih: getTarihte(date, doy),
    atasozu: pick(ATASOZLeri, doy * 3 + 7),
    ozlu: pick(OZLU_SOZLER, doy * 2 + 3),
    yemek: pick(YEMEKLER, doy + date.getFullYear()),
    bilgi: pick(BILGILER, doy + 11),
  }
}

function classicSheet(c) {
  const tarih = c.tarih.map((t) => `<p class="c-line">• ${t}</p>`).join('')
  return `
    <div class="classic-sheet">
      <div class="classic-brand">SAATLİ MAARİF TAKVİMİ</div>
      <div class="classic-date">
        <div class="classic-left">
          <div class="classic-weekday">${c.gunAdi}</div>
          <div class="classic-day">${c.gun}</div>
          <div class="classic-month">${c.ay} ${c.yil}</div>
        </div>
        <div class="classic-right">
          <div><span>Hicrî</span><strong>${c.hicri.day} ${c.hicri.month} ${c.hicri.year}</strong></div>
          <div><span>İsim günü</span><strong>${c.isimler}</strong></div>
        </div>
      </div>
      <div class="classic-block">
        <h3>Bugün tarihte</h3>
        ${tarih}
      </div>
      <div class="classic-block">
        <h3>Günün sözü</h3>
        <p class="c-quote">« ${c.atasozu} »</p>
      </div>
      <div class="classic-block">
        <h3>Günün yemeği — ${c.yemek.ad}</h3>
        <p><b>Malzemeler:</b> ${c.yemek.malzemeler}</p>
        <p><b>Yapılışı:</b> ${c.yemek.yapilis}</p>
      </div>
      <div class="classic-block">
        <h3>${c.bilgi.baslik}</h3>
        <p>${c.bilgi.metin}</p>
      </div>
      <div class="classic-block">
        <h3>Özlü söz</h3>
        <p class="c-quote">${c.ozlu}</p>
      </div>
      <div class="classic-tear-hint">Yukarı kaydır — yaprağı kopar</div>
    </div>
  `
}

function modernSheet(c) {
  const tarih = c.tarih.map((t) => `<li>${t}</li>`).join('')
  return `
    <div class="page-sheet">
      <header class="page-top">
        <div class="logo"><span class="logo-mark"></span><span class="logo-text">MAARİF</span></div>
        <div class="side side-left">
          <div class="side-icon sun"></div>
          <div class="side-meta"><strong>${c.hicri.day}</strong><span>${c.hicri.month}</span></div>
        </div>
        <div class="date-hero">
          <div class="month">${c.ay.toUpperCase()}</div>
          <div class="day-num">${c.gun}</div>
          <div class="weekday">${c.gunAdi.toUpperCase()}</div>
        </div>
        <div class="side side-right">
          <div class="side-icon moon"></div>
          <div class="side-meta"><strong>${c.yil}</strong><span>${c.isimler.split(',')[0]}</span></div>
        </div>
      </header>
      <div class="page-body">
        <section class="block"><h2>Bugün tarihte</h2><ul>${tarih}</ul></section>
        <section class="block proverb-block"><h2>Günün sözü</h2><p>« ${c.atasozu} »</p></section>
        <section class="block recipe-block"><h2>Günün yemeği</h2><h3>${c.yemek.ad}</h3>
          <p class="label">Malzemeler</p><p>${c.yemek.malzemeler}</p>
          <p class="label">Yapılışı</p><p>${c.yemek.yapilis}</p>
        </section>
        <section class="block"><h2>${c.bilgi.baslik}</h2><p>${c.bilgi.metin}</p></section>
        <section class="block proverb-block"><h2>Özlü söz</h2><p>${c.ozlu}</p></section>
      </div>
      <div class="page-footer"><span>Yukarı kaydır</span><span class="chevron">↑</span></div>
    </div>
  `
}

function stripsHTML(inner) {
  let html = ''
  for (let i = 0; i < STRIPS; i++) {
    html += `<div class="strip" style="--i:${i}; --n:${STRIPS}"><div class="strip-face"><div class="strip-content" style="transform:translateY(calc(-100% * ${i} / ${STRIPS}))">${inner}</div></div></div>`
  }
  return html
}

function setVersion(v) {
  version = v
  localStorage.setItem('maarif-version', v)
  document.body.dataset.version = v
  render()
}

function render() {
  document.body.dataset.version = version
  const c = buildContent(current)
  const next = buildContent(addDays(current, 1))
  const sheet = version === 'classic' ? classicSheet : modernSheet
  const front = sheet(c)
  const back = sheet(next)

  app.innerHTML = `
    <div class="version-bar">
      <button type="button" class="ver-btn ${version === 'classic' ? 'active' : ''}" data-v="classic">V2 · Klasik duvar</button>
      <button type="button" class="ver-btn ${version === 'modern' ? 'active' : ''}" data-v="modern">V1 · Modern</button>
    </div>

    <div class="wall">
      <div class="pad" id="phone">
        <div class="pad-layers" aria-hidden="true"></div>
        <div class="binding" aria-hidden="true">
          <div class="binding-bar"></div>
          ${Array.from({ length: 9 }, () => '<i class="hole"></i>').join('')}
        </div>
        <div class="stage" id="stage">
          <div class="page page-next" id="page-next">${back}</div>
          <div class="page page-front" id="page-front">
            <div class="curl-stack" id="curl-stack">${stripsHTML(front)}</div>
          </div>
        </div>
      </div>
    </div>

    <div class="dock">
      <button type="button" id="btn-prev" class="dock-btn">Önceki</button>
      <button type="button" id="btn-today" class="dock-btn dock-today">BUGÜN</button>
      <button type="button" id="btn-next" class="dock-btn">Sonraki</button>
    </div>
  `

  app.querySelectorAll('.ver-btn').forEach((btn) => {
    btn.addEventListener('click', () => setVersion(btn.dataset.v))
  })
  document.getElementById('btn-prev').onclick = () => jump(-1)
  document.getElementById('btn-today').onclick = () => {
    current = startOfDay(new Date())
    render()
  }
  document.getElementById('btn-next').onclick = () => {
    if (!flipping) animateCurlToEnd()
  }
  bindCurl(document.getElementById('phone'))
}

function easeOutCubic(t) {
  return 1 - (1 - t) ** 3
}

function setCurlProgress(p) {
  const stack = document.getElementById('curl-stack')
  const next = document.getElementById('page-next')
  if (!stack) return
  const progress = Math.max(0, Math.min(1.2, p))
  const curlPos = progress * (STRIPS + 6)
  const curlWidth = 6
  const radius = 34
  stack.querySelectorAll('.strip').forEach((strip, i) => {
    const fromBottom = STRIPS - 1 - i
    const dist = curlPos - fromBottom
    let angle = 0
    let z = 0
    let y = 0
    let brightness = 1
    let opacity = 1
    let shade = 0
    if (dist >= curlWidth) {
      angle = -178
      opacity = 0
      z = radius * 0.2
    } else if (dist > 0) {
      const t = dist / curlWidth
      const theta = t * Math.PI
      angle = -(theta * 180) / Math.PI
      z = Math.sin(theta) * radius
      y = -(1 - Math.cos(theta)) * (radius * 0.15)
      brightness = 1 - Math.sin(theta) * 0.28
      shade = Math.sin(theta) * 0.55
      opacity = t > 0.9 ? 1 - (t - 0.9) / 0.1 : 1
    }
    const face = strip.querySelector('.strip-face')
    face.style.transform = `translateY(${y}px) rotateX(${angle}deg) translateZ(${z}px)`
    face.style.filter = `brightness(${brightness})`
    face.style.opacity = String(Math.max(0, opacity))
    face.style.setProperty('--curl-shade', String(shade))
  })
  if (next) {
    const reveal = Math.min(1, progress * 1.2)
    next.style.transform = `scale(${0.985 + reveal * 0.015})`
    next.style.filter = `brightness(${0.92 + reveal * 0.08})`
  }
}

function resetCurl() {
  setCurlProgress(0)
}

function animateCurlToEnd(from = 0) {
  if (flipping) return
  flipping = true
  const start = from
  const t0 = performance.now()
  const dur = 600
  const tick = (now) => {
    const t = Math.min(1, (now - t0) / dur)
    setCurlProgress(start + (1.12 - start) * easeOutCubic(t))
    if (t < 1) {
      requestAnimationFrame(tick)
      return
    }
    current = addDays(current, 1)
    flipping = false
    render()
  }
  requestAnimationFrame(tick)
}

function animateCurlBack(from) {
  const start = from
  const t0 = performance.now()
  const dur = 340
  const tick = (now) => {
    const t = Math.min(1, (now - t0) / dur)
    setCurlProgress(start * (1 - easeOutCubic(t)))
    if (t < 1) requestAnimationFrame(tick)
    else resetCurl()
  }
  requestAnimationFrame(tick)
}

function jump(delta) {
  if (flipping) return
  if (delta > 0) {
    animateCurlToEnd(0)
    return
  }
  current = addDays(current, delta)
  render()
}

function bindCurl(root) {
  const stage = document.getElementById('stage')
  if (!stage) return
  let active = false
  let dragging = false
  let startY = 0
  let startX = 0
  let lastY = 0
  let lastT = 0
  let velocity = 0
  let progress = 0
  let pid = null
  const height = () => Math.max(stage.clientHeight, 420)

  stage.addEventListener('pointerdown', (e) => {
    if (flipping || e.button === 2) return
    active = true
    dragging = false
    pid = e.pointerId
    startY = e.clientY
    startX = e.clientX
    lastY = e.clientY
    lastT = performance.now()
    velocity = 0
    progress = 0
    stage.setPointerCapture?.(e.pointerId)
  })

  stage.addEventListener(
    'pointermove',
    (e) => {
      if (!active || flipping) return
      if (pid !== null && e.pointerId !== pid) return
      const dy = startY - e.clientY
      const dx = Math.abs(e.clientX - startX)
      const now = performance.now()
      velocity = (lastY - e.clientY) / Math.max(1, now - lastT)
      lastY = e.clientY
      lastT = now
      if (!dragging) {
        if (dy > 10 && dy > dx * 1.05) {
          dragging = true
          root.classList.add('is-curling')
        } else return
      }
      e.preventDefault()
      progress = Math.min(1.05, Math.max(0, dy / (height() * 0.78)))
      setCurlProgress(progress)
    },
    { passive: false },
  )

  const end = (e) => {
    if (!active) return
    if (pid !== null && e.pointerId !== pid) return
    active = false
    root.classList.remove('is-curling')
    if (!dragging) {
      pid = null
      return
    }
    dragging = false
    pid = null
    if (progress > 0.2 || velocity > 0.4) animateCurlToEnd(progress)
    else animateCurlBack(progress)
  }
  stage.addEventListener('pointerup', end)
  stage.addEventListener('pointercancel', end)
  resetCurl()
}

render()
