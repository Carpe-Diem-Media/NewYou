import assert from "node:assert/strict"
import {test} from "node:test"
import {contrastRatio, contrastGrade, sampleColor} from "../../assets/js/design_system.js"

test("contrast measures equal colors, black/white and a known brand pair", () => {
  assert.equal(contrastRatio([0, 0, 0], [255, 255, 255]), 21)
  assert.equal(contrastRatio([44, 44, 44], [44, 44, 44]), 1)
  assert.ok(contrastRatio([255, 255, 255], [0, 97, 239]) >= 4.5)
  assert.equal(contrastGrade(7), "AAA text")
  assert.equal(contrastGrade(4.5), "AA text")
  assert.equal(contrastGrade(3), "Large text only")
  assert.equal(contrastGrade(2.99), "Insufficient text contrast")
})

test("contrast rejects invalid and out-of-range measurements", () => {
  for (const value of [[], [0, 0], [0, 0, -1], [256, 0, 0], [NaN, 0, 0], "white", null]) {
    assert.equal(contrastRatio(value, [255, 255, 255]), null)
  }
  assert.equal(contrastGrade(null), "Not measured")
})


test("canvas sampling rejects invalid assignments instead of reusing the prior fill", () => {
  let fillStyle = "#fff"
  const context = {
    clearRect() {},
    set fillStyle(value) { if (value !== "invalid") fillStyle = value },
    get fillStyle() { return fillStyle },
    fillRect() {},
    getImageData() { return {data: [255, 255, 255, 255]} }
  }

  assert.deepEqual(sampleColor(context, "#fff"), [255, 255, 255])
  assert.deepEqual(sampleColor(context, "#fff"), [255, 255, 255], "repeated valid colors remain measurable")
  assert.deepEqual(sampleColor(context, "rgb(255, 255, 255)"), [255, 255, 255], "equivalent valid syntax remains measurable")
  assert.equal(sampleColor(context, "invalid"), null)
})

test("canvas sampling rejects transparent colors and unavailable contexts", () => {
  const context = {
    fillStyle: "",
    clearRect() {},
    fillRect() {},
    getImageData() { return {data: [10, 20, 30, 128]} }
  }

  assert.equal(sampleColor(context, "rgba(10, 20, 30, .5)"), null)
  assert.equal(sampleColor(null, "#fff"), null)
})
