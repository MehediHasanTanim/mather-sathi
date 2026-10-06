'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const { validateEntries, checkLabelContract, build } = require('../lib');

const BUILD = path.join(__dirname, '../build.js');
const good = () => ({
  id: 'rice_blast', crop: 'rice', status: 'published',
  name_bn: 'ধানের ব্লাস্ট রোগ', name_en: 'Rice blast', ai_hint_en: 'Eye-shaped lesions.',
  description_bn: 'একটি ছত্রাকজনিত রোগ।', symptoms_bn: ['পাতায় দাগ'], cause_bn: 'ছত্রাক।',
  urgency: 'high', immediate_bn: ['সার বন্ধ রাখুন'],
  medicine: [{ name_bn: 'পরীক্ষামূলক নাম', active_ingredient: 'x', dose_bn: '১ গ্রাম', interval_bn: '৭ দিন', pre_harvest_interval_days: 7 }],
  prevention_bn: ['সুষম সার দিন'], see_expert: false,
  source: 'TEST SOURCE', reviewed_by: 'Tester', reviewed_at: '2026-01-01',
});
const run = (entry, opts) => validateEntries([{ file: 'x.json', entry }], opts);
const rules = (errs) => errs.map((e) => e.rule);
const withEntry = (mut) => { const e = good(); mut(e); return e; };

test('a fully valid published entry passes', () => assert.deepStrictEqual(run(good()), []));

// ---- one failing fixture per Design §5.3 rule ----
test('rule: schema (missing field, bad enum, extra field, wrong type)', () => {
  assert.ok(rules(run(withEntry((e) => delete e.name_bn))).includes('schema'));
  assert.ok(rules(run(withEntry((e) => { e.urgency = 'extreme'; }))).includes('schema'));
  assert.ok(rules(run(withEntry((e) => { e.surprise = 1; }))).includes('schema'));
  assert.ok(rules(run(withEntry((e) => { e.see_expert = 'no'; }))).includes('schema'));
  assert.ok(rules(run(withEntry((e) => { e.id = 'unknown'; }))).includes('schema'), 'reserved id');
});

test('rule: unique ids', () => {
  const errs = validateEntries([{ file: 'a.json', entry: good() }, { file: 'b.json', entry: good() }]);
  assert.ok(rules(errs).includes('unique-id'));
});

test('rule: id must start with its crop', () => {
  assert.ok(rules(run(withEntry((e) => { e.id = 'potato_blast'; }))).includes('id-crop-prefix'));
});

test('rule: review metadata required on published entries', () => {
  for (const k of ['source', 'reviewed_by', 'reviewed_at']) {
    assert.ok(rules(run(withEntry((e) => { e[k] = ' '; }))).includes('review-metadata'), k);
  }
  assert.ok(rules(run(withEntry((e) => { e.reviewed_at = 'yesterday'; }))).includes('review-metadata'));
});

test('rule: medicine completeness', () => {
  for (const k of ['name_bn', 'dose_bn', 'interval_bn']) {
    assert.ok(rules(run(withEntry((e) => { e.medicine[0][k] = ''; }))).includes('medicine-complete'), k);
  }
  assert.ok(rules(run(withEntry((e) => { e.medicine[0].pre_harvest_interval_days = null; }))).includes('medicine-complete'));
});

test('rule: Bangla fields must contain Bangla', () => {
  assert.ok(rules(run(withEntry((e) => { e.description_bn = 'English only'; }))).includes('language'));
  assert.ok(rules(run(withEntry((e) => { e.medicine[0].dose_bn = '1 gram'; }))).includes('language'));
  assert.ok(rules(run(withEntry((e) => { e.symptoms_bn = ['plain']; }))).includes('language'));
});

test('rule: no leftover <placeholder> text in published entries', () => {
  assert.ok(rules(run(withEntry((e) => { e.cause_bn = 'ছত্রাক <verified>'; }))).includes('placeholder'));
  assert.ok(rules(run(withEntry((e) => { e.medicine[0].active_ingredient = '<verified>'; }))).includes('placeholder'));
});

test('drafts may keep placeholders and skip review metadata', () => {
  const draft = withEntry((e) => {
    e.status = 'draft'; e.source = ''; e.reviewed_by = ''; e.reviewed_at = '';
    e.medicine = [{ name_bn: '<অনুমোদিত নাম>', active_ingredient: '<verified>', dose_bn: '<verified dose>', interval_bn: '<verified interval>', pre_harvest_interval_days: null }];
  });
  assert.deepStrictEqual(run(draft), []);
});

