import './style.css'

const PRAYERS = [
  { key: 'Fajr', name: 'İmsak' },
  { key: 'Sunrise', name: 'Güneş', meta: true },
  { key: 'Dhuhr', name: 'Öğle' },
  { key: 'Asr', name: 'İkindi' },
  { key: 'Maghrib', name: 'Akşam' },
  { key: 'Isha', name: 'Yatsı' },
]

const CITIES = [
  { city: 'Istanbul', label: 'İstanbul' },
  { city: 'Ankara', label: 'Ankara' },
  { city: 'Izmir', label: 'İzmir' },
  { city: 'Bursa', label: 'Bursa' },
  { city: 'Antalya', label: 'Antalya' },
  { city: 'Konya', label: 'Konya' },
  { city: 'Gaziantep', label: 'Gaziantep' },
  { city: 'Adana', label: 'Adana' },
  { city: 'Trabzon', label: 'Trabzon' },
  { city: 'Erzurum', label: 'Erzurum' },
]

const THEMES = [
  { id: 'sari-siyah', label: 'Sarı · Siyah', swatch: ['#0a0a0a', '#f5c518'] },
  { id: 'yesil', label: 'Yeşil tonlar', swatch: ['#0d1f14', '#3d8b5f'] },
  { id: 'beyaz-yesil', label: 'Beyaz · Yeşil', swatch: ['#f4f7f2', '#1f7a4c'] },
  { id: 'lacivert', label: 'Beyaz · Lacivert', swatch: ['#f2f5fb', '#1a2a6c'] },
  { id: 'gece-mavi', label: 'Gece · Mavi', swatch: ['#071018', '#4db0ff'] },
  { id: 'zeytin', label: 'Zeytin · Altın', swatch: ['#1a1c12', '#c6a84b'] },
]

const app = document.querySelector('#app')

let state = {
  city: localStorage.getItem('vakit-city') || 'Istanbul',
  label: localStorage.getItem('vakit-label') || 'İstanbul',
  theme: localStorage.getItem('vakit-theme') || 'sari-siyah',
  timings: null,
  dateLabel: '',
  hijri: '',
  loading: true,
  error: '',
  now: new Date(),
  nextKey: '',
}

let tickTimer = null
let mounted = false

function parseTimeToday(hhmm, base = state.now) {
  const [h, m] = hhmm.split(':').map(Number)
  const d = new Date(base)
  d.setHours(h, m, 0, 0)
  return d
}

function formatHMS(ms) {
  const total = Math.max(0, Math.floor(ms / 1000))
  return {
    h: String(Math.floor(total / 3600)).padStart(2, '0'),
    m: String(Math.floor((total % 3600) / 60)).padStart(2, '0'),
    s: String(total % 60).padStart(2, '0'),
  }
}

function formatClock(date) {
  return date.toLocaleTimeString('tr-TR', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  })
}

function getSchedule() {
  if (!state.timings) return []
  return PRAYERS.map((p) => ({
    ...p,
    time: state.timings[p.key],
    date: parseTimeToday(state.timings[p.key]),
  }))
}

function getNextPrayer(schedule) {
  const now = state.now.getTime()
  const upcoming = schedule.filter((p) => !p.meta && p.date.getTime() > now)
  if (upcoming.length) return upcoming[0]
  const fajr = schedule.find((p) => p.key === 'Fajr')
  if (!fajr) return null
  const tomorrow = new Date(fajr.date)
  tomorrow.setDate(tomorrow.getDate() + 1)
  return { ...fajr, date: tomorrow, tomorrow: true }
}

function getCurrentPeriod(schedule) {
  const now = state.now.getTime()
  const prayers = schedule.filter((p) => !p.meta)
  let current = prayers[prayers.length - 1]
  for (let i = 0; i < prayers.length; i++) {
    if (prayers[i].date.getTime() <= now) current = prayers[i]
  }
  return current
}

function applyTheme(id) {
  state.theme = id
  localStorage.setItem('vakit-theme', id)
  document.body.dataset.theme = id
}

