// Generates the HUD heart SVGs procedurally with rough.js.
//
// Two states, same seed so the wobble matches between them:
//   heart_full.svg  -> sketchy red-filled heart  (you have this life)
//   heart_empty.svg -> sketchy grey outline only (you lost this life)
//
// rough.js is a procedural geometry library (NOT generative AI), so these
// assets are jam-legal. Re-run with `npm run build` to regenerate.

const fs = require("fs");
const path = require("path");
const rough = require("roughjs");

const gen = rough.generator();

const SIZE = 64;
// A heart path centred in a 64x64 box (two top lobes + bottom point).
const HEART =
  "M32 56 " +
  "C 12 41, 6 24, 16 16 " +
  "C 24 10, 31 16, 32 23 " +
  "C 33 16, 40 10, 48 16 " +
  "C 58 24, 52 41, 32 56 Z";

// Same seed + roughness for both so the silhouette is identical; only the
// fill changes between full and empty.
const SEED = 42;
const COMMON = { roughness: 1.9, bowing: 1.4, strokeWidth: 2.6, seed: SEED };

function toSvg(drawable) {
  const paths = gen.toPaths(drawable);
  const body = paths
    .map((p) => {
      const fill = p.fill && p.fill !== "none" ? p.fill : "none";
      const stroke = p.stroke && p.stroke !== "none" ? p.stroke : "none";
      const sw = p.strokeWidth || 0;
      return (
        `<path d="${p.d}" fill="${fill}" stroke="${stroke}" ` +
        `stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"/>`
      );
    })
    .join("");
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" ` +
    `viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}">` +
    body +
    `</svg>\n`
  );
}

// Full: dense red hachure fill + a deeper red sketchy outline.
const full = gen.path(HEART, {
  ...COMMON,
  stroke: "#b3161b",
  fill: "#e63b3b",
  fillStyle: "hachure",
  hachureGap: 3.2,
  fillWeight: 2.0,
  hachureAngle: -41,
});

// Empty: just the sketchy grey outline, no fill.
const empty = gen.path(HEART, {
  ...COMMON,
  stroke: "#6b6b73",
  fill: "none",
});

const outDir = path.resolve(__dirname, "../../assets/sprites");
fs.writeFileSync(path.join(outDir, "heart_full.svg"), toSvg(full));
fs.writeFileSync(path.join(outDir, "heart_empty.svg"), toSvg(empty));

console.log("Wrote heart_full.svg and heart_empty.svg to assets/sprites/");
