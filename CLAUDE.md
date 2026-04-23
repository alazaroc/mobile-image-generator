# CLAUDE.md

## Approach

- Think before acting. Read existing files before writing code.
- Prefer editing over rewriting whole files.
- Test your code before declaring done.
- No sycophantic openers or closing fluff.
- User instructions always override this file.

## Project

Generates Play Store marketing screenshots: wraps app screenshots in a phone mockup frame (Puppeteer → HTML template) with background color and caption text.

## Commands

```bash
npm run generate                    # Discover all images in images/original/, render with mockup
npm run generate -- --color "#hex"  # Override background color
npm run convert:original            # images/original/ → images/converted-to-webp/
npm run convert:generated           # images/generated-with-mobile-format/ → images/converted-to-webp/
npm run convert:original -- -w 800 -q 90   # custom width/quality
npm run convert:original -- --no-resize    # format only, no resize
npm run all                         # generate + convert:generated in sequence
```

No test/lint commands.

## Key files

- `captions.json` — map of `"relative/path.png": "caption text"` (relative to `images/original/`)
- `scripts/generate-mobile-format.js` — discovers all PNG/JPG under `images/original/` recursively, renders each via Puppeteer, saves to `images/generated-with-mobile-format/` (same structure). `COLOR` default = `#4a8c4e`, overridable via `--color`.
- `scripts/convert-images-to-webp.sh` — reads `images/original/` or `images/generated-with-mobile-format/` (via `--source original|generated`), outputs WebP to `images/converted-to-webp/original/` or `images/converted-to-webp/generated/` respectively.
- `mockup.html` — phone frame template. Used by Puppeteer AND works standalone in browser for manual generation.

## Pipeline

`images/original/**` → `npm run generate` → `images/generated-with-mobile-format/**` → `npm run convert:generated` → `images/converted-to-webp/generated/**`

## .gitignore behavior

`images/original/**` is ignored except `images/original/example/` (kept as demo). Output dirs (`generated-with-mobile-format/`, `converted-to-webp/`) are ignored.

## To add screenshots

1. Drop PNG/JPG anywhere under `images/original/`
2. Add caption to `captions.json` if needed (omit = no caption text)
3. Run `npm run all`
