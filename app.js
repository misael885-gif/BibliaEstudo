const config = window.__BIBLIA_CONFIG__;

const TABLET_SIDEBAR_QUERY = "(max-width: 1180px)";

if (!config || !Array.isArray(config.books) || config.books.length === 0) {
  throw new Error("O catálogo da Bíblia não foi carregado.");
}

const translations = getAvailableTranslations();
const translationMap = Object.fromEntries(translations.map((translation) => [translation.code, translation]));
const defaultTranslationCode = translations[0].code;

const store = {
  books: Object.create(null),
  refs: Object.create(null),
  loading: new Map(),
};

window.__BIBLIA_REGISTER_BOOK__ = (translationCodeOrSlug, slugOrPayload, maybePayload) => {
  const hasExplicitTranslation = typeof maybePayload !== "undefined";
  const translationCode = hasExplicitTranslation ? translationCodeOrSlug : defaultTranslationCode;
  const slug = hasExplicitTranslation ? slugOrPayload : translationCodeOrSlug;
  const payload = hasExplicitTranslation ? maybePayload : slugOrPayload;

  if (!store.books[translationCode]) {
    store.books[translationCode] = Object.create(null);
  }

  store.books[translationCode][slug] = payload;
};

window.__BIBLIA_REGISTER_REFS__ = (slug, payload) => {
  store.refs[slug] = payload;
};

const state = {
  translationCode: defaultTranslationCode,
  book: config.books[0].slug,
  chapter: 1,
  verse: null,
  end: null,
  fromBook: null,
  fromChapter: null,
  fromVerse: null,
  activeTestament: "AT",
  referencePreview: null,
  sidebarOpen: false,
  dailyVerse: null,
  backToTopTarget: null,
};

const elements = {
  shell: document.querySelector("#shell"),
  sidebar: document.querySelector("#sidebar"),
  translationSelect: document.querySelector("#translationSelect"),
  bookSelect: document.querySelector("#bookSelect"),
  chapterInput: document.querySelector("#chapterInput"),
  verseInput: document.querySelector("#verseInput"),
  jumpForm: document.querySelector("#jumpForm"),
  bookGrid: document.querySelector("#bookGrid"),
  chapterGrid: document.querySelector("#chapterGrid"),
  passageTitle: document.querySelector("#passageTitle"),
  passageSubtitle: document.querySelector("#passageSubtitle"),
  verses: document.querySelector("#verses"),
  readerStatus: document.querySelector("#readerStatus"),
  prevChapterButton: document.querySelector("#prevChapterButton"),
  nextChapterButton: document.querySelector("#nextChapterButton"),
  testamentTabs: [...document.querySelectorAll(".tab")],
  translationMeta: document.querySelector("#translationMeta"),
  menuToggleButton: document.querySelector("#menuToggleButton"),
  closeSidebarButton: document.querySelector("#closeSidebarButton"),
  sidebarBackdrop: document.querySelector("#sidebarBackdrop"),
  dailyVerseCard: document.querySelector("#dailyVerseCard"),
  dailyGreeting: document.querySelector("#dailyGreeting"),
  dailyVerseReference: document.querySelector("#dailyVerseReference"),
  dailyVerseText: document.querySelector("#dailyVerseText"),
  openDailyVerseButton: document.querySelector("#openDailyVerseButton"),
  backToTopButton: document.querySelector("#backToTopButton"),
};

const tabletSidebarMedia = window.matchMedia(TABLET_SIDEBAR_QUERY);
let renderToken = 0;
let referenceToken = 0;
let dailyVerseToken = 0;

init();

function init() {
  populateSelects();
  populateBookButtons();
  bindEvents();
  syncStateFromHash();
  syncSidebarUi();
  render();
}

