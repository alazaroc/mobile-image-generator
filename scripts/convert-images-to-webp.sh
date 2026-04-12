#!/usr/bin/env bash
#
# Converts PNG screenshots to WebP format with optional resizing.
# Reads from images/original, writes to images/converted-to-webp (preserving subfolder structure).
# Requires: cwebp (brew install webp), sips (built-in macOS)
#
# Usage (run from project root):
#   npm run convert
#   ./scripts/convert-images-to-webp.sh
#   ./scripts/convert-images-to-webp.sh -w 800 -q 90
#   ./scripts/convert-images-to-webp.sh --no-resize

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────
WIDTH=600
QUALITY=85
RESIZE=true
SOURCE="original"   # "original" | "generated"
FILES=()

# ── Parse arguments ─────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--width)    WIDTH="$2";    shift 2 ;;
    -q|--quality)  QUALITY="$2";  shift 2 ;;
    --no-resize)   RESIZE=false;  shift ;;
    --source)      SOURCE="$2";   shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--source original|generated] [-w WIDTH] [-q QUALITY] [--no-resize]"
      echo ""
      echo "  --source       Input folder: 'original' (default) or 'generated'"
      echo "  -w, --width    Target width in px (default: 600)"
      echo "  -q, --quality  WebP quality 0-100 (default: 85)"
      echo "  --no-resize    Skip resizing, only convert format"
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'. Use -h for help."
      exit 1
      ;;
  esac
done

# ── Dependency check ────────────────────────────────────────────────
for cmd in cwebp sips; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' not found. Install with: brew install webp"
    exit 1
  fi
done

# ── Resolve paths ───────────────────────────────────────────────────
if [ "$SOURCE" = "generated" ]; then
  INPUT_DIR="images/generated-with-mobile-format"
  OUTPUT_DIR="images/converted-to-webp/generated"
elif [ "$SOURCE" = "original" ]; then
  INPUT_DIR="images/original"
  OUTPUT_DIR="images/converted-to-webp/original"
else
  echo "Error: --source must be 'original' or 'generated'"
  exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: input directory '$INPUT_DIR' not found. Run from project root."
  exit 1
fi

while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "$INPUT_DIR" \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -print0)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No PNG files found in $INPUT_DIR."
  exit 0
fi

# ── Convert ─────────────────────────────────────────────────────────
converted=0
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

for png in "${FILES[@]}"; do
  # Compute relative path from INPUT_DIR and mirror under OUTPUT_DIR
  rel="${png#${INPUT_DIR}/}"
  # Strip any image extension (.png, .jpg, .jpeg) and replace with .webp
  rel_noext="${rel%.*}"
  out_path="${OUTPUT_DIR}/${rel_noext}.webp"
  out_dir=$(dirname "$out_path")
  mkdir -p "$out_dir"

  safe_name=$(echo "$rel" | tr '/' '_')

  if [ "$RESIZE" = true ]; then
    resized="${tmpdir}/${safe_name}.png"
    sips --resampleWidth "$WIDTH" "$png" --out "$resized" &>/dev/null
    cwebp -q "$QUALITY" "$resized" -o "$out_path" &>/dev/null
  else
    cwebp -q "$QUALITY" "$png" -o "$out_path" &>/dev/null
  fi

  png_size=$(stat -f%z "$png" 2>/dev/null || stat -c%s "$png")
  webp_size=$(stat -f%z "$out_path" 2>/dev/null || stat -c%s "$out_path")
  saved=$(( (png_size - webp_size) * 100 / png_size ))

  converted=$((converted + 1))
  echo "✓ ${out_path}  (${saved}% smaller)"
done

echo ""
echo "Done: $converted file(s) converted (width=${WIDTH}px, quality=${QUALITY})"
