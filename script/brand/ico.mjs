// Build a PNG-embedded .ico from one or more PNG files.
// Usage: node ico.mjs <out.ico> <png1> [png2 ...]
// Each PNG must be square; its width is read from the IHDR chunk.
import { readFileSync, writeFileSync } from "node:fs"

const [out, ...pngs] = process.argv.slice(2)
if (!out || pngs.length === 0) {
  console.error("usage: node ico.mjs <out.ico> <png...>")
  process.exit(1)
}

const images = pngs.map((p) => {
  const data = readFileSync(p)
  // PNG IHDR width is a big-endian uint32 at byte offset 16.
  const width = data.readUInt32BE(16)
  return { data, size: width >= 256 ? 0 : width } // 0 means 256 in ICO
})

const HEADER = 6
const ENTRY = 16
let offset = HEADER + ENTRY * images.length

const header = Buffer.alloc(HEADER)
header.writeUInt16LE(0, 0) // reserved
header.writeUInt16LE(1, 2) // type 1 = icon
header.writeUInt16LE(images.length, 4)

const entries = []
const bodies = []
for (const img of images) {
  const e = Buffer.alloc(ENTRY)
  e.writeUInt8(img.size, 0) // width
  e.writeUInt8(img.size, 1) // height
  e.writeUInt8(0, 2) // palette
  e.writeUInt8(0, 3) // reserved
  e.writeUInt16LE(1, 4) // color planes
  e.writeUInt16LE(32, 6) // bits per pixel
  e.writeUInt32LE(img.data.length, 8) // size of image data
  e.writeUInt32LE(offset, 12) // offset of image data
  offset += img.data.length
  entries.push(e)
  bodies.push(img.data)
}

writeFileSync(out, Buffer.concat([header, ...entries, ...bodies]))
console.log(`wrote ${out} (${images.length} sizes)`)
