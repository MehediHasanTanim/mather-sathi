'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { validateMeta, validateLabels, checkModelDir } = require('../lib');
const { checkLabelContract } = require('../../kb_build/lib');

const meta = () => ({ version: 'v1', file: 'crop_disease_v1.tflite', input_size: 224, input_type: 'float32', resize: 'bilinear', normalization: 'zero_one', output: 'probabilities', labels: 4 });
const labels = () => [
  { disease_id: 'rice_blast', crop: 'rice' }, { disease_id: 'healthy', crop: 'rice' }, { disease_id: 'unknown', crop: 'rice' },
  { disease_id: 'potato_late_blight', crop: 'potato' },
];
function dir(files) {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'model-'));
  for (const [n, c] of Object.entries(files)) fs.writeFileSync(path.join(d, n), typeof c === 'string' || Buffer.isBuffer(c) ? c : JSON.stringify(c));
  return d;
}

test('a valid meta passes', () => assert.deepStrictEqual(validateMeta(meta()), []));

test('meta: every enum and range is enforced', () => {
  for (const [k, v] of [['input_type', 'int8'], ['resize', 'nearest'], ['normalization', 'foo'], ['output', 'scores'], ['input_size', 8], ['labels', 1], ['file', '../x.tflite'], ['file', 'model.bin'], ['version', '']]) {
    assert.ok(validateMeta({ ...meta(), [k]: v }).length > 0, `${k}=${v}`);
  }
});

test('meta: dtype and normalization must agree', () => {
  assert.ok(validateMeta({ ...meta(), input_type: 'uint8' }).some((e) => /uint8/.test(e)));
  assert.deepStrictEqual(validateMeta({ ...meta(), input_type: 'uint8', normalization: 'none' }), []);
  assert.ok(validateMeta({ ...meta(), normalization: 'none' }).some((e) => /float32/.test(e)));
});

test('labels: shape and duplicates', () => {
  assert.deepStrictEqual(validateLabels(labels()), []);
  assert.ok(validateLabels([]).length);
  assert.ok(validateLabels([{ disease_id: 'a' }]).length);
  assert.ok(validateLabels([...labels(), { disease_id: 'rice_blast', crop: 'rice' }]).some((e) => /duplicates/.test(e)));
});

test('no model files means a cloud-only build, which is fine', () => {
  const r = checkModelDir(dir({ '.gitkeep': '' }));
  assert.deepStrictEqual([r.present, r.errors], [false, []]);
});

test('a complete handoff passes', () => {
  const r = checkModelDir(dir({ 'model_meta.json': meta(), 'labels.json': labels(), 'crop_disease_v1.tflite': Buffer.alloc(100) }));
  assert.deepStrictEqual(r.errors, []);
});

test('each missing or inconsistent piece is reported', () => {
  const noModel = checkModelDir(dir({ 'model_meta.json': meta(), 'labels.json': labels() }));
  assert.ok(noModel.errors.some((e) => /crop_disease_v1.tflite is missing/.test(e)));
  const noMeta = checkModelDir(dir({ 'labels.json': labels() }));
  assert.ok(noMeta.errors.some((e) => /model_meta.json is missing/.test(e)));
  const wrongCount = checkModelDir(dir({ 'model_meta.json': { ...meta(), labels: 5 }, 'labels.json': labels(), 'crop_disease_v1.tflite': Buffer.alloc(1) }));
  assert.ok(wrongCount.errors.some((e) => /4 labels but model_meta.json says 5/.test(e)));
  const broken = checkModelDir(dir({ 'model_meta.json': '{ nope', 'labels.json': labels() }));
  assert.ok(broken.errors.some((e) => /invalid JSON/.test(e)));
});

test('the CLI exits 0 with no model and non-zero for a bad handoff', () => {
  const cli = path.join(__dirname, '../check.js');
  assert.strictEqual(spawnSync('node', [cli, dir({})], { encoding: 'utf8' }).status, 0);
  assert.strictEqual(spawnSync('node', [cli], { encoding: 'utf8' }).status, 0, 'the repo itself ships no model yet');
  const bad = spawnSync('node', [cli, dir({ 'labels.json': labels() })], { encoding: 'utf8' });
  assert.strictEqual(bad.status, 1);
  assert.match(bad.stderr, /model_meta.json is missing/);
});

test('label contract against the KB (plan 6.1): unknown label ids and missing healthy/unknown classes fail', () => {
  const entries = [{ id: 'rice_blast', crop: 'rice' }];
  const ok = [{ disease_id: 'rice_blast', crop: 'rice' }, { disease_id: 'healthy', crop: 'rice' }, { disease_id: 'unknown', crop: 'rice' }];
  assert.deepStrictEqual(checkLabelContract(entries, ok), []);
  assert.ok(checkLabelContract(entries, [...ok, { disease_id: 'rice_ghost', crop: 'rice' }]).some((e) => /no KB entry/.test(e.message)));
  assert.ok(checkLabelContract(entries, ok.filter((l) => l.disease_id !== 'healthy')).some((e) => /no "healthy" class/.test(e.message)));
  assert.ok(checkLabelContract([...entries, { id: 'rice_brown_spot', crop: 'rice' }], ok).some((e) => /no model label/.test(e.message)));
});
