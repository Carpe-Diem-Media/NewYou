const validColor = color => Array.isArray(color) && color.length === 3 &&
  color.every(value => Number.isFinite(value) && value >= 0 && value <= 255)

const luminance = color => color.map(value => {
  const channel = value / 255
  return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
}).reduce((sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index], 0)

export const contrastRatio = (foreground, background) => {
  if (!validColor(foreground) || !validColor(background)) return null
  const values = [luminance(foreground), luminance(background)].sort((a, b) => b - a)
  return (values[0] + 0.05) / (values[1] + 0.05)
}

export const contrastGrade = ratio => {
  if (!Number.isFinite(ratio)) return "Not measured"
  if (ratio >= 7) return "AAA text"
  if (ratio >= 4.5) return "AA text"
  if (ratio >= 3) return "Large text only"
  return "Insufficient text contrast"
}

export const sampleColor = (context, color) => {
  if (!context || typeof color !== "string") return null
  try {
    const sentinels = ["#010203", "#040506"]
    let unchangedForEverySentinel = true
    for (const sentinel of sentinels) {
      context.fillStyle = sentinel
      context.fillStyle = color
      if (context.fillStyle !== sentinel) unchangedForEverySentinel = false
    }
    if (unchangedForEverySentinel) return null
    context.fillStyle = color
    context.clearRect(0, 0, 1, 1)
    context.fillRect(0, 0, 1, 1)
    const [r, g, b, alpha] = context.getImageData(0, 0, 1, 1).data
    return alpha === 255 ? [r, g, b] : null
  } catch {
    return null
  }
}

export const DesignSystem = {
  mounted() {
    const canvas = document.createElement("canvas")
    canvas.width = canvas.height = 1
    this.colorContext = canvas.getContext("2d", {willReadFrequently: true})
    this.schedule = () => {
      cancelAnimationFrame(this.frame)
      this.frame = requestAnimationFrame(() => this.measure())
    }
    this.click = async event => {
      const copy = event.target.closest("[data-copy]")
      if (copy) {
        try {
          await navigator.clipboard.writeText(copy.dataset.copy)
          this.announce(`Copied ${copy.dataset.copy}.`)
        } catch {
          this.announce("Clipboard unavailable. Select the token text to copy it.")
        }
      }
      if (event.target.closest("[data-refresh-tokens]")) {
        this.measure()
        this.announce("Measurements refreshed from CSS.")
      }
      const demo = event.target.closest("[data-demo-action]")
      if (demo) this.announce(`${demo.textContent.trim()} example activated.`)
    }
    this.el.addEventListener("click", this.click)
    window.addEventListener("resize", this.schedule)
    document.addEventListener("load", this.schedule, true)
    this.observer = new MutationObserver(this.schedule)
    this.observer.observe(document.documentElement, {attributes: true, attributeFilter: ["style", "class", "data-theme"]})
    this.resizeObserver = new ResizeObserver(this.schedule)
    this.resizeObserver.observe(this.el)
    this.el.querySelectorAll("[data-copy]").forEach(button => button.disabled = false)
    this.schedule()
  },

  updated() {
    this.el.querySelectorAll("[data-copy]").forEach(button => button.disabled = false)
    this.schedule()
  },

  measure() {
    const root = getComputedStyle(document.documentElement)
    this.el.querySelectorAll("[data-token]").forEach(output => {
      output.textContent = root.getPropertyValue(output.dataset.token).trim() || "Not defined"
    })
    this.el.querySelectorAll("[data-contrast-sample]").forEach(sample => {
      const css = getComputedStyle(sample)
      const ratio = this.colorContext && contrastRatio(
        sampleColor(this.colorContext, css.color),
        sampleColor(this.colorContext, css.backgroundColor)
      )
      const output = sample.parentElement.querySelector("[data-contrast-result]")
      output.textContent = ratio ? `${ratio.toFixed(2)}:1 / ${contrastGrade(ratio)}` : "Not measured: use opaque colors"
    })
    this.el.querySelectorAll("[data-measure-target][data-measure-property]").forEach(output => {
      const target = this.el.querySelector(`#${CSS.escape(output.dataset.measureTarget)}`)
      if (target) output.textContent = getComputedStyle(target).getPropertyValue(output.dataset.measureProperty).trim()
    })
    this.el.querySelectorAll("[data-css-support]").forEach(output => {
      const supports = {
        oklch: CSS.supports("color", "oklch(from red l c h)"),
        "color-mix": CSS.supports("color", "color-mix(in oklch, red, blue)"),
        progress: CSS.supports("width", "calc(progress(1, 0, 2) * 1px)")
      }
      output.textContent = supports[output.dataset.cssSupport] ? "Supported" : "Not supported"
    })
    const readout = this.el.querySelector("[data-viewport-readout]")
    if (readout) readout.textContent = `${window.innerWidth}px viewport`
    const stage = this.el.querySelector("#preview-stage")
    const frame = this.el.querySelector("#design-preview-frame")
    if (stage && frame) {
      const width = frame.offsetWidth
      const scale = Math.min(1, stage.clientWidth / Math.max(1, width))
      stage.style.setProperty("--design-preview-scale", String(scale))
      const output = this.el.querySelector("[data-preview-readout]")
      output.textContent = `${width}px CSS viewport / ${Math.round(scale * 100)}% scale`
    }
  },

  announce(message) {
    const status = this.el.querySelector("#token-status, #preview-status")
    if (status) status.textContent = message
  },

  destroyed() {
    cancelAnimationFrame(this.frame)
    this.observer.disconnect()
    this.resizeObserver.disconnect()
    this.el.removeEventListener("click", this.click)
    window.removeEventListener("resize", this.schedule)
    document.removeEventListener("load", this.schedule, true)
  }
}
