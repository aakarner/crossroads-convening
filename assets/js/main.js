// Mobile menu toggle
const toggle = document.querySelector(".menu-toggle");
const nav = document.getElementById("site-nav");

toggle.addEventListener("click", () => {
  const open = nav.classList.toggle("is-open");
  toggle.setAttribute("aria-expanded", String(open));
});

nav.addEventListener("click", (e) => {
  if (e.target.closest("a")) {
    nav.classList.remove("is-open");
    toggle.setAttribute("aria-expanded", "false");
  }
});

// Proceedings: print button
document.querySelectorAll("[data-print]").forEach((btn) => {
  btn.addEventListener("click", () => window.print());
});

// Proceedings: collapse the contents on small screens, and highlight the section being read
const toc = document.querySelector(".toc");
if (toc) {
  const details = toc.querySelector("details");
  const narrow = window.matchMedia("(max-width: 900px)");
  if (narrow.matches) details.open = false;
  toc.addEventListener("click", (e) => {
    if (e.target.closest("a") && narrow.matches) details.open = false;
  });

  const links = new Map();
  toc.querySelectorAll("a[href^='#']").forEach((a) => links.set(a.getAttribute("href").slice(1), a));
  const headings = [...links.keys()].map((id) => document.getElementById(id)).filter(Boolean);

  const setActive = () => {
    let current = headings[0];
    for (const h of headings) {
      if (h.getBoundingClientRect().top < 140) current = h;
      else break;
    }
    toc.querySelectorAll(".is-active").forEach((el) => el.classList.remove("is-active"));
    const stop = links.get(current.id)?.closest(".toc__stop");
    stop?.classList.add("is-active");
    stop?.parentElement.closest(".toc__stop")?.classList.add("is-active");

    // keep the highlighted stop in view when the contents list is taller than the screen
    if (stop && !narrow.matches && toc.scrollHeight > toc.clientHeight) {
      const offset = stop.getBoundingClientRect().top - toc.getBoundingClientRect().top;
      if (offset < 40 || offset > toc.clientHeight - 80) toc.scrollTop += offset - toc.clientHeight / 3;
    }
  };
  setActive();
  window.addEventListener("scroll", setActive, { passive: true });
}

// Photo gallery: open photos full size in a viewer, with arrow keys to move between them
const lightbox = document.querySelector(".lightbox");
if (lightbox) {
  const items = [...document.querySelectorAll(".gallery__item a")];
  const img = lightbox.querySelector(".lightbox__img");
  const caption = lightbox.querySelector(".lightbox__caption");
  let index = 0;

  const show = (i) => {
    index = (i + items.length) % items.length;
    const thumb = items[index].querySelector("img");
    img.src = items[index].href;
    img.alt = thumb.alt;
    caption.textContent = `${thumb.alt} (${index + 1} of ${items.length})`;
  };

  items.forEach((a, i) => {
    a.addEventListener("click", (e) => {
      e.preventDefault();
      show(i);
      lightbox.showModal();
    });
  });
  lightbox.querySelector(".lightbox__btn--prev").addEventListener("click", () => show(index - 1));
  lightbox.querySelector(".lightbox__btn--next").addEventListener("click", () => show(index + 1));
  lightbox.querySelector(".lightbox__btn--close").addEventListener("click", () => lightbox.close());
  lightbox.addEventListener("click", (e) => { if (e.target === lightbox) lightbox.close(); });
  lightbox.addEventListener("keydown", (e) => {
    if (e.key === "ArrowLeft") show(index - 1);
    if (e.key === "ArrowRight") show(index + 1);
  });
}

// Load YouTube players only when clicked (keeps the page fast and avoids tracking until then)
document.querySelectorAll(".yt").forEach((el) => {
  el.querySelector(".yt__link").addEventListener("click", (e) => {
    e.preventDefault();
    const iframe = document.createElement("iframe");
    iframe.src = `https://www.youtube-nocookie.com/embed/${el.dataset.id}?autoplay=1`;
    iframe.title = el.dataset.title;
    iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
    iframe.allowFullscreen = true;
    el.replaceChildren(iframe);
  });
});
