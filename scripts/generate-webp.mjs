/**
 * Converts large public-folder images to WebP at build time.
 * Skips gracefully if sharp is not installed — the build continues with PNG fallbacks.
 * Run: node scripts/generate-webp.mjs
 */
import { existsSync } from "fs";
import { stat } from "fs/promises";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const publicDir = resolve(__dirname, "../public");

const conversions = [
  // Hero image: resize to max 1400 px wide + aggressive WebP compression
  {
    input: "somalia-coast.png",
    output: "somalia-coast.webp",
    quality: 78,
    resize: { width: 1400, withoutEnlargement: true },
  },
  // Logo: keep dimensions, convert to WebP (no spaces in output name)
  {
    input: "logo rajo ai.png",
    output: "logo-rajo-ai.webp",
    quality: 85,
    resize: null,
  },
];

// Load sharp conditionally — non-fatal if missing
let sharp;
try {
  ({ default: sharp } = await import("sharp"));
} catch {
  console.warn("[webp] sharp not installed — skipping WebP generation.");
  console.warn("[webp] To enable: npm install --save-dev sharp");
  process.exit(0);
}

let converted = 0;
for (const { input, output, quality, resize } of conversions) {
  const inputPath = resolve(publicDir, input);
  const outputPath = resolve(publicDir, output);

  if (!existsSync(inputPath)) {
    console.warn(`[webp] skipping "${input}" — file not found`);
    continue;
  }

  // Skip regeneration if output already exists and is newer than input
  if (existsSync(outputPath)) {
    const [inStat, outStat] = await Promise.all([stat(inputPath), stat(outputPath)]);
    if (outStat.mtimeMs >= inStat.mtimeMs) {
      console.log(`[webp] "${output}" is up-to-date`);
      continue;
    }
  }

  try {
    let pipeline = sharp(inputPath);
    if (resize) pipeline = pipeline.resize(resize);
    await pipeline.webp({ quality }).toFile(outputPath);
    console.log(`[webp] ✓ "${input}" → "${output}"`);
    converted++;
  } catch (err) {
    console.error(`[webp] ✗ "${input}": ${err.message}`);
  }
}

if (converted > 0) console.log(`[webp] generated ${converted} WebP file(s)`);
process.exit(0);
