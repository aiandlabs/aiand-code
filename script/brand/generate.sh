#!/usr/bin/env bash
# Regenerate all aiand-code brand raster assets from the master SVGs in this dir.
# Requires macOS tools: qlmanage (SVG->PNG), sips (resize/crop), iconutil (.icns), node (.ico).
set -euo pipefail

BRAND="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BRAND/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "brand dir: $BRAND"
echo "repo root: $ROOT"
echo "work dir:  $WORK"

# --- rasterize an SVG to a square PNG of exactly $1 px ---
rasterize() { # svg size out
  local svg="$1" size="$2" out="$3"
  qlmanage -t -s "$size" -o "$WORK" "$svg" >/dev/null 2>&1
  # qlmanage always emits a square thumbnail named <basename>.png
  sips -z "$size" "$size" "$WORK/$(basename "$svg").png" --out "$out" >/dev/null
}

# --- pre-render high-res masters ---
ICON1024="$WORK/icon-1024.png"
rasterize "$BRAND/icon-master.svg" 1024 "$ICON1024"

# wordmark aspect, read from the master viewBox ("0 0 <W> <H>")
WM_VB=$(grep -o 'viewBox="0 0 [0-9.]* [0-9.]*"' "$BRAND/wordmark-light.svg" | head -1)
WM_W=$(echo "$WM_VB" | awk '{print $3}')
WM_H=$(echo "$WM_VB" | awk '{print $4+0}')
# band height when the wordmark is fit to width in a 1200px square box
BAND_H=$(awk "BEGIN{printf \"%d\", 1200*${WM_H}/${WM_W}+0.5}")

# wordmark bands: render square, crop the centered content band (transparent)
make_band() { # svg out
  qlmanage -t -s 1200 -o "$WORK" "$1" >/dev/null 2>&1
  sips -c "$BAND_H" 1200 "$WORK/$(basename "$1").png" --out "$2" >/dev/null
}
WL_BAND="$WORK/wordmark-light-band.png"; make_band "$BRAND/wordmark-light.svg" "$WL_BAND"
WD_BAND="$WORK/wordmark-dark-band.png";  make_band "$BRAND/wordmark-dark.svg"  "$WD_BAND"

icon_at() { sips -z "$1" "$1" "$ICON1024" --out "$2" >/dev/null; }              # square icon at N px
wordmark_at() { # band height dest  -> preserve aspect at given height
  sips --resampleHeight "$2" "$1" --out "$3" >/dev/null
}

# ============================================================
# 1) Web/UI favicon set  (ui/src/assets/favicon, symlinked into web/public)
# ============================================================
FAV="$ROOT/packages/ui/src/assets/favicon"
echo "==> favicon set: $FAV"
cp "$BRAND/icon-master.svg" "$FAV/favicon.svg"
cp "$BRAND/icon-master.svg" "$FAV/favicon-v3.svg"
icon_at 96  "$FAV/favicon-96x96.png"
icon_at 96  "$FAV/favicon-96x96-v3.png"
icon_at 180 "$FAV/apple-touch-icon.png"
icon_at 180 "$FAV/apple-touch-icon-v3.png"
icon_at 192 "$FAV/web-app-manifest-192x192.png"
icon_at 512 "$FAV/web-app-manifest-512x512.png"
# .ico (16/32/48/64)
for s in 16 32 48 64; do icon_at $s "$WORK/ico-$s.png"; done
node "$BRAND/ico.mjs" "$FAV/favicon.ico"    "$WORK/ico-16.png" "$WORK/ico-32.png" "$WORK/ico-48.png" "$WORK/ico-64.png"
cp "$FAV/favicon.ico" "$FAV/favicon-v3.ico"

# ============================================================
# 2) Docs favicons + logos
# ============================================================
echo "==> docs"
cp "$BRAND/icon-master.svg" "$ROOT/packages/docs/favicon.svg"
cp "$BRAND/icon-master.svg" "$ROOT/packages/docs/favicon-v3.svg"
cp "$BRAND/wordmark-light.svg" "$ROOT/packages/docs/logo/light.svg"
cp "$BRAND/wordmark-dark.svg"  "$ROOT/packages/docs/logo/dark.svg"

