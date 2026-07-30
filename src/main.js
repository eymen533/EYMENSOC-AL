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
}

let tickTimer = null

function parseTimeToday(hhmm, base = state.now) {
  const [h, m] = hhmm.split(':').map(Number)
  const d = new Date(base)
  d.setHours(h, m, 0, 0)
  return d
}

function formatHMS(ms) {
  const total = Math.max(0, Math.floor(ms / 1000))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  return {
    h: String(h).padStart(2, '0'),
    m: String(m).padStart(2, '0'),
    s: String(s).padStart(2, '0'),
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
  // Yatsı geçtiyse yarın imsak
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
  const map = {
    Fajr: 'dawn',
    Dhuhr: 'noon',
    Asr: 'afternoon',
    Maghrib: 'dusk',
    Isha: 'night',
  }
  return map[nextKey] || 'night'
}

async function fetchTimings(city) {
  const url = `https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(city)}&country=Turkey&method=13&school=1`
  const res = await fetch(url)
  if (!res.ok) throw new Error('Vakitler alınamadı')
  const json = await res.json()
  const data = json.data
  return {
    timings: data.timings,
    dateLabel: `${data.date.gregorian.day} ${data.date.gregorian.month.en} ${data.date.gregorian.year}`,
    hijri: `${data.date.hijri.day} ${data.date.hijri.month.en} ${data.date.hijri.year}`,
  }
}

async function load() {
  state.loading = true
  state.error = ''
  render()
  try {
    const data = await fetchTimings(state.city)
    state.timings = data.timings
    state.dateLabel = data.dateLabel
    state.hijri = data.hijri
    state.loading = false
  } catch (e) {
    state.loading = false
    state.error = 'Vakitler yüklenemedi. Bağlantını kontrol et.'
  }
  render()
}

function setCity(city, label) {
  state.city = city
  state.label = label
  localStorage.setItem('vakit-city', city)
  localStorage.setItem('vakit-label', label)
  load()
}

function render() {
  const schedule = getSchedule()
  const next = getNextPrayer(schedule)
  const current = getCurrentPeriod(schedule)
  const theme = skyTheme(next?.key || current?.key)
  const remain = next ? formatHMS(next.date.getTime() - state.now.getTime()) : null

  document.body.dataset.sky = theme

  app.innerHTML = `
    <div class="sky" aria-hidden="true">
      <div class="sky-wash"></div>
      <div class="sky-orb"></div>
      <div class="sky-haze"></div>
      <div class="sky-grain"></div>
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

      ${
        state.loading
          ? `<div class="status">Vakitler hazırlanıyor…</div>`
          : state.error
            ? `<div class="status error">${state.error}<button type="button" id="retry">Tekrar dene</button></div>`
            : `
        <section class="hero">
          <p class="hero-kicker">${next?.tomorrow ? 'Yarın' : 'Sıradaki'} · ${next?.name || '—'}</p>
          <h2 class="hero-name">${next?.name || '—'}</h2>
          <div class="countdown" aria-live="polite">
            <div class="unit"><span>${remain?.h || '00'}</span><small>saat</small></div>
            <div class="sep">:</div>
            <div class="unit"><span>${remain?.m || '00'}</span><small>dk</small></div>
            <div class="sep">:</div>
            <div class="unit"><span>${remain?.s || '00'}</span><small>sn</small></div>
          </div>
          <p class="hero-sub">${state.label} · ${next?.time || ''}</p>
        </section>

        <section class="times" aria-label="Günün namaz vakitleri">
          <div class="times-head">
            <h3>Bugün</h3>
            <p>${state.dateLabel}</p>
          </div>
          <ul class="time-list">
            ${schedule
              .map((p) => {
                const isNext = next && p.key === next.key && !next.tomorrow
                const isNow = current && p.key === current.key && !p.meta
                const passed = p.date.getTime() <= state.now.getTime() && !isNext
                return `
                  <li class="time-row ${p.meta ? 'is-meta' : ''} ${isNext ? 'is-next' : ''} ${isNow ? 'is-now' : ''} ${passed ? 'is-passed' : ''}">
                    <span class="time-name">${p.name}</span>
                    <span class="time-clock">${p.time}</span>
                  </li>`
              })
              .join('')}
          </ul>
        </section>
        `
      }
    </main>
  `

  const select = document.getElementById('city-select')
  if (select) {
    select.addEventListener('change', () => {
      const opt = select.selectedOptions[0]
      setCity(opt.value, opt.textContent)
    })
  }
  const retry = document.getElementById('retry')
  if (retry) retry.addEventListener('click', load)
}

function startClock() {
  if (tickTimer) clearInterval(tickTimer)
  tickTimer = setInterval(() => {
    state.now = new Date()
    if (!state.loading && !state.error && state.timings) render()
  }, 1000)
}

load()
startClock()
