#!/usr/bin/env node
'use strict';
// Usage: node tools/kb_build/build.js [--env dev|stg|prod] [--validate] [--check] [--src DIR] [--meta FILE]
//                                     [--labels FILE] [--kb-out FILE] [--index-out FILE]
//   --validate  validate only, write nothing
//   --check     fail if the committed outputs differ from a fresh build (CI)
const fs = require('node:fs');
const path = require('node:path');
const { build } = require('./lib');

const root = path.join(__dirname, '../..');
const args = process.argv.slice(2);
const flag = (n) => args.includes(`--${n}`);
const opt = (n, d) => { const i = args.indexOf(`--${n}`); return i >= 0 ? args[i + 1] : d; };

const env = opt('env', 'dev');
const srcDir = path.resolve(opt('src', path.join(root, 'kb/src')));
const metaFile = path.resolve(opt('meta', path.join(root, 'kb/meta.json')));
const labelsFile = path.resolve(opt('labels', path.join(root, 'assets/models/labels.json')));
const kbOut = path.resolve(opt('kb-out', path.join(root, 'assets/kb/kb.json')));
const indexOut = path.resolve(opt('index-out', path.join(root, 'functions/src/kb_index.json')));

const meta = JSON.parse(fs.readFileSync(metaFile, 'utf8'));
const labels = fs.existsSync(labelsFile) ? JSON.parse(fs.readFileSync(labelsFile, 'utf8')) : null;
const r = build({ srcDir, meta, env, labels });

if (r.errors.length) {
  console.error(`kb_build: ${r.errors.length} error(s)`);
  for (const e of r.errors) console.error(`  [${e.rule}] ${e.message}`);
  process.exit(1);
}
console.log(`kb_build: env=${env} entries=${r.counts.included}/${r.counts.total} drafts=${r.counts.drafts} seq=${meta.seq} sha256=${r.sha256}`);

if (flag('validate')) process.exit(0);
if (flag('check')) {
  const stale = [[kbOut, r.kbJson], [indexOut, r.indexJson]].filter(([f, c]) => !fs.existsSync(f) || fs.readFileSync(f, 'utf8') !== c);
  if (stale.length) {
    console.error(`kb_build: outputs are out of date, run: node tools/kb_build/build.js --env ${env}\n  ${stale.map(([f]) => path.relative(root, f)).join('\n  ')}`);
    process.exit(1);
  }
  console.log('kb_build: committed outputs are up to date');
  process.exit(0);
}
for (const [f, c] of [[kbOut, r.kbJson], [indexOut, r.indexJson]]) {
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, c);
}
