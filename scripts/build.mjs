import { mkdirSync, cpSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const html = join(root, "index.single.html");

function ensureDir(p) {
  mkdirSync(p, { recursive: true });
}

function copyHtml(dest) {
  cpSync(html, dest);
}

for (const dir of ["dist", "docs", "dist/fonts", "docs/fonts", "dist/icons", "docs/icons"]) {
  ensureDir(join(root, dir));
}

copyHtml(join(root, "index.html"));
copyHtml(join(root, "dist/index.html"));
copyHtml(join(root, "docs/index.html"));

cpSync(join(root, "public/fonts"), join(root, "dist/fonts"), { recursive: true });
cpSync(join(root, "public/fonts"), join(root, "docs/fonts"), { recursive: true });

cpSync(join(root, "public/icons"), join(root, "dist/icons"), { recursive: true });
cpSync(join(root, "public/icons"), join(root, "docs/icons"), { recursive: true });

for (const file of ["manifest.webmanifest", "sw.js"]) {
  const src = join(root, "public", file);
  if (existsSync(src)) {
    cpSync(src, join(root, "dist", file));
    cpSync(src, join(root, "docs", file));
  }
}

if (existsSync(join(root, "widget"))) {
  cpSync(join(root, "widget"), join(root, "docs/widget"), { recursive: true });
  cpSync(join(root, "widget"), join(root, "dist/widget"), { recursive: true });
}
if (existsSync(join(root, "IPHONE.md"))) {
  cpSync(join(root, "IPHONE.md"), join(root, "docs/IPHONE.md"));
  cpSync(join(root, "IPHONE.md"), join(root, "dist/IPHONE.md"));
}

writeFileSync(join(root, "docs/.nojekyll"), "");
console.log("Built dist/ and docs/");
