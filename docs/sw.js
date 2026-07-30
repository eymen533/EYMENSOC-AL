/* Unregisters itself — Safari crashes on SW + Cloudflare redirect responses */
self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
      const regs = await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: "window" });
      for (const client of clients) {
        client.navigate(client.url).catch(() => {});
      }
      await self.clients.claim();
      return regs;
    })()
  );
});

/* Do not intercept fetches — avoids "Response served by service worker has redirections" */
