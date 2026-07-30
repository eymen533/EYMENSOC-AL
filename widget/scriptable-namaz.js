// Namaz Vakitleri — Scriptable Widget
// Kurulum:
// 1) App Store'dan "Scriptable" indir
// 2) Scriptable'da + ile yeni script, bu dosyanın tamamını yapıştır
// 3) Üstte CITY = "Istanbul" satırını kendi şehrine göre değiştir
// 4) Ana ekranda boş alana basılı tut → + → Scriptable → Medium/Small
// 5) Widget ayarından bu scripti seç

const CITY = args.widgetParameter || "Istanbul";
const METHOD = 13; // Diyanet İşleri Başkanlığı

const THEME = {
  bg: new Color("#0a0a0a"),
  accent: new Color("#f5c518"),
  muted: new Color("#888888"),
  text: new Color("#ffffff"),
  soft: new Color("#1a1a1a"),
};

const NAMES = {
  Fajr: "İmsak",
  Sunrise: "Güneş",
  Dhuhr: "Öğle",
  Asr: "İkindi",
  Maghrib: "Akşam",
  Isha: "Yatsı",
};
const ORDER = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"];

async function fetchTimes(city) {
  const url = `https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(
    city
  )}&country=Turkey&method=${METHOD}`;
  const req = new Request(url);
  const json = await req.loadJSON();
  return json.data.timings;
}

function parseHM(hm) {
  const [h, m] = String(hm).split(":").map(Number);
  const d = new Date();
  d.setHours(h, m, 0, 0);
  return d;
}

function findNext(timings) {
  const now = new Date();
  for (const key of ORDER) {
    const t = parseHM(timings[key]);
    if (t > now) return { key, at: t };
  }
  const tomorrow = parseHM(timings.Fajr);
  tomorrow.setDate(tomorrow.getDate() + 1);
  return { key: "Fajr", at: tomorrow };
}

function pad(n) {
  return String(n).padStart(2, "0");
}

function fmtCountdown(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) return `${h}s ${pad(m)}d ${pad(s)}sn`;
  return `${m}d ${pad(s)}sn`;
}

function fmtClock(d) {
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

async function createWidget() {
  const timings = await fetchTimes(CITY);
  const next = findNext(timings);
  const now = new Date();
  const w = new ListWidget();
  w.backgroundColor = THEME.bg;
  w.setPadding(14, 16, 14, 16);

  const top = w.addStack();
  top.layoutHorizontally();
  const cityTxt = top.addText(CITY.toUpperCase());
  cityTxt.font = Font.boldSystemFont(11);
  cityTxt.textColor = THEME.muted;
  top.addSpacer();
  const clock = top.addText(fmtClock(now));
  clock.font = Font.boldSystemFont(11);
  clock.textColor = THEME.muted;

  w.addSpacer(8);

  const nextLabel = w.addText(`SONRAKİ · ${NAMES[next.key]}`);
  nextLabel.font = Font.semiboldSystemFont(12);
  nextLabel.textColor = THEME.accent;

  const countdown = w.addText(fmtCountdown(next.at - now));
  countdown.font = Font.boldSystemFont(28);
  countdown.textColor = THEME.text;
  countdown.minimumScaleFactor = 0.6;

  const nextTime = w.addText(fmtClock(next.at));
  nextTime.font = Font.systemFont(13);
  nextTime.textColor = THEME.muted;

  if (config.widgetFamily !== "small") {
    w.addSpacer(10);
    const row = w.addStack();
    row.layoutHorizontally();
    row.spacing = 6;
    for (const key of ORDER) {
      const col = row.addStack();
      col.layoutVertically();
      col.centerAlignContent();
      const isNext = key === next.key;
      const n = col.addText(NAMES[key]);
      n.font = Font.systemFont(9);
      n.textColor = isNext ? THEME.accent : THEME.muted;
      n.centerAlignText();
      const t = col.addText(String(timings[key]).slice(0, 5));
      t.font = Font.boldSystemFont(12);
      t.textColor = isNext ? THEME.accent : THEME.text;
      t.centerAlignText();
      if (key !== "Isha") row.addSpacer();
    }
  }

  w.refreshAfterDate = new Date(Date.now() + 60 * 1000);
  return w;
}

const widget = await createWidget();
if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  await widget.presentMedium();
}
Script.complete();
