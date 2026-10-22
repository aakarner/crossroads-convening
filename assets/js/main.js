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