# ============================================================
# 3) Wordmark SVGs across web / console / stats
#    convention: *-light = dark ink (light bg), *-dark = light ink (dark bg)
# ============================================================
echo "==> wordmark SVGs"
put_light() { cp "$BRAND/wordmark-light.svg" "$1"; }
put_dark()  { cp "$BRAND/wordmark-dark.svg"  "$1"; }
put_mark_light() { cp "$BRAND/mark.svg" "$1"; }      # dark-ink arrow (light bg)
put_mark_dark()  { cp "$BRAND/mark-dark.svg" "$1"; } # light-ink arrow (dark bg)

for f in \
  packages/web/src/assets/logo-light.svg \
  packages/web/src/assets/logo-ornate-light.svg \
  packages/console/app/src/asset/logo-ornate-light.svg \
  packages/console/app/src/asset/logo.svg \
  packages/console/app/src/asset/lander/logo-light.svg \
  packages/console/app/src/asset/lander/opencode-logo-light.svg \
  packages/console/app/src/asset/lander/opencode-wordmark-light.svg \
  packages/console/app/src/asset/lander/wordmark-light.svg \
  packages/console/app/src/asset/brand/opencode-logo-light.svg \
  packages/console/app/src/asset/brand/opencode-wordmark-light.svg \
  packages/console/app/src/asset/brand/opencode-wordmark-simple-light.svg \
  packages/stats/app/src/asset/logo-ornate-light.svg
do [ -e "$ROOT/$f" ] && put_light "$ROOT/$f" || echo "  (skip missing $f)"; done

for f in \
  packages/web/src/assets/logo-dark.svg \
  packages/web/src/assets/logo-ornate-dark.svg \
  packages/console/app/src/asset/logo-ornate-dark.svg \
  packages/console/app/src/asset/lander/logo-dark.svg \
  packages/console/app/src/asset/lander/opencode-logo-dark.svg \
  packages/console/app/src/asset/lander/opencode-wordmark-dark.svg \
  packages/console/app/src/asset/lander/wordmark-dark.svg \
  packages/console/app/src/asset/brand/opencode-logo-dark.svg \
  packages/console/app/src/asset/brand/opencode-wordmark-dark.svg \
  packages/console/app/src/asset/brand/opencode-wordmark-simple-dark.svg \
  packages/stats/app/src/asset/logo-ornate-dark.svg
do [ -e "$ROOT/$f" ] && put_dark "$ROOT/$f" || echo "  (skip missing $f)"; done

# square brand marks
put_mark_light "$ROOT/packages/console/app/src/asset/brand/opencode-logo-light-square.svg"
put_mark_dark  "$ROOT/packages/console/app/src/asset/brand/opencode-logo-dark-square.svg"

# ============================================================
# 4) Console brand-kit PNGs (wordmark rasters + social preview cards)
# ============================================================
echo "==> console brand-kit PNGs"
CB="$ROOT/packages/console/app/src/asset/brand"
for f in opencode-wordmark-light.png opencode-wordmark-simple-light.png; do
  [ -e "$CB/$f" ] && wordmark_at "$WL_BAND" 230 "$CB/$f"; done
for f in opencode-wordmark-dark.png opencode-wordmark-simple-dark.png; do
  [ -e "$CB/$f" ] && wordmark_at "$WD_BAND" 230 "$CB/$f"; done

