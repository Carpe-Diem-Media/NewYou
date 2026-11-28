const surface = document.getElementById("reconciliation");
const status = document.getElementById("reconciliation-request-status");
let pending;

function enableForms() {
  surface.querySelectorAll("[data-operator-fields]").forEach(fields => { fields.disabled = false; });
}

function clearPage() {
  pending?.abort();
  surface.replaceChildren();
}

function reopen() {
  clearPage();
  window.location.replace(window.location.pathname);
}

enableForms();
surface.addEventListener("click", event => {
  if (event.target.closest("[data-operator-reset]")) reopen();
});

surface.addEventListener("submit", async event => {
  event.preventDefault();
  if (pending || !event.submitter) return;

  const form = event.target;
  const body = new URLSearchParams(new FormData(form, event.submitter));
  const fields = form.querySelector("[data-operator-fields]");
  const request = new AbortController();
  pending = request;
  fields.disabled = true;
  surface.setAttribute("aria-busy", "true");
  status.textContent = "Checking current authority…";
  form.querySelectorAll('input:not([type="hidden"])').forEach(input => { input.value = ""; });

  try {
    const response = await fetch(form.action, {
      method: "POST",
      headers: {"x-newyou-operator-request": "1"},
      cache: "no-store",
      redirect: "error",
      body,
      signal: request.signal
    });
    if (response.status === 404) return reopen();

    const doc = new DOMParser().parseFromString(await response.text(), "text/html");
    const result = doc.getElementById("reconciliation-result");
    if (!result) throw new Error("Missing reconciliation result");
    surface.querySelector("#reconciliation-result").replaceWith(result);
    enableForms();
    result.focus();
    status.textContent = "";
  } catch {
    if (!request.signal.aborted) {
      status.textContent = "Result unavailable. Reopen the case to check its current status.";
      fields.disabled = false;
      form.querySelector("button[type=submit]")?.focus();
    }
  } finally {
    pending = undefined;
    surface.removeAttribute("aria-busy");
  }
});

window.addEventListener("pagehide", clearPage);
window.addEventListener("pageshow", event => {
  if (event.persisted) reopen();
});