async function fetchTimings(city) {
  const url = `https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(city)}&country=Turkey&method=13&school=1`
  const res = await fetch(url)
  if (!res.ok) throw new Error('Vakitler alınamadı')
  const json = await res.json()
  const data = json.data
  const monthsTr = [
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
  const g = data.date.gregorian
  return {
    timings: data.timings,
    dateLabel: `${Number(g.day)} ${monthsTr[Number(g.month.number) - 1]} ${g.year}`,
    hijri: `${data.date.hijri.day} ${data.date.hijri.month.en} ${data.date.hijri.year}`,
  }
}

async function load() {
  state.loading = true
  state.error = ''
  mounted = false
  renderShell()
  try {
    const data = await fetchTimings(state.city)
    state.timings = data.timings
    state.dateLabel = data.dateLabel
    state.hijri = data.hijri
    state.loading = false
  } catch {
    state.loading = false
    state.error = 'Vakitler yüklenemedi. Bağlantını kontrol et.'
  }
  renderShell()
}

function setCity(city, label) {
  state.city = city
  state.label = label
  localStorage.setItem('vakit-city', city)
  localStorage.setItem('vakit-label', label)
  load()
}

function themePickerHTML() {
  return `
    <div class="themes" role="listbox" aria-label="Renk teması">
      ${THEMES.map(
        (t) => `
        <button type="button" class="theme-chip ${state.theme === t.id ? 'active' : ''}" data-theme="${t.id}" title="${t.label}" aria-label="${t.label}">
          <span class="swatch" style="--a:${t.swatch[0]};--b:${t.swatch[1]}"></span>
          <span class="theme-name">${t.label}</span>
        </button>`,
      ).join('')}
    </div>
  `
}

function renderShell() {
  applyTheme(state.theme)
  const schedule = getSchedule()
  const next = getNextPrayer(schedule)
  const current = getCurrentPeriod(schedule)
  state.nextKey = next?.key || ''

  if (state.loading || state.error) {
    mounted = false
    app.innerHTML = `
      <div class="bg" aria-hidden="true"><div class="bg-orb"></div><div class="bg-grid"></div></div>
      <main class="shell">
        <header class="top">
          <div class="brand"><h1>VAKİT</h1></div>
        </header>
        ${themePickerHTML()}
        <div class="status ${state.error ? 'error' : ''}">
          <p>${state.error || 'Vakitler hazırlanıyor…'}</p>
          ${state.error ? '<button type="button" id="retry">Tekrar dene</button>' : ''}
        </div>
      </main>`
    bindChrome()
    return
  }

  const remain = next ? formatHMS(next.date.getTime() - state.now.getTime()) : { h: '00', m: '00', s: '00' }

  app.innerHTML = `
    <div class="bg" aria-hidden="true">
      <div class="bg-orb"></div>
      <div class="bg-grid"></div>
      <div class="bg-noise"></div>
    </div>

    <main class="shell">
      <header class="top">
        <div class="brand">
          <span class="brand-mark" aria-hidden="true"></span>
          <h1>VAKİT</h1>
        </div>
        <label class="city">
          <span class="sr">Şehir</span>
          <select id="city-select" aria-label="Şehir seç">
            ${CITIES.map(
              (c) =>
                `<option value="${c.city}" ${c.city === state.city ? 'selected' : ''}>${c.label}</option>`,
            ).join('')}
          </select>
        </label>
      </header>

      ${themePickerHTML()}

      <section class="hero" aria-live="polite">
        <div class="hero-now">
          <p class="eyebrow">Şu an</p>
          <p class="clock" id="clock-now">${formatClock(state.now)}</p>
        </div>

        <div class="hero-next">
          <p class="eyebrow" id="next-kicker">${next?.tomorrow ? 'Yarın' : 'Sıradaki'} · <span id="next-name">${next?.name || '—'}</span></p>
          <div class="countdown">
            <div class="cd"><span id="cd-h">${remain.h}</span><small>SAAT</small></div>
            <span class="colon">:</span>
            <div class="cd"><span id="cd-m">${remain.m}</span><small>DAKİKA</small></div>
            <span class="colon">:</span>
            <div class="cd"><span id="cd-s">${remain.s}</span><small>SANİYE</small></div>
          </div>
          <p class="hero-meta" id="hero-meta">${state.label.toUpperCase()} · ${next?.time || ''} · ${state.dateLabel.toUpperCase()}</p>
        </div>
      </section>

      <section class="times">
        <div class="times-head">
          <h2>Günün vakitleri</h2>
          <p id="hijri-line">${state.hijri}</p>
        </div>
        <ul class="time-list" id="time-list">
          ${schedule
            .map((p) => {
              const isNext = next && p.key === next.key && !next.tomorrow
              const isNow = current && p.key === current.key && !p.meta
              const passed = p.date.getTime() <= state.now.getTime() && !isNext
              return `
                <li class="time-row ${p.meta ? 'is-meta' : ''} ${isNext ? 'is-next' : ''} ${isNow ? 'is-now' : ''} ${passed ? 'is-passed' : ''}" data-key="${p.key}">
                  <span class="time-name">${p.name.toUpperCase()}</span>
                  <span class="time-clock">${p.time}</span>
                </li>`
            })
            .join('')}
        </ul>
      </section>
    </main>
  `

  bindChrome()
  mounted = true
}

function bindChrome() {
  document.getElementById('city-select')?.addEventListener('change', (e) => {
    const opt = e.target.selectedOptions[0]
    setCity(opt.value, opt.textContent)
  })
  document.getElementById('retry')?.addEventListener('click', load)
  document.querySelectorAll('.theme-chip').forEach((btn) => {
    btn.addEventListener('click', () => {
      applyTheme(btn.dataset.theme)
      document.querySelectorAll('.theme-chip').forEach((b) => b.classList.toggle('active', b === btn))
    })
  })
}

function tickUpdate() {
  state.now = new Date()
  if (!mounted || state.loading || state.error || !state.timings) {
    const clock = document.getElementById('clock-now')
    if (clock) clock.textContent = formatClock(state.now)
    return
  }

  const schedule = getSchedule()
  const next = getNextPrayer(schedule)
  const current = getCurrentPeriod(schedule)

  if ((next?.key || '') !== state.nextKey) {
    renderShell()
    return
  }

  const remain = next ? formatHMS(next.date.getTime() - state.now.getTime()) : null
  const clock = document.getElementById('clock-now')
  if (clock) clock.textContent = formatClock(state.now)
  if (remain) {
    document.getElementById('cd-h').textContent = remain.h
    document.getElementById('cd-m').textContent = remain.m
    document.getElementById('cd-s').textContent = remain.s
  }

  document.querySelectorAll('.time-row').forEach((row) => {
    const p = schedule.find((x) => x.key === row.dataset.key)
    if (!p) return
    const isNext = next && p.key === next.key && !next.tomorrow
    const isNow = current && p.key === current.key && !p.meta
    const passed = p.date.getTime() <= state.now.getTime() && !isNext
    row.classList.toggle('is-next', !!isNext)
    row.classList.toggle('is-now', !!isNow)
    row.classList.toggle('is-passed', !!passed)
  })
}

applyTheme(state.theme)
load()
tickTimer = setInterval(tickUpdate, 1000)
