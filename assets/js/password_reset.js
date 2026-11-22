// Native navigation submits the form. Presentation changes grant no authority.
document.querySelectorAll("form[data-reset-form], form[data-session-revoke-form]").forEach(form => {
  form.addEventListener("submit", () => {
    const button = form.querySelector('button[type="submit"]');
    if (button) {
      button.disabled = true;
      button.textContent = form.dataset.processing;
    }
    form.setAttribute("aria-busy", "true");
  });
});
