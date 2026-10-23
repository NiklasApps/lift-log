// Offline cache for the self-hosted copy. Pages: network first so updates show up;
// everything else (icons, fonts): cache first.
const CACHE = "liftlog-v2";
const CORE = ["./", "./liftlog.html", "./manifest.webmanifest", "./favicon.svg", "./favicon-32.png", "./liftlog-icon-180.png", "./liftlog-icon-512.png", "./liftlog-maskable-512.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const put = res => { if (res.ok || res.type === "opaque") { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return res; };
  if (req.mode === "navigate") {
    e.respondWith(fetch(req).then(put).catch(() => caches.match(req).then(r => r || caches.match("./liftlog.html"))));
    return;
  }
  e.respondWith(caches.match(req).then(r => r || fetch(req).then(put)));
});
