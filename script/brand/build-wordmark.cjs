// Regenerate wordmark-{light,dark}.svg and the web <Logo> component from the
// master lockup wordmark-lockup.svg (arrow + "ai&" + pixel "code"), supplied by
// the designer. We only recolor + tighten the viewBox here — the glyphs (incl.
// the pixel "code" face) are baked into the master as vector paths, so they
// render everywhere (incl. GitHub READMEs, which strip @font-face).
//
//   node script/brand/build-wordmark.cjs
//
// Convention: *-light = dark ink (light bg), *-dark = light ink (dark bg).
const fs = require("fs")
const path = require("path")

const DIR = __dirname
const ROOT = path.resolve(DIR, "../..")

// Brand palette (see FORK.md): ink for light/dark backgrounds + accent red.
const INK_LIGHT = "#151517"
const INK_DARK = "#F2F2F2"
const RED = "#C70007"

// The master ships with vertical letterboxing: content spans x[0,2682],
// y[151,569]. We translate it up by 150 so it sits in a conventional
// 0,0-origin viewBox (keeps generate.sh's "0 0 W H" assumptions intact).
const VIEWBOX = "0 0 2682 419"
const SHIFT = "translate(0 -150)"

const master = fs.readFileSync(path.join(DIR, "wordmark-lockup.svg"), "utf8")

// Pull every <path d="…" fill="…"/> and split accent (red) from ink.
const paths = [...master.matchAll(/<path\s+d="([^"]+)"\s+fill="([^"]+)"\s*\/>/g)].map((m) => ({
  d: m[1],
  fill: m[2],
}))
const isRed = (fill) => fill.toLowerCase() === RED.toLowerCase()
const ink = paths.filter((p) => !isRed(p.fill))
const red = paths.filter((p) => isRed(p.fill))
if (!ink.length || !red.length) throw new Error(`unexpected lockup paths: ink=${ink.length} red=${red.length}`)

// --- master SVGs (single flat ink color) ---
function emitMaster(file, inkColor) {
  const body = [
    ...ink.map((p) => `  <path d="${p.d}" fill="${inkColor}"/>`),
    ...red.map((p) => `  <path d="${p.d}" fill="${RED}"/>`),
  ].join("\n")
  const svg = `<svg width="2682" height="419" viewBox="${VIEWBOX}" fill="none" xmlns="http://www.w3.org/2000/svg">
<g transform="${SHIFT}">
${body}
</g>
</svg>
`
  fs.writeFileSync(path.join(DIR, file), svg)
  console.log(`wrote ${file} (viewBox ${VIEWBOX})`)
}
emitMaster("wordmark-light.svg", INK_LIGHT)
emitMaster("wordmark-dark.svg", INK_DARK)

// --- web <Logo>: ink follows theme via --icon-strong-base, accent stays red ---
const logoFile = path.join(ROOT, "packages/ui/src/components/logo.tsx")
const src = fs.readFileSync(logoFile, "utf8")
const marker = "// Full wordmark:"
const head = src.slice(0, src.indexOf(marker))
const inkJsx = ink.map((p) => `          <path d="${p.d}" />`).join("\n")
const redJsx = red.map((p) => `        <path d="${p.d}" fill="${RED}" />`).join("\n")
const logo = `// Full wordmark: arrow + "ai&" + pixel "code" lockup. Ink follows theme; accent stays brand red.
export const Logo = (props: { class?: string }) => {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="${VIEWBOX}"
      fill="none"
      classList={{ [props.class ?? ""]: !!props.class }}
    >
      <g transform="${SHIFT}">
        <g fill="var(--icon-strong-base)">
${inkJsx}
        </g>
${redJsx}
      </g>
    </svg>
  )
}
`
fs.writeFileSync(logoFile, head + logo)
console.log(`rewrote ${path.relative(ROOT, logoFile)} <Logo> (${ink.length} ink + ${red.length} accent paths)`)
