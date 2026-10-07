#!/usr/bin/env node
// Copies shared data into the Functions source tree (Functions deploy only functions/).
// Usage: node tools/sync_functions_data.js [--check]
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const pairs = [['assets/data/districts.json', 'functions/src/districts.json']];
let stale = false;
for (const [from, to] of pairs) {
  const src = fs.readFileSync(path.join(root, from));
  const dst = path.join(root, to);
  if (process.argv.includes('--check')) {
    if (!fs.existsSync(dst) || !fs.readFileSync(dst).equals(src)) { console.error(`out of date: ${to} (run node tools/sync_functions_data.js)`); stale = true; }
  } else {
    fs.writeFileSync(dst, src);
  }
}
process.exit(stale ? 1 : 0);
