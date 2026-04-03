const pwaElements = {
  installAppButton: document.querySelector("#installAppButton"),
  installPanel: document.querySelector("#installPanel"),
  installPanelTitle: document.querySelector("#installPanelTitle"),
  installPanelText: document.querySelector("#installPanelText"),
  installActionButton: document.querySelector("#installActionButton"),
  dismissInstallPanelButton: document.querySelector("#dismissInstallPanelButton"),
};

if (Object.values(pwaElements).every(Boolean)) {
  initPwa();
}

function initPwa() {
  const pwaState = {
    deferredPrompt: null,
    panelContext: null,
  };

  bindInstallEvents(pwaState);
  syncInstallUi(pwaState);

  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    pwaState.deferredPrompt = event;
    syncInstallUi(pwaState);
  });

  window.addEventListener("appinstalled", () => {
    pwaState.deferredPrompt = null;
    hideInstallPanel(pwaState);
    syncInstallUi(pwaState);
  });

  const displayModeMedia = window.matchMedia("(display-mode: standalone)");
  const syncDisplayMode = () => {
    if (isStandaloneMode()) {
      hideInstallPanel(pwaState);
    }

    syncInstallUi(pwaState);
  };

  if (typeof displayModeMedia.addEventListener === "function") {
    displayModeMedia.addEventListener("change", syncDisplayMode);
  } else if (typeof displayModeMedia.addListener === "function") {
    displayModeMedia.addListener(syncDisplayMode);
  }

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
}

function bindInstallEvents(pwaState) {
  pwaElements.installAppButton.addEventListener("click", async () => {
    const installContext = getInstallContext(pwaState);

    if (installContext.type === "direct") {
      await promptDirectInstall(pwaState);
      return;
    }

    showInstallPanel(pwaState, installContext);
  });

  pwaElements.installActionButton.addEventListener("click", async () => {
    await promptDirectInstall(pwaState);
  });

  pwaElements.dismissInstallPanelButton.addEventListener("click", () => {
    hideInstallPanel(pwaState);
    syncInstallUi(pwaState);
  });
}

function syncInstallUi(pwaState) {
  if (isStandaloneMode()) {
    pwaElements.installAppButton.hidden = true;
    pwaElements.installPanel.hidden = true;
    return;
  }

  const installContext = getInstallContext(pwaState);
  pwaElements.installAppButton.hidden = false;
  pwaElements.installAppButton.textContent = installContext.buttonLabel;

  if (pwaState.panelContext) {
    showInstallPanel(pwaState, getInstallContext(pwaState, pwaState.panelContext));
  }
}

function getInstallContext(pwaState, forcedType = null) {
  const type = forcedType || detectInstallType(pwaState);

  switch (type) {
    case "direct":
      return {
        type,
        buttonLabel: "Instalar app",
        title: "Instalar a Bíblia agora",
        text: "Este navegador já liberou a instalação. Toque em instalar para colocar a Bíblia na tela inicial com abertura em tela cheia.",
        showActionButton: true,
      };
    case "ios":
      return {
        type,
        buttonLabel: "Como instalar",
        title: "Instalar no iPad ou iPhone",
        text: "No Safari, toque em Compartilhar e depois em Adicionar à Tela de Início. Assim a Bíblia fica com ícone próprio e abre como app.",
        showActionButton: false,
      };
    case "file":
      return {
        type,
        buttonLabel: "Como instalar",
        title: "Abra por um endereço web",
        text: "Para instalar como app, esta Bíblia precisa ser aberta por https:// ou http://localhost. O arquivo aberto direto do computador não permite instalação nem cache offline.",
        showActionButton: false,
      };
    case "insecure":
      return {
        type,
        buttonLabel: "Como instalar",
        title: "Use HTTPS para instalar",
        text: "A instalação e o modo offline exigem um endereço seguro. Publique este app em HTTPS para instalar no iPad, no celular ou no desktop.",
        showActionButton: false,
      };
    default:
      return {
        type: "browser",
        buttonLabel: "Como instalar",
        title: "Instalação pelo navegador",
        text: "Se o navegador ainda não mostrou a instalação automática, use o menu do navegador e procure por Instalar app ou Adicionar à Tela inicial.",
        showActionButton: false,
      };
  }
}

function detectInstallType(pwaState) {
  if (pwaState.deferredPrompt) {
    return "direct";
  }

  if (location.protocol === "file:") {
    return "file";
  }

  if (!canRegisterServiceWorker()) {
    return "insecure";
  }

  if (isIosDevice()) {
    return "ios";
  }

  return "browser";
}

async function promptDirectInstall(pwaState) {
  if (!pwaState.deferredPrompt) {
    showInstallPanel(pwaState, getInstallContext(pwaState));
    return;
  }

  const promptEvent = pwaState.deferredPrompt;
  promptEvent.prompt();

  try {
    await promptEvent.userChoice;
  } finally {
    pwaState.deferredPrompt = null;
    hideInstallPanel(pwaState);
    syncInstallUi(pwaState);
  }
}

function showInstallPanel(pwaState, installContext) {
  pwaState.panelContext = installContext.type;
  pwaElements.installPanelTitle.textContent = installContext.title;
  pwaElements.installPanelText.textContent = installContext.text;
  pwaElements.installActionButton.hidden = !installContext.showActionButton;
  pwaElements.installPanel.hidden = false;
}

function hideInstallPanel(pwaState) {
  pwaState.panelContext = null;
  pwaElements.installPanel.hidden = true;
  pwaElements.installActionButton.hidden = true;
}

function canRegisterServiceWorker() {
  return Boolean(
    window.isSecureContext ||
      location.hostname === "localhost" ||
      location.hostname === "127.0.0.1"
  );
}

function isStandaloneMode() {
  return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;
}

function isIosDevice() {
  const userAgent = window.navigator.userAgent || "";
  const platform = window.navigator.platform || "";
  const maxTouchPoints = window.navigator.maxTouchPoints || 0;

  return /iPad|iPhone|iPod/.test(userAgent) || (platform === "MacIntel" && maxTouchPoints > 1);
}