test('rule: label contract (labels.json vs KB)', () => {
  const labels = [
    { disease_id: 'rice_blast', crop: 'rice' }, { disease_id: 'healthy', crop: 'rice' }, { disease_id: 'unknown', crop: 'rice' },
  ];
  assert.deepStrictEqual(run(good(), { labels }), []);

  const missingEntry = [...labels, { disease_id: 'rice_ghost', crop: 'rice' }];
  assert.ok(rules(run(good(), { labels: missingEntry })).includes('label-contract'));

  const noHealthy = labels.filter((l) => l.disease_id !== 'healthy');
  assert.match(checkLabelContract([good()], noHealthy)[0].message, /no "healthy" class/);

  const unlabeled = withEntry((e) => { e.id = 'rice_brown_spot'; });
  const errs = validateEntries([{ file: 'a.json', entry: good() }, { file: 'b.json', entry: unlabeled }], { labels });
  assert.match(errs.find((e) => e.rule === 'label-contract').message, /"rice_brown_spot" has no model label/);

  const otherCropOnly = withEntry((e) => { e.id = 'potato_late_blight'; e.crop = 'potato'; });
  assert.deepStrictEqual(validateEntries([{ file: 'a.json', entry: otherCropOnly }], { labels: [] }), [], 'crops absent from labels are not required');
});

// ---- build: determinism, env handling, CLI ----
function tmpSrc(entries) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kb-'));
  for (const e of entries) fs.writeFileSync(path.join(dir, `${e.id}.json`), JSON.stringify(e));
  return dir;
}
const meta = { version: '1.0.0', seq: 3 };

test('identical input gives an identical SHA-256, regardless of key or file order', () => {
  const a = good(); const b = { ...good(), id: 'rice_brown_spot' };
  const reordered = Object.fromEntries(Object.entries(b).reverse());
  const r1 = build({ srcDir: tmpSrc([a, b]), meta, env: 'prod' });
  const r2 = build({ srcDir: tmpSrc([a, reordered]), meta, env: 'prod' });
  assert.deepStrictEqual(r1.errors, []);
  assert.strictEqual(r1.sha256, r2.sha256);
  assert.strictEqual(r1.kbJson, r2.kbJson);
  assert.notStrictEqual(r1.sha256, build({ srcDir: tmpSrc([a, b]), meta: { ...meta, seq: 4 }, env: 'prod' }).sha256);
});

test('drafts are included in dev and excluded from stg/prod', () => {
  const draft = { ...good(), id: 'rice_brown_spot', status: 'draft', source: '', reviewed_by: '', reviewed_at: '' };
  const src = tmpSrc([good(), draft]);
  const dev = build({ srcDir: src, meta, env: 'dev' });
  assert.strictEqual(dev.counts.included, 2);
  assert.strictEqual(JSON.parse(dev.kbJson).includes_drafts, true);
  for (const env of ['stg', 'prod']) {
    const r = build({ srcDir: src, meta, env });
    assert.deepStrictEqual(JSON.parse(r.kbJson).entries.map((e) => e.id), ['rice_blast']);
    assert.deepStrictEqual(JSON.parse(r.indexJson).entries.map((e) => e.id), ['rice_blast']);
    assert.strictEqual(JSON.parse(r.kbJson).includes_drafts, false);
  }
});

test('the real repo seed KB ships no drafts to stg or prod (CI check)', () => {
  for (const env of ['stg', 'prod']) {
    const out = execFileSync('node', [BUILD, '--env', env, '--validate'], { encoding: 'utf8' });
    assert.match(out, /drafts=0/, env);
  }
});

test('the committed kb.json and kb_index.json are up to date for dev', () => {
  execFileSync('node', [BUILD, '--env', 'dev', '--check'], { encoding: 'utf8' });
});

test('CLI exits non-zero and names the rule for a bad entry', () => {
  const bad = withEntry((e) => { e.medicine[0].dose_bn = ''; });
  const dir = tmpSrc([bad]);
  const metaFile = path.join(dir, '..', `meta-${path.basename(dir)}.json`);
  fs.writeFileSync(metaFile, JSON.stringify(meta));
  const r = spawnSync('node', [BUILD, '--env', 'prod', '--validate', '--src', dir, '--meta', metaFile], { encoding: 'utf8' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stderr, /\[medicine-complete\]/);
});

test('invalid JSON is reported as a schema error', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kb-'));
  fs.writeFileSync(path.join(dir, 'broken.json'), '{ nope');
  const r = build({ srcDir: dir, meta, env: 'dev' });
  assert.match(r.errors[0].message, /invalid JSON/);
});
