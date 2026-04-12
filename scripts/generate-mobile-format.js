const puppeteer = require("puppeteer");
const path = require("path");
const fs = require("fs");

const ROOT = path.join(__dirname, "..");
const ORIGINAL_DIR = path.join(ROOT, "images", "original");
const OUTPUT_DIR = path.join(ROOT, "images", "generated-with-mobile-format");
const IMAGE_EXTS = new Set([".png", ".jpg", ".jpeg"]);

// ── CLI args ─────────────────────────────────────────────────────────
let COLOR = "#4a8c4e";
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i] === "--color" && process.argv[i + 1]) {
    COLOR = process.argv[++i];
  }
}

// ── Captions ─────────────────────────────────────────────────────────
const captionsPath = path.join(ROOT, "captions.json");
const captions = fs.existsSync(captionsPath)
  ? JSON.parse(fs.readFileSync(captionsPath, "utf8"))
  : {};

// ── Helpers ───────────────────────────────────────────────────────────
function findImages(dir, baseDir = dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findImages(full, baseDir));
    } else if (entry.isFile() && IMAGE_EXTS.has(path.extname(entry.name).toLowerCase())) {
      results.push(path.relative(baseDir, full));
    }
  }
  return results.sort();
}

// ── Main ─────────────────────────────────────────────────────────────
(async () => {
  if (!fs.existsSync(ORIGINAL_DIR)) {
    console.error(`Error: input directory not found: ${ORIGINAL_DIR}`);
    process.exit(1);
  }

  const images = findImages(ORIGINAL_DIR);
  if (images.length === 0) {
    console.log("No images found in images/original.");
    process.exit(0);
  }

  console.log(`Generating ${images.length} image(s) with color ${COLOR}...\n`);

  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport({ width: 800, height: 1200, deviceScaleFactor: 3 });

  const htmlPath = `file://${path.join(ROOT, "mockup-playstore.html")}`;

  for (const relPath of images) {
    const imgAbsPath = path.join(ORIGINAL_DIR, relPath);
    // Output always as PNG regardless of input format
    const outRelPath = relPath.replace(/\.(jpg|jpeg)$/i, ".png");
    const outPath = path.join(OUTPUT_DIR, outRelPath);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });

    await page.goto(htmlPath, { waitUntil: "networkidle0" });

    await page.evaluate((color) => {
      document.body.style.background = "transparent";
      document.getElementById("card").style.background = color;
      document.getElementById("custom-input").value = color;
      document.getElementById("color-preview").style.background = color;
      document.querySelector(".phone").style.background = color;
      document.querySelector(".notch").style.background = color;
      window.currentBg = color;
    }, COLOR);

    const ext = path.extname(relPath).toLowerCase();
    const mime = ext === ".png" ? "image/png" : "image/jpeg";
    const imgBase64 = fs.readFileSync(imgAbsPath).toString("base64");
    await page.evaluate(([b64, mimeType]) => {
      const phone = document.querySelector(".phone");
      phone.style.height = "628px";
      document.getElementById("screen").innerHTML =
        `<img src="data:${mimeType};base64,${b64}" alt="screenshot" style="width:100%;height:100%;object-fit:fill;display:block;">`;
    }, [imgBase64, mime]);

    const caption = captions[relPath] ?? "";
    await page.evaluate((text) => {
      const label = document.getElementById("label-text");
      label.innerText = text;
      label.style.borderBottom = "none";
    }, caption);

    await new Promise((r) => setTimeout(r, 300));

    const card = await page.$("#card");
    const box = await card.boundingBox();
    await page.screenshot({
      path: outPath,
      type: "png",
      omitBackground: true,
      clip: { x: box.x, y: box.y, width: box.width, height: box.height },
    });

    const captionLabel = caption ? `"${caption}"` : "(no caption)";
    console.log(`✓ ${relPath}  →  ${captionLabel}`);
  }

  await browser.close();
  console.log(`\nDone! ${images.length} image(s) saved in images/generated-with-mobile-format/`);
})();
