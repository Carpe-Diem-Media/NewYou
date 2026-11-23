const form = document.getElementById("support-lookup");
const diagnostics = document.getElementById("support-diagnostics");

function clearLookup() {
  form.reset();
  diagnostics?.replaceChildren();
  diagnostics?.remove();
}

window.addEventListener("pagehide", clearLookup);
window.addEventListener("pageshow", event => {
  if (!event.persisted) return;

  clearLookup();
  // A restored result may be the response to a POST. Navigate to the
  // form's fixed URL as a GET so the server rechecks the current Session.
  window.location.replace(form.action);
});
