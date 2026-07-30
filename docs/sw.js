/* Cache-first app shell — survives tunnel death / offline reopen on iPhone */
const CACHE = "namaz-v3";
const ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/apple-touch-icon.png",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./fonts/SF-Pro-Display-Bold.woff2",
  "./fonts/SF-Pro-Display-Medium.woff2",
  "./fonts/SF-Pro-Display-Regular.woff2",
  "./fonts/SF-Pro-Display-Semibold.woff2",
  "./fonts/SF-Pro-Text-Regular.woff2",
  "./fonts/SF-Pro-Text-Semibold.woff2",
  "./fonts/SF-Pro-Text-Bold.woff2",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) =>
        Promise.all(
          ASSETS.map((url) =>
            cache.add(url).catch(() => cache.add(new Request(url, { cache: "reload" })).catch(() => null))
          )
        )
      )
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  // Prayer API: network only (never poison cache with errors)
  if (url.hostname.includes("aladhan.com")) return;

  if (url.origin !== self.location.origin) return;

  // Navigations / HTML: cache-first so Ana Ekran reopen works offline
  const accept = req.headers.get("accept") || "";
  const isNav = req.mode === "navigate" || accept.includes("text/html");

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      const cached = await cache.match(req, { ignoreSearch: true });
      if (isNav) {
        const shell = cached || (await cache.match("./index.html")) || (await cache.match("./"));
        if (shell) {
          // Refresh in background when online
          fetch(req)
            .then((res) => {
              if (res && res.ok) cache.put("./index.html", res.clone());
            })
            .catch(() => {});
          return shell;
        }
      } else if (cached) {
        fetch(req)
          .then((res) => {
            if (res && res.ok) cache.put(req, res.clone());
          })
          .catch(() => {});
        return cached;
      }

      try {
        const res = await fetch(req);
        if (res && res.ok) cache.put(req, res.clone());
        return res;
      } catch (err) {
        if (cached) return cached;
        if (isNav) {
          const fallback = (await cache.match("./index.html")) || (await cache.match("./"));
          if (fallback) return fallback;
        }
        throw err;
      }
    })()
  );
});