# social preview cards: dark/light card with centered wordmark, cropped to 16:9
make_card() { # bg-hex wordmark-svg out-w out-h dest
  # qlmanage scales non-square SVGs unpredictably, so render a SQUARE canvas
  # (side = out-w) with the wordmark vertically centered, then crop to out-h.
  local bg="$1" wm="$2" w="$3" h="$4" dest="$5"
  local inner; inner="$(sed -e '1d' -e '$d' "$wm")" # strip outer <svg> / </svg>
  local iw=$(( w * 60 / 100 ))
  local ih; ih=$(awk "BEGIN{printf \"%d\", ${iw}*${WM_H}/${WM_W}+0.5}") # match wordmark aspect
  local ix=$(( (w - iw) / 2 )); local iy=$(( (w - ih) / 2 )) # centered in WxW square
  cat > "$WORK/card.svg" <<EOF
<svg width="$w" height="$w" viewBox="0 0 $w $w" xmlns="http://www.w3.org/2000/svg">
<rect width="$w" height="$w" fill="$bg"/>
<svg x="$ix" y="$iy" width="$iw" height="$ih" viewBox="0 0 ${WM_W} ${WM_H}">$inner</svg>
</svg>
EOF
  qlmanage -t -s "$w" -o "$WORK" "$WORK/card.svg" >/dev/null 2>&1
  sips -z "$w" "$w" "$WORK/card.svg.png" --out "$WORK/card2.png" >/dev/null # force exact square
  sips -c "$h" "$w" "$WORK/card2.png" --out "$dest" >/dev/null # crop centered to 16:9
}
[ -e "$CB/preview-opencode-wordmark-light.png" ]        && make_card "#FFFFFF" "$BRAND/wordmark-light.svg" 2400 1350 "$CB/preview-opencode-wordmark-light.png"
[ -e "$CB/preview-opencode-wordmark-dark.png" ]         && make_card "#151517" "$BRAND/wordmark-dark.svg"  2400 1350 "$CB/preview-opencode-wordmark-dark.png"
[ -e "$CB/preview-opencode-wordmark-simple-light.png" ] && make_card "#FFFFFF" "$BRAND/wordmark-light.svg" 2400 1350 "$CB/preview-opencode-wordmark-simple-light.png"
[ -e "$CB/preview-opencode-wordmark-simple-dark.png" ]  && make_card "#151517" "$BRAND/wordmark-dark.svg"  2400 1350 "$CB/preview-opencode-wordmark-simple-dark.png"

# ============================================================
# 5) Desktop app icons (dev / beta / prod) — every PNG at its current size
# ============================================================
echo "==> desktop icons"
for flavor in dev beta prod; do
  DIR="$ROOT/packages/desktop/icons/$flavor"
  [ -d "$DIR" ] || { echo "  (skip missing flavor $flavor)"; continue; }
  # regenerate every PNG at its existing pixel dimensions
  while IFS= read -r png; do
    w=$(sips -g pixelWidth "$png" | awk '/pixelWidth/{print $2}')
    icon_at "$w" "$png"
  done < <(find "$DIR" -type f -name '*.png')

  # icns from a fresh iconset
  ISET="$WORK/$flavor.iconset"; mkdir -p "$ISET"
  icon_at 16   "$ISET/icon_16x16.png";      icon_at 32   "$ISET/icon_16x16@2x.png"
  icon_at 32   "$ISET/icon_32x32.png";      icon_at 64   "$ISET/icon_32x32@2x.png"
  icon_at 128  "$ISET/icon_128x128.png";    icon_at 256  "$ISET/icon_128x128@2x.png"
  icon_at 256  "$ISET/icon_256x256.png";    icon_at 512  "$ISET/icon_256x256@2x.png"
  icon_at 512  "$ISET/icon_512x512.png";    cp "$ICON1024" "$ISET/icon_512x512@2x.png"
  [ -e "$DIR/icon.icns" ] && iconutil -c icns "$ISET" -o "$DIR/icon.icns"

  # ico
  if [ -e "$DIR/icon.ico" ]; then
    for s in 16 32 48 64 128 256; do icon_at $s "$WORK/d-$s.png"; done
    node "$BRAND/ico.mjs" "$DIR/icon.ico" "$WORK/d-16.png" "$WORK/d-32.png" "$WORK/d-48.png" "$WORK/d-64.png" "$WORK/d-128.png" "$WORK/d-256.png"
  fi
done

echo "done."
