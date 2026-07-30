import './style.css'

const PRAYERS = [
  { key: 'Fajr', name: 'İmsak', short: 'Sabah' },
  { key: 'Sunrise', name: 'Güneş', short: 'Doğuş', meta: true },
  { key: 'Dhuhr', name: 'Öğle', short: 'Öğle' },
  { key: 'Asr', name: 'İkindi', short: 'İkindi' },
  { key: 'Maghrib', name: 'Akşam', short: 'Akşam' },
  { key: 'Isha', name: 'Yatsı', short: 'Yatsı' },
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

const app = document.querySelector('#app')

let state = {
  city: localStorage.getItem('vakit-city') || 'Istanbul',
  label: localStorage.getItem('vakit-label') || 'İstanbul',
  timings: null,
  dateLabel: '',
  hijri: '',
  loading: true,
  error: '',
  now: new Date(),
  theme: 'night',
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

function skyTheme(nextKey) {
  return (
    {
      Fajr: 'dawn',
      Dhuhr: 'noon',
      Asr: 'afternoon',
      Maghrib: 'dusk',
      Isha: 'night',
    }[nextKey] || 'night'
  )
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
  const monthIdx = Number(g.month.number) - 1
  return {
    timings: data.timings,
    dateLabel: `${Number(g.day)} ${monthsTr[monthIdx]} ${g.year}`,
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

function renderShell() {
  const schedule = getSchedule()
  const next = getNextPrayer(schedule)
  const current = getCurrentPeriod(schedule)
  state.theme = skyTheme(next?.key || current?.key)
  state.nextKey = next?.key || ''
  document.body.dataset.sky = state.theme

  if (state.loading || state.error) {
    mounted = false
    app.innerHTML = `
      <div class="sky" aria-hidden="true">
        <div class="sky-glow"></div>
        <div class="sky-arch"></div>
        <div class="sky-veil"></div>
      </div>
      <main class="shell">
        <header class="top">
          <div class="brand"><span class="crescent" aria-hidden="true"></span><h1>VAKİT</h1></div>
        </header>
        <div class="status ${state.error ? 'error' : ''}">
          <p>${state.error || 'Vakitler hazırlanıyor…'}</p>
          ${state.error ? '<button type="button" id="retry">Tekrar dene</button>' : ''}
        </div>
      </main>`
    document.getElementById('retry')?.addEventListener('click', load)
    return
  }

  const remain = next ? formatHMS(next.date.getTime() - state.now.getTime()) : { h: '00', m: '00', s: '00' }

  app.innerHTML = `
    <div class="sky" aria-hidden="true">
      <div class="sky-glow"></div>
      <div class="sky-arch"></div>
      <div class="sky-veil"></div>
    </div>

    <main class="shell">
      <header class="top">
        <div class="brand">
          <span class="crescent" aria-hidden="true"></span>
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

      <section class="hero">
        <p class="hero-kicker" id="hero-kicker">${next?.tomorrow ? 'Yarın' : 'Sıradaki vakit'}</p>
        <h2 class="hero-name" id="hero-name">${next?.name || '—'}</h2>
        <div class="countdown" aria-live="polite">
          <div class="unit"><span id="cd-h">${remain.h}</span><small>saat</small></div>
          <span class="sep" aria-hidden="true">:</span>
          <div class="unit"><span id="cd-m">${remain.m}</span><small>dk</small></div>
          <span class="sep" aria-hidden="true">:</span>
          <div class="unit"><span id="cd-s">${remain.s}</span><small>sn</small></div>
        </div>
        <p class="hero-sub" id="hero-sub">${state.label} · ${next?.time || ''}</p>
      </section>

      <section class="times" aria-label="Günün namaz vakitleri">
        <div class="times-head">
          <div>
            <h3>Bugünün vakitleri</h3>
            <p id="date-line">${state.dateLabel}</p>
          </div>
          <p class="hijri" id="hijri-line">${state.hijri}</p>
        </div>
        <ul class="time-list" id="time-list">
          ${schedule
            .map((p) => {
              const isNext = next && p.key === next.key && !next.tomorrow
              const isNow = current && p.key === current.key && !p.meta
              const passed = p.date.getTime() <= state.now.getTime() && !isNext
              return `
                <li class="time-row ${p.meta ? 'is-meta' : ''} ${isNext ? 'is-next' : ''} ${isNow ? 'is-now' : ''} ${passed ? 'is-passed' : ''}" data-key="${p.key}">
                  <span class="time-name">${p.name}</span>
                  <span class="time-clock">${p.time}</span>
                </li>`
            })
            .join('')}
        </ul>
      </section>
    </main>
  `

  document.getElementById('city-select')?.addEventListener('change', (e) => {
    const opt = e.target.selectedOptions[0]
    setCity(opt.value, opt.textContent)
  })

  mounted = true
}

/** Sadece sayaç ve satır durumunu güncelle — tam DOM yenileme yok (flicker önler) */
function tickUpdate() {
  state.now = new Date()
  if (!mounted || state.loading || state.error || !state.timings) return

  const schedule = getSchedule()
  const next = getNextPrayer(schedule)
  const current = getCurrentPeriod(schedule)
  const theme = skyTheme(next?.key || current?.key)

  // Namaz değiştiyse bir kez yeniden çiz
  if ((next?.key || '') !== state.nextKey || theme !== state.theme) {
    state.theme = theme
    state.nextKey = next?.key || ''
    renderShell()
    return
  }

  const remain = next ? formatHMS(next.date.getTime() - state.now.getTime()) : null
  const h = document.getElementById('cd-h')
  const m = document.getElementById('cd-m')
  const s = document.getElementById('cd-s')
  if (h && remain) {
    h.textContent = remain.h
    m.textContent = remain.m
    s.textContent = remain.s
  }

  const kicker = document.getElementById('hero-kicker')
  const name = document.getElementById('hero-name')
  const sub = document.getElementById('hero-sub')
  if (kicker) kicker.textContent = next?.tomorrow ? 'Yarın' : 'Sıradaki vakit'
  if (name) name.textContent = next?.name || '—'
  if (sub) sub.textContent = `${state.label} · ${next?.time || ''}`

  document.querySelectorAll('.time-row').forEach((row) => {
    const key = row.dataset.key
    const p = schedule.find((x) => x.key === key)
    if (!p) return
    const isNext = next && p.key === next.key && !next.tomorrow
    const isNow = current && p.key === current.key && !p.meta
    const passed = p.date.getTime() <= state.now.getTime() && !isNext
    row.classList.toggle('is-next', !!isNext)
    row.classList.toggle('is-now', !!isNow)
    row.classList.toggle('is-passed', !!passed)
  })
}

function startClock() {
  if (tickTimer) clearInterval(tickTimer)
  tickTimer = setInterval(tickUpdate, 1000)
}

load()
startClock()