function bindEvents() {
  window.addEventListener("hashchange", () => {
    closeSidebar({ restoreFocus: false });
    closeReferencePreview({ rerender: false });
    syncStateFromHash();
    render();
  });

  elements.translationSelect.addEventListener("change", () => {
    closeSidebar({ restoreFocus: false });
    updateHash({
      translationCode: elements.translationSelect.value,
      book: state.book,
      chapter: state.chapter,
      verse: state.verse,
      end: state.end,
      fromBook: null,
      fromChapter: null,
      fromVerse: null,
    });
  });

  elements.jumpForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const meta = getBookMeta(elements.bookSelect.value);
    if (!meta) {
      return;
    }

    const chapter = clampNumber(parseInteger(elements.chapterInput.value, 1), 1, meta.chapterCount);
    const verseValue = elements.verseInput.value.trim();
    const verse = verseValue ? Math.max(1, parseInteger(verseValue, 1)) : null;

    closeSidebar({ restoreFocus: false });
    updateHash({
      book: meta.slug,
      chapter,
      verse,
      end: null,
      fromBook: null,
      fromChapter: null,
      fromVerse: null,
    });
  });

  elements.bookGrid.addEventListener("click", (event) => {
    const button = event.target.closest("[data-book]");
    if (!button) {
      return;
    }

    closeSidebar({ restoreFocus: false });
    updateHash({
      book: button.dataset.book,
      chapter: 1,
      verse: null,
      end: null,
      fromBook: null,
      fromChapter: null,
      fromVerse: null,
    });
  });

  elements.chapterGrid.addEventListener("click", (event) => {
    const button = event.target.closest("[data-chapter]");
    if (!button) {
      return;
    }

    closeSidebar({ restoreFocus: false });
    updateHash({
      book: state.book,
      chapter: Number(button.dataset.chapter),
      verse: null,
      end: null,
      fromBook: null,
      fromChapter: null,
      fromVerse: null,
    });
  });

  elements.prevChapterButton.addEventListener("click", () => {
    const meta = getBookMeta(state.book);
    if (!meta) {
      return;
    }

    if (state.chapter > 1) {
      closeSidebar({ restoreFocus: false });
      updateHash({
        book: state.book,
        chapter: state.chapter - 1,
        verse: null,
        end: null,
        fromBook: null,
        fromChapter: null,
        fromVerse: null,
      });
      return;
    }

    const previousBook = config.books[meta.index - 1];
    if (previousBook) {
      closeSidebar({ restoreFocus: false });
      updateHash({
        book: previousBook.slug,
        chapter: previousBook.chapterCount,
        verse: null,
        end: null,
        fromBook: null,
        fromChapter: null,
        fromVerse: null,
      });
    }
  });

  elements.nextChapterButton.addEventListener("click", () => {
    const meta = getBookMeta(state.book);
    if (!meta) {
      return;
    }

    if (state.chapter < meta.chapterCount) {
      closeSidebar({ restoreFocus: false });
      updateHash({
        book: state.book,
        chapter: state.chapter + 1,
        verse: null,
        end: null,
        fromBook: null,
        fromChapter: null,
        fromVerse: null,
      });
      return;
    }

    const nextBook = config.books[meta.index + 1];
    if (nextBook) {
      closeSidebar({ restoreFocus: false });
      updateHash({
        book: nextBook.slug,
        chapter: 1,
        verse: null,
        end: null,
        fromBook: null,
        fromChapter: null,
        fromVerse: null,
      });
    }
  });

  elements.testamentTabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      state.activeTestament = tab.dataset.testament;
      renderBookButtons();
      renderTabs();
    });
  });

  elements.menuToggleButton.addEventListener("click", () => {
    toggleSidebar();
  });

  elements.closeSidebarButton.addEventListener("click", () => {
    closeSidebar();
  });

  elements.sidebarBackdrop.addEventListener("click", () => {
    closeSidebar();
  });

  elements.openDailyVerseButton.addEventListener("click", () => {
    if (!state.dailyVerse) {
      return;
    }

    state.backToTopTarget = {
      translationCode: state.translationCode,
      book: state.dailyVerse.book,
      chapter: state.dailyVerse.chapter,
      verse: state.dailyVerse.verse,
    };

    closeSidebar({ restoreFocus: false });
    updateHash({
      translationCode: state.translationCode,
      book: state.dailyVerse.book,
      chapter: state.dailyVerse.chapter,
      verse: state.dailyVerse.verse,
      end: null,
      fromBook: null,
      fromChapter: null,
      fromVerse: null,
    });
  });

  elements.backToTopButton.addEventListener("click", () => {
    elements.dailyVerseCard.scrollIntoView({ block: "start", behavior: "smooth" });
  });

  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeSidebar();
    }
  });

  window.addEventListener("scroll", syncBackToTopButton, { passive: true });
  window.addEventListener("resize", syncBackToTopButton);

  const syncSidebarOnViewportChange = () => {
    if (!isTabletSidebarLayout()) {
      state.sidebarOpen = false;
    }

    syncSidebarUi();
  };

  if (typeof tabletSidebarMedia.addEventListener === "function") {
    tabletSidebarMedia.addEventListener("change", syncSidebarOnViewportChange);
  } else if (typeof tabletSidebarMedia.addListener === "function") {
    tabletSidebarMedia.addListener(syncSidebarOnViewportChange);
  }

  elements.verses.addEventListener("click", (event) => {
    const closeButton = event.target.closest("[data-close-reference]");
    if (closeButton) {
      closeReferencePreview();
      return;
    }

    const referenceButton = event.target.closest("[data-ref-book-index]");
    if (referenceButton) {
      const previewRequest = {
        sourceBook: state.book,
        sourceChapter: state.chapter,
        sourceVerse: Number(referenceButton.dataset.sourceVerse),
        targetBookIndex: Number(referenceButton.dataset.refBookIndex),
        targetChapter: Number(referenceButton.dataset.refChapter),
        targetStart: Number(referenceButton.dataset.refStart),
        targetEnd: Number(referenceButton.dataset.refEnd),
      };

      if (isSameReferencePreview(state.referencePreview, previewRequest)) {
        closeReferencePreview();
        return;
      }

      openReferencePreview(previewRequest);
      return;
    }

    const verseButton = event.target.closest("[data-verse]");
    if (verseButton) {
      closeSidebar({ restoreFocus: false });
      updateHash({
        book: state.book,
        chapter: state.chapter,
        verse: Number(verseButton.dataset.verse),
        end: null,
        fromBook: null,
        fromChapter: null,
        fromVerse: null,
      });
    }
  });

}

