// Generates the Excalidraw-style title card with rough.js (the same sketchy
// engine Excalidraw uses). Pure geometry, NOT generative AI. `npm run build`.

const fs = require("fs");
const path = require("path");
const rough = require("roughjs");

const gen = rough.generator();
const W = 960;
const H = 360;

function toSvg(drawables) {
  let body = "";
  for (const d of drawables) {
    for (const p of gen.toPaths(d)) {
      const fill = p.fill && p.fill !== "none" ? p.fill : "none";
      const stroke = p.stroke && p.stroke !== "none" ? p.stroke : "none";
      body +=
        `<path d="${p.d}" fill="${fill}" stroke="${stroke}" ` +
        `stroke-width="${p.strokeWidth || 0}" stroke-linecap="round" stroke-linejoin="round"/>`;
    }
  }
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">` +
    body +
    `</svg>\n`
  );
}

const ink = "#1f2233";
const opts = { roughness: 2.0, bowing: 1.6, stroke: ink, strokeWidth: 3, seed: 11 };

const drawables = [
  // Sketchy card frame.
  gen.rectangle(24, 24, W - 48, H - 48, opts),
  // A double-stroke accent on the frame's top-left corner area is implicit in
  // rough.js; add a hand-drawn underline where the title sits.
  gen.line(150, 250, W - 150, 250, { ...opts, strokeWidth: 4, seed: 7 }),
  // A couple of little "awakening" sparks, Excalidraw-style.
  gen.line(W - 120, 70, W - 96, 54, { ...opts, strokeWidth: 2, seed: 3 }),
  gen.line(W - 110, 84, W - 84, 80, { ...opts, strokeWidth: 2, seed: 4 }),
  gen.line(110, 70, 86, 54, { ...opts, strokeWidth: 2, seed: 5 }),
];

fs.writeFileSync(path.resolve(__dirname, "../../assets/sprites/title_card.svg"), toSvg(drawables));
console.log("Wrote title_card.svg to assets/sprites/");
