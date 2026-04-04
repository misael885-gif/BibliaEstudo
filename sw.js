const CACHE_VERSION = "biblia-estudo-v7";
const SHELL_CACHE = `${CACHE_VERSION}-shell`;
const RUNTIME_CACHE = `${CACHE_VERSION}-runtime`;
const APP_SHELL = [
  "./",
  "./index.html",
  "./styles.css",
  "./app.js",
  "./pwa.js",
  "./data/catalog.js",
  "./data/translations.js",
  "./manifest.webmanifest",
  "./icons/icon.svg",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/apple-touch-icon.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    Promise.all([
      cleanupOldCaches(),
      self.clients.claim(),
    ])
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") {
    return;
  }

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  if (request.mode === "navigate") {
    event.respondWith(handleNavigationRequest(request));
    return;
  }

  if (shouldHandleAsStaticAsset(url.pathname)) {
    event.respondWith(cacheFirst(request));
  }
});

async function cleanupOldCaches() {
  const keys = await caches.keys();
  return Promise.all(
    keys
      .filter((key) => ![SHELL_CACHE, RUNTIME_CACHE].includes(key))
      .map((key) => caches.delete(key))
  );
}

async function handleNavigationRequest(request) {
  try {
    const response = await fetch(request);
    const cache = await caches.open(RUNTIME_CACHE);
    cache.put(request, response.clone());
    return response;
  } catch (error) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    return caches.match("./index.html");
  }
}

async function cacheFirst(request) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    refreshInBackground(request);
    return cachedResponse;
  }

  try {
    const response = await fetch(request);
    if (isCacheableResponse(response)) {
      const cache = await caches.open(RUNTIME_CACHE);
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    return caches.match(request);
  }
}

async function refreshInBackground(request) {
  try {
    const response = await fetch(request);
    if (!isCacheableResponse(response)) {
      return;
    }

    const cache = await caches.open(RUNTIME_CACHE);
    cache.put(request, response.clone());
  } catch (error) {
    return;
  }
}

function shouldHandleAsStaticAsset(pathname) {
  return (
    pathname.endsWith(".css") ||
    pathname.endsWith(".js") ||
    pathname.endsWith(".html") ||
    pathname.endsWith(".json") ||
    pathname.endsWith(".png") ||
    pathname.endsWith(".svg") ||
    pathname.endsWith(".webmanifest") ||
    pathname.startsWith("/data/")
  );
}

function isCacheableResponse(response) {
  return response && response.ok;
}
