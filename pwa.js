if ("serviceWorker" in navigator) {
  window.addEventListener(
    "load",
    () => {
      navigator.serviceWorker.getRegistrations().then((registrations) => {
        return Promise.all(registrations.map((registration) => registration.unregister()));
      }).then(() => {
        if (typeof caches === "undefined") {
          return;
        }

        return caches.keys().then((keys) => {
          return Promise.all(
            keys
              .filter((key) => key.startsWith("biblia-estudo-"))
              .map((key) => caches.delete(key))
          );
        });
      }).catch(() => {
        return;
      });
    },
    { once: true }
  );
}