function isTabletSidebarLayout() {
  return tabletSidebarMedia.matches;
}

function toggleSidebar() {
  if (!isTabletSidebarLayout()) {
    return;
  }

  if (state.sidebarOpen) {
    closeSidebar();
    return;
  }

  state.sidebarOpen = true;
  syncSidebarUi();
}

function closeSidebar(options = {}) {
  const restoreFocus = options.restoreFocus !== false;
  if (!state.sidebarOpen) {
    syncSidebarUi();
    return;
  }

  state.sidebarOpen = false;
  syncSidebarUi();

  if (restoreFocus) {
    elements.menuToggleButton.focus();
  }
}

function syncSidebarUi() {
  const useTabletSidebar = isTabletSidebarLayout();
  const isOpen = useTabletSidebar && state.sidebarOpen;

  elements.shell.classList.toggle("is-sidebar-open", isOpen);
  document.body.classList.toggle("is-sidebar-open", isOpen);
  elements.menuToggleButton.hidden = !useTabletSidebar;
  elements.menuToggleButton.setAttribute("aria-expanded", String(isOpen));
  elements.sidebar.setAttribute("aria-hidden", String(useTabletSidebar && !isOpen));
}

function populateSelects() {
  elements.translationSelect.innerHTML = translations
    .map(
      (translation) =>
        `<option value="${translation.code}">${escapeHtml(translation.shortName || translation.name)}</option>`
    )
    .join("");

  elements.bookSelect.innerHTML = config.books
    .map((book) => `<option value="${book.slug}">${escapeHtml(book.name)}</option>`)
    .join("");

  const activeTranslation = getActiveTranslation();
  elements.translationMeta.textContent = `${activeTranslation.name} · ${activeTranslation.license}`;
}

function populateBookButtons() {
  elements.bookGrid.innerHTML = config.books
    .map(
      (book) => `
        <button
          type="button"
          class="book-grid__button"
          data-book="${book.slug}"
          data-testament="${book.testament}"
        >
          ${escapeHtml(book.name)}
        </button>
      `
    )
    .join("");
}

