const button = document.getElementById("copy-member-reference");
const reference = document.getElementById("member-reference-value");
const status = document.getElementById("member-reference-copy-status");

// Restored pages need fresh Session authority before displaying the reference.
window.addEventListener("pagehide", () => {
  reference.textContent = "";
  button.hidden = true;
  status.textContent = "";
});
window.addEventListener("pageshow", event => {
  if (event.persisted) window.location.reload();
});

button.addEventListener("click", async () => {
  status.textContent = "";
  try {
    await navigator.clipboard.writeText(reference.textContent);
    status.textContent = button.dataset.copied;
  } catch {
    status.textContent = button.dataset.unavailable;
  }
});
button.hidden = false;
