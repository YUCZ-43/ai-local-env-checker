const root = document.documentElement;
const toggle = document.querySelector("#theme-toggle");
const storedTheme = window.localStorage.getItem("ai-local-website-theme");

if (storedTheme === "dark") {
  root.dataset.theme = "dark";
  if (toggle) {
    toggle.textContent = "Light preview";
    toggle.setAttribute("aria-pressed", "true");
  }
}

toggle?.addEventListener("click", () => {
  const next = root.dataset.theme === "dark" ? "light" : "dark";
  root.dataset.theme = next;
  window.localStorage.setItem("ai-local-website-theme", next);
  toggle.textContent = next === "dark" ? "Light preview" : "Dark preview";
  toggle.setAttribute("aria-pressed", String(next === "dark"));
});