function syncStateFromHash() {
  const params = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  const requestedTranslation = params.get("version");
  const requestedBook = params.get("book");
  const meta = getBookMeta(requestedBook) || config.books[0];
  const translation = getTranslationMeta(requestedTranslation) || getTranslationMeta(defaultTranslationCode);

  state.translationCode = translation.code;
  state.book = meta.slug;
  state.chapter = clampNumber(parseInteger(params.get("chapter"), 1), 1, meta.chapterCount);
  state.verse = params.has("verse") ? Math.max(1, parseInteger(params.get("verse"), 1)) : null;
  state.end = params.has("end") ? Math.max(state.verse || 1, parseInteger(params.get("end"), state.verse || 1)) : null;
  state.fromBook = getBookMeta(params.get("fromBook")) ? params.get("fromBook") : null;
  state.fromChapter = state.fromBook ? Math.max(1, parseInteger(params.get("fromChapter"), 1)) : null;
  state.fromVerse = state.fromBook ? Math.max(1, parseInteger(params.get("fromVerse"), 1)) : null;
  state.activeTestament = meta.testament;

  if (state.backToTopTarget && !matchesPassageTarget(state.backToTopTarget)) {
    state.backToTopTarget = null;
  }
}

function updateHash(nextState) {
  closeReferencePreview({ rerender: false });

  const mergedState = {
    translationCode: nextState.translationCode || state.translationCode || defaultTranslationCode,
    book: nextState.book || state.book,
    chapter: nextState.chapter || state.chapter,
    verse: Object.prototype.hasOwnProperty.call(nextState, "verse") ? nextState.verse : state.verse,
    end: Object.prototype.hasOwnProperty.call(nextState, "end") ? nextState.end : state.end,
    fromBook: Object.prototype.hasOwnProperty.call(nextState, "fromBook") ? nextState.fromBook : state.fromBook,
    fromChapter: Object.prototype.hasOwnProperty.call(nextState, "fromChapter") ? nextState.fromChapter : state.fromChapter,
    fromVerse: Object.prototype.hasOwnProperty.call(nextState, "fromVerse") ? nextState.fromVerse : state.fromVerse,
  };

  const params = new URLSearchParams();
  params.set("version", mergedState.translationCode);
  params.set("book", mergedState.book);
  params.set("chapter", String(mergedState.chapter));

  if (mergedState.verse) {
    params.set("verse", String(mergedState.verse));
  }

  if (mergedState.end && mergedState.end !== mergedState.verse) {
    params.set("end", String(mergedState.end));
  }

  if (mergedState.fromBook && mergedState.fromChapter && mergedState.fromVerse) {
    params.set("fromBook", mergedState.fromBook);
    params.set("fromChapter", String(mergedState.fromChapter));
    params.set("fromVerse", String(mergedState.fromVerse));
  }

  const nextHash = params.toString();
  if (window.location.hash.replace(/^#/, "") === nextHash) {
    syncStateFromHash();
    render();
    return;
  }

  window.location.hash = nextHash;
}

async function render(options = {}) {
  const skipFocus = Boolean(options.skipFocus);
  const currentToken = ++renderToken;
  const meta = getBookMeta(state.book);
  const activeTranslation = getActiveTranslation();
  if (!meta) {
    return;
  }

  renderDailyVerseCard();
  setLoading(true, "Carregando texto...");

  try {
    await Promise.all([loadBookData(state.translationCode, state.book), loadRefData(state.book)]);
  } catch (error) {
    elements.verses.innerHTML = `
      <article class="verse">
        <div class="verse__body">Não foi possível carregar este livro agora.</div>
      </article>
    `;
    setLoading(false, "");
    return;
  }

  if (currentToken !== renderToken) {
    return;
  }

  const translationBooks = store.books[state.translationCode] || {};
  const chapters = translationBooks[state.book] || [];
  const chapterVerses = chapters[state.chapter - 1] || [];
  const refMap = store.refs[state.book] || {};

  elements.passageTitle.textContent = `${meta.name} ${state.chapter}`;
  elements.passageSubtitle.textContent = `${activeTranslation.name} · capítulo ${state.chapter} de ${meta.chapterCount}`;
  elements.translationSelect.value = state.translationCode;
  elements.bookSelect.value = state.book;
  elements.chapterInput.value = String(state.chapter);
  elements.verseInput.value = state.verse ? String(state.verse) : "";
  elements.translationMeta.textContent = `${activeTranslation.name} · ${activeTranslation.license}`;

  renderTabs();
  renderBookButtons();
  renderChapterButtons(meta.chapterCount);
  renderReferenceBanner();
  syncBackToTopButton();

  elements.verses.innerHTML = chapterVerses
    .map((text, index) => renderVerse({ text, verseNumber: index + 1, refMap }))
    .filter(Boolean)
    .join("");

  setLoading(false, "");
  syncBackToTopButton();

  if (!skipFocus) {
    requestAnimationFrame(() => {
      focusVerse();
    });
  }
}

function renderTabs() {
  elements.testamentTabs.forEach((tab) => {
    tab.classList.toggle("is-active", tab.dataset.testament === state.activeTestament);
  });
}

function renderBookButtons() {
  const buttons = [...elements.bookGrid.querySelectorAll("[data-book]")];
  buttons.forEach((button) => {
    const isVisible = button.dataset.testament === state.activeTestament;
    button.hidden = !isVisible;
    button.classList.toggle("is-active", button.dataset.book === state.book);
  });
}

function renderChapterButtons(count) {
  elements.chapterGrid.innerHTML = Array.from({ length: count }, (_, index) => {
    const chapter = index + 1;
    const className = chapter === state.chapter ? "chapter-grid__button is-active" : "chapter-grid__button";
    return `<button type="button" class="${className}" data-chapter="${chapter}">${chapter}</button>`;
  }).join("");
}

function renderReferenceBanner() {
  return;
}

async function renderDailyVerseCard() {
  const now = new Date();
  const dateKey = getLocalDateKey(now);
  const period = getGreetingPeriod(now);
  const greeting = getGreetingForTime(now);
  const activeTranslation = getActiveTranslation();
  const selection = getDailyVerseSelection(now);

  if (
    state.dailyVerse &&
    state.dailyVerse.translationCode === state.translationCode &&
    state.dailyVerse.dateKey === dateKey
  ) {
    renderDailyVerseContent(state.dailyVerse, greeting, activeTranslation, period);
    return;
  }

  renderDailyVerseLoading(selection, greeting, activeTranslation, period);
  const token = ++dailyVerseToken;

  try {
    await loadBookData(state.translationCode, selection.book);
  } catch (error) {
    if (token !== dailyVerseToken) {
      return;
    }

    state.dailyVerse = null;
    renderDailyVerseError(greeting, period);
    return;
  }

  if (token !== dailyVerseToken) {
    return;
  }

  const translationBooks = store.books[state.translationCode] || {};
  const chapters = translationBooks[selection.book] || [];
  const chapterVerses = chapters[selection.chapter - 1] || [];
  const pickedVerse = pickDailyVerseFromChapter(
    chapterVerses,
    `${selection.dateKey}:${selection.book}:${selection.chapter}:verse`
  );

  if (!pickedVerse) {
    state.dailyVerse = null;
    renderDailyVerseError(greeting, period);
    return;
  }

  state.dailyVerse = {
    translationCode: state.translationCode,
    dateKey: selection.dateKey,
    book: selection.book,
    chapter: selection.chapter,
    verse: pickedVerse.verse,
    text: pickedVerse.text,
  };

  renderDailyVerseContent(state.dailyVerse, greeting, activeTranslation, period);
}

function renderDailyVerseLoading(selection, greeting, translation, period) {
  const bookMeta = getBookMeta(selection.book);
  elements.dailyVerseCard.dataset.period = period;
  elements.dailyGreeting.textContent = greeting;
  elements.dailyVerseReference.textContent = bookMeta
    ? `${bookMeta.name} ${selection.chapter} · ${translation.shortName || translation.name}`
    : translation.shortName || translation.name;
  elements.dailyVerseText.textContent = "Preparando o versículo de hoje...";
  elements.openDailyVerseButton.disabled = true;
  syncBackToTopButton();
}

function renderDailyVerseContent(dailyVerse, greeting, translation, period) {
  const bookMeta = getBookMeta(dailyVerse.book);
  if (!bookMeta) {
    renderDailyVerseError(greeting, period);
    return;
  }

  elements.dailyVerseCard.dataset.period = period;
  elements.dailyGreeting.textContent = greeting;
  elements.dailyVerseReference.textContent = `${bookMeta.name} ${dailyVerse.chapter}:${dailyVerse.verse} · ${translation.shortName || translation.name}`;
  elements.dailyVerseText.textContent = dailyVerse.text;
  elements.openDailyVerseButton.disabled = false;
  elements.openDailyVerseButton.setAttribute(
    "aria-label",
    `Abrir ${bookMeta.name} ${dailyVerse.chapter}:${dailyVerse.verse}`
  );
  syncBackToTopButton();
}

function renderDailyVerseError(greeting, period) {
  elements.dailyVerseCard.dataset.period = period;
  elements.dailyGreeting.textContent = greeting;
  elements.dailyVerseReference.textContent = "Versículo do dia";
  elements.dailyVerseText.textContent = "Não foi possível carregar a passagem de hoje agora.";
  elements.openDailyVerseButton.disabled = true;
  syncBackToTopButton();
}

function renderVerse({ text, verseNumber, refMap }) {
  if (!text) {
    return "";
  }

  const isFocused = state.verse && verseNumber === state.verse;
  const bookName = getBookMeta(state.book)?.name || state.book;
  const verseLabel = `${bookName} ${state.chapter}:${verseNumber}`;
  const verseKey = `${state.chapter}:${verseNumber}`;
  const references = refMap[verseKey] || [];
  const classes = ["verse"];
  const inlineReferencePreview = renderInlineReferencePreview(verseNumber);
  if (isFocused) {
    classes.push("is-focused");
  }

  return `
    <article class="${classes.join(" ")}" id="${getVerseElementId(state.book, state.chapter, verseNumber)}">
      <div class="verse__head">
        <button type="button" class="verse__number" data-verse="${verseNumber}" aria-label="Ir para ${verseLabel}">${verseLabel}</button>
      </div>
      <div class="verse__body">
        <span class="verse__text">${escapeHtml(text)}</span>
      </div>
      ${
        references.length
          ? `
            <div class="verse__references">
              <div class="verse__references-title">Referências</div>
              <div class="verse__references-list">
                ${references.map((reference) => renderReferenceChip(reference, verseNumber)).join("")}
              </div>
              ${inlineReferencePreview}
            </div>
          `
          : ""
      }
    </article>
  `;
}

function getGreetingPeriod(date = new Date()) {
  const hour = date.getHours();
  if (hour < 12) {
    return "morning";
  }

  if (hour < 18) {
    return "afternoon";
  }

  return "night";
}

function getGreetingForTime(date = new Date()) {
  const period = getGreetingPeriod(date);
  if (period === "morning") {
    return "Bom dia, Deus esteja conosco!";
  }

  if (period === "afternoon") {
    return "Boa tarde, Deus esteja conosco!";
  }

  return "Boa noite, Deus esteja conosco!";
}

function getDailyVerseSelection(date = new Date()) {
  const dateKey = getLocalDateKey(date);
  const bookIndex = pickSeededIndex(`${dateKey}:book`, config.books.length);
  const book = config.books[bookIndex];
  const chapter = pickSeededIndex(`${dateKey}:${book.slug}:chapter`, book.chapterCount) + 1;

  return {
    dateKey,
    book: book.slug,
    chapter,
  };
}

function pickDailyVerseFromChapter(chapterVerses, seed) {
  const availableVerses = chapterVerses
    .map((text, index) => ({
      verse: index + 1,
      text,
    }))
    .filter((item) => typeof item.text === "string" && item.text.trim());

  if (availableVerses.length === 0) {
    return null;
  }

  return availableVerses[pickSeededIndex(seed, availableVerses.length)];
}

function renderReferenceChip(reference, sourceVerse) {
  const targetMeta = config.books[reference[0]];
  if (!targetMeta) {
    return "";
  }

  const label = `${targetMeta.name} ${reference[1]}:${reference[2]}${reference[3] !== reference[2] ? `-${reference[3]}` : ""}`;
  const isOpen = isSameReferencePreview(state.referencePreview, {
    sourceBook: state.book,
    sourceChapter: state.chapter,
    sourceVerse,
    targetBookIndex: reference[0],
    targetChapter: reference[1],
    targetStart: reference[2],
    targetEnd: reference[3],
  });

  return `
    <button
      type="button"
      class="cross-reference${isOpen ? " is-open" : ""}"
      data-ref-book-index="${reference[0]}"
      data-ref-chapter="${reference[1]}"
      data-ref-start="${reference[2]}"
      data-ref-end="${reference[3]}"
      data-source-verse="${sourceVerse}"
      title="Ver ${escapeHtml(label)} abaixo deste versículo"
    >
      ${escapeHtml(label)}
    </button>
  `;
}

function renderInlineReferencePreview(verseNumber) {
  const preview = state.referencePreview;
  if (
    !preview ||
    preview.sourceBook !== state.book ||
    preview.sourceChapter !== state.chapter ||
    preview.sourceVerse !== verseNumber
  ) {
    return "";
  }

  const targetMeta = config.books[preview.targetBookIndex];
  if (!targetMeta) {
    return "";
  }

  const targetLabel = `${targetMeta.name} ${preview.targetChapter}:${preview.targetStart}${preview.targetEnd !== preview.targetStart ? `-${preview.targetEnd}` : ""}`;

  if (preview.loading) {
    return `
      <section class="inline-reference">
        <div class="inline-reference__status">Carregando ${escapeHtml(targetLabel)}...</div>
      </section>
    `;
  }

  if (preview.error) {
    return `
      <section class="inline-reference">
        <div class="inline-reference__status">Não foi possível abrir essa referência agora.</div>
      </section>
    `;
  }

  if (!preview.verses || preview.verses.length === 0) {
    return `
      <section class="inline-reference">
        <div class="inline-reference__status">Essa referência não trouxe texto disponível para exibir.</div>
      </section>
    `;
  }

  return `
    <section class="inline-reference">
      <div class="inline-reference__header">
        <div>
          <div class="inline-reference__eyebrow">Referência aberta</div>
          <div class="inline-reference__title">${escapeHtml(targetLabel)}</div>
        </div>
        <button type="button" class="button button--secondary inline-reference__close" data-close-reference="true">Fechar</button>
      </div>
      <div class="inline-reference__verses">
        ${preview.verses
          .map(
            (item) => `
              <article class="inline-reference__verse">
                <div class="inline-reference__verse-number">${item.verse}</div>
                <div class="inline-reference__verse-text">${escapeHtml(item.text)}</div>
              </article>
            `
          )
          .join("")}
      </div>
    </section>
  `;
}

async function openReferencePreview(previewRequest) {
  const targetBook = config.books[previewRequest.targetBookIndex];
  if (!targetBook) {
    return;
  }

  const token = ++referenceToken;
  state.referencePreview = {
    ...previewRequest,
    loading: true,
    error: false,
    verses: [],
  };
  render({ skipFocus: true });

  try {
    await loadBookData(state.translationCode, targetBook.slug);
  } catch (error) {
    if (token !== referenceToken) {
      return;
    }

    state.referencePreview = {
      ...previewRequest,
      loading: false,
      error: true,
      verses: [],
    };
    render({ skipFocus: true });
    return;
  }

  if (token !== referenceToken) {
    return;
  }

  const translationBooks = store.books[state.translationCode] || {};
  const chapters = translationBooks[targetBook.slug] || [];
  const chapterVerses = chapters[previewRequest.targetChapter - 1] || [];
  const verses = [];

  for (let verse = previewRequest.targetStart; verse <= previewRequest.targetEnd; verse++) {
    const text = chapterVerses[verse - 1];
    if (text) {
      verses.push({ verse, text });
    }
  }

  state.referencePreview = {
    ...previewRequest,
    loading: false,
    error: false,
    verses,
  };
  render({ skipFocus: true });
}

function closeReferencePreview(options = {}) {
  const rerender = options.rerender !== false;
  referenceToken += 1;
  state.referencePreview = null;
  renderReferenceBanner();

  if (rerender) {
    render({ skipFocus: true });
  }
}

function focusVerse() {
  if (!state.verse || state.referencePreview) {
    return;
  }

  const target = document.getElementById(getVerseElementId(state.book, state.chapter, state.verse));
  if (!target) {
    return;
  }

  target.scrollIntoView({ block: "center", behavior: "smooth" });
  window.setTimeout(syncBackToTopButton, 280);
}

function setLoading(isLoading, message) {
  elements.readerStatus.hidden = !isLoading;
  elements.readerStatus.textContent = message;
}

async function loadBookData(translationCode, slug) {
  if (store.books[translationCode]?.[slug]) {
    return;
  }

  const translation = getTranslationMeta(translationCode);
  if (!translation) {
    throw new Error(`Tradução desconhecida: ${translationCode}`);
  }

  await loadScript(`book:${translationCode}:${slug}`, `${translation.dataPath}/${slug}.js`);
}

async function loadRefData(slug) {
  if (store.refs[slug]) {
    return;
  }

  await loadScript(`ref:${slug}`, `data/refs/${slug}.js`);
}

function loadScript(key, src) {
  if (store.loading.has(key)) {
    return store.loading.get(key);
  }

  const promise = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.charset = "utf-8";
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error(`Falha ao carregar ${src}`));
    document.head.appendChild(script);
  }).finally(() => {
    store.loading.delete(key);
  });

  store.loading.set(key, promise);
  return promise;
}

