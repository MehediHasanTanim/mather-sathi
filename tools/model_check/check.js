#!/usr/bin/env node
'use strict';
// Usage: node tools/model_check/check.js [modelsDir]   (default assets/models)
// Run after dropping the handoff files in; also run `node tools/kb_build/build.js --env dev --validate`,
// which checks labels.json against the KB.
const path = require('node:path');
const { checkModelDir } = require('./lib');

const dir = path.resolve(process.argv[2] || path.join(__dirname, '../../assets/models'));
const r = checkModelDir(dir);
if (!r.present) {
  console.log('model_check: no offline model bundled (cloud-only build), nothing to check');
  process.exit(0);
}
if (r.errors.length) {
  console.error(`model_check: ${r.errors.length} problem(s)`);
  r.errors.forEach((e) => console.error(`  ${e}`));
  process.exit(1);
}
console.log(`model_check: ok (${r.meta.version}, ${r.meta.input_size}px ${r.meta.input_type}, ${r.labels.length} labels)`);
