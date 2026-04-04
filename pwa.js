if ("serviceWorker" in navigator && canRegisterServiceWorker()) {
  window.addEventListener(
    "load",
    () => {
      navigator.serviceWorker.register("./sw.js").catch(() => {
        return;
      });
    },
    { once: true }
  );
}

function canRegisterServiceWorker() {
  return Boolean(
    window.isSecureContext ||
      location.hostname === "localhost" ||
      location.hostname === "127.0.0.1"
  );
}
