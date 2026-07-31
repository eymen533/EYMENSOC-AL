import { mkdirSync, cpSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { execSync } from "node:child_process";

const root = process.cwd();
const htmlSrc = join(root, "index.single.html");

function ensureDir(p) {
  mkdirSync(p, { recursive: true });
}

let version = String(Date.now());
try {
  version = execSync("git rev-parse --short HEAD", { cwd: root }).toString().trim();
} catch {
  /* ignore */
}
const builtAt = new Date().toISOString();

function writeHtml(dest) {
  let html = readFileSync(htmlSrc, "utf8");
  html = html.replaceAll("__VAKIT_VERSION__", version);
  writeFileSync(dest, html);
}

for (const dir of ["dist", "docs", "dist/fonts", "docs/fonts", "dist/icons", "docs/icons"]) {
  ensureDir(join(root, dir));
}

writeHtml(join(root, "index.html"));
writeHtml(join(root, "dist/index.html"));
writeHtml(join(root, "docs/index.html"));

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

const versionPayload = JSON.stringify({ version, builtAt }, null, 2) + "\n";
writeFileSync(join(root, "docs/version.json"), versionPayload);
writeFileSync(join(root, "dist/version.json"), versionPayload);

writeFileSync(join(root, "docs/.nojekyll"), "");
console.log(`Built dist/ and docs/ version=${version}`);