function getAvailableTranslations() {
  const registeredTranslations = Array.isArray(window.__BIBLIA_TRANSLATIONS__) ? window.__BIBLIA_TRANSLATIONS__ : [];
  if (registeredTranslations.length > 0) {
    return registeredTranslations.map((translation) => ({
      ...translation,
      dataPath: translation.dataPath || "data/books",
    }));
  }

  return [
    {
      ...config.translation,
      shortName: config.translation.code,
      dataPath: "data/books",
    },
  ];
}

function getTranslationMeta(code) {
  return translationMap[code] || null;
}

function getActiveTranslation() {
  return getTranslationMeta(state.translationCode) || getTranslationMeta(defaultTranslationCode);
}

function getBookMeta(slug) {
  return config.books.find((book) => book.slug === slug) || null;
}

function getVerseElementId(book, chapter, verse) {
  return `verse-${book}-${chapter}-${verse}`;
}

function syncBackToTopButton() {
  const shouldShow = shouldShowBackToTopButton();
  elements.backToTopButton.hidden = !shouldShow;
}

function shouldShowBackToTopButton() {
  if (!state.backToTopTarget) {
    return false;
  }

  if (!matchesPassageTarget(state.backToTopTarget)) {
    return false;
  }

  return getScrollTop() > 24;
}

function matchesPassageTarget(target) {
  if (!target) {
    return false;
  }

  return (
    state.translationCode === target.translationCode &&
    state.book === target.book &&
    state.chapter === target.chapter &&
    state.verse === target.verse
  );
}

function getScrollTop() {
  return window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0;
}

function getLocalDateKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function pickSeededIndex(seed, max) {
  if (!Number.isFinite(max) || max <= 0) {
    return 0;
  }

  let hash = 2166136261;
  for (const char of seed) {
    hash ^= char.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }

  return (hash >>> 0) % max;
}

function parseInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function clampNumber(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function isSameReferencePreview(currentPreview, nextPreview) {
  if (!currentPreview || !nextPreview) {
    return false;
  }

  return (
    currentPreview.sourceBook === nextPreview.sourceBook &&
    currentPreview.sourceChapter === nextPreview.sourceChapter &&
    currentPreview.sourceVerse === nextPreview.sourceVerse &&
    currentPreview.targetBookIndex === nextPreview.targetBookIndex &&
    currentPreview.targetChapter === nextPreview.targetChapter &&
    currentPreview.targetStart === nextPreview.targetStart &&
    currentPreview.targetEnd === nextPreview.targetEnd
  );
}
