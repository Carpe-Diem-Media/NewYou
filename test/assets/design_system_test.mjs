import assert from "node:assert/strict"
import {test} from "node:test"
import {contrastRatio, contrastGrade} from "../../assets/js/design_system.js"

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
