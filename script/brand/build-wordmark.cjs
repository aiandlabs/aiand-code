// Regenerate wordmark-{light,dark}.svg from wordmark-base.svg (arrow + "ai&")
// by appending "code" set in Geist SemiBold, converted to vector paths so it
// renders everywhere (incl. GitHub READMEs, which strip @font-face).
//
//   npm i opentype.js && node script/brand/build-wordmark.cjs
//
// The existing "ai&" logotype is heavier than Geist Regular; SemiBold matches.
const ot = require("opentype.js")
const fs = require("fs")
const path = require("path")

const DIR = __dirname
const font = (() => {
  const b = fs.readFileSync(path.join(DIR, "Geist-SemiBold.ttf"))
  return ot.parse(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength))
})()

// Match the logotype: baseline y=23.84, x-height=17 (measured from the "i" body).
const BASELINE = 23.84
const XHEIGHT = 17.0
const fontSize = XHEIGHT / (font.tables.os2.sxHeight / font.unitsPerEm)
const START_X = 72.8 // just after the "&" (logotype right edge ~72)

const codePath = font.getPath("code", START_X, BASELINE, fontSize)
const codeD = codePath.toPathData(3)
const right = Math.ceil(codePath.getBoundingBox().x2 + 3)

const base = fs.readFileSync(path.join(DIR, "wordmark-base.svg"), "utf8")
const innerPaths = base.split("\n").filter((l) => l.includes("<path")).join("\n")

function emit(file, ink) {
  const paths = innerPaths.replace(/#151517/g, ink)
  const svg = `<svg width="${right}" height="24" viewBox="0 0 ${right} 24" fill="none" xmlns="http://www.w3.org/2000/svg">
${paths}
<path d="${codeD}" fill="${ink}"/>
</svg>
`
  fs.writeFileSync(path.join(DIR, file), svg)
  console.log(`wrote ${file} (viewBox 0 0 ${right} 24)`)
}

emit("wordmark-light.svg", "#151517")
emit("wordmark-dark.svg", "#F2F2F2")
