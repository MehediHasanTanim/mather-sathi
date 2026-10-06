'use strict';
// KB validation and compilation (Design §5.3). No dependencies: runs in CI with just Node.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const SCHEMA_VERSION = 1;
const PSEUDO_IDS = ['healthy', 'unknown'];
const ENVS = ['dev', 'stg', 'prod'];

// ---- minimal JSON-schema subset: type, enum, required, properties, items, minItems,
// ---- minLength, minimum, pattern, additionalProperties --------------------------------
function typeOf(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  if (Number.isInteger(v)) return 'integer';
  return typeof v;
}
function typeMatches(v, t) {
  const actual = typeOf(v);
  return actual === t || (t === 'number' && actual === 'integer');
}

function validateSchema(value, schema, at, errors) {
  if (schema.enum && !schema.enum.includes(value)) {
    errors.push(`${at}: must be one of ${JSON.stringify(schema.enum)}`);
    return;
  }
  if (schema.type) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!types.some((t) => typeMatches(value, t))) {
      errors.push(`${at}: expected ${types.join(' or ')}, got ${typeOf(value)}`);
      return;
    }
  }
  if (typeof value === 'string') {
    if (schema.minLength !== undefined && value.length < schema.minLength) errors.push(`${at}: must not be empty`);
    if (schema.pattern && !new RegExp(schema.pattern).test(value)) errors.push(`${at}: does not match ${schema.pattern}`);
  }
  if (typeof value === 'number' && schema.minimum !== undefined && value < schema.minimum) {
    errors.push(`${at}: must be >= ${schema.minimum}`);
  }
  if (Array.isArray(value)) {
    if (schema.minItems !== undefined && value.length < schema.minItems) errors.push(`${at}: needs at least ${schema.minItems} item(s)`);
    if (schema.items) value.forEach((v, i) => validateSchema(v, schema.items, `${at}[${i}]`, errors));
  }
  if (typeOf(value) === 'object') {
    for (const k of schema.required || []) if (!(k in value)) errors.push(`${at}: missing required field "${k}"`);
    const props = schema.properties || {};
    for (const [k, v] of Object.entries(value)) {
      if (props[k]) validateSchema(v, props[k], `${at}.${k}`, errors);
      else if (schema.additionalProperties === false) errors.push(`${at}: unexpected field "${k}"`);
    }
  }
}

// ---- content rules -------------------------------------------------------------------
const hasBangla = (s) => /[ঀ-৿]/.test(s);
const hasPlaceholder = (s) => /<[^<>\n]*>/.test(s);

function bnFields(e) {
  const out = [['name_bn', e.name_bn], ['description_bn', e.description_bn], ['cause_bn', e.cause_bn]];
  for (const k of ['symptoms_bn', 'immediate_bn', 'prevention_bn']) (e[k] || []).forEach((s, i) => out.push([`${k}[${i}]`, s]));
  (e.medicine || []).forEach((m, i) => {
    for (const k of ['name_bn', 'dose_bn', 'interval_bn']) out.push([`medicine[${i}].${k}`, m[k]]);
  });
  return out.filter(([, v]) => typeof v === 'string');
}

function allStrings(e) {
  const out = [];
  (function walk(v, p) {
    if (typeof v === 'string') out.push([p, v]);
    else if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${p}[${i}]`));
    else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) walk(x, p ? `${p}.${k}` : k);
  })(e, '');
  return out;
}

/**
 * Validates entries. Each item is {file, entry}. Returns [{rule, message}].
 * Rules: schema, id-crop-prefix, unique-id, review-metadata, medicine-complete, language, placeholder, label-contract.
 * Review, language and placeholder rules apply to `published` entries only; drafts are for development.
 */
function validateEntries(items, { labels } = {}) {
  const errs = [];
  const add = (rule, file, msg) => errs.push({ rule, message: `${file}: ${msg}` });
  const schema = JSON.parse(fs.readFileSync(path.join(__dirname, '../../kb/schema.json'), 'utf8'));
  const seen = new Map();

  for (const { file, entry: e } of items) {
    const se = [];
    validateSchema(e, schema, 'entry', se);
    se.forEach((m) => add('schema', file, m));
    if (typeOf(e) !== 'object') continue;

    if (typeof e.id === 'string') {
      if (seen.has(e.id)) add('unique-id', file, `duplicate id "${e.id}" (also in ${seen.get(e.id)})`);
      else seen.set(e.id, file);
      if (typeof e.crop === 'string' && !e.id.startsWith(`${e.crop}_`)) add('id-crop-prefix', file, `id "${e.id}" must start with "${e.crop}_"`);
    }
    if (e.status !== 'published') continue;

    for (const k of ['source', 'reviewed_by', 'reviewed_at']) {
      if (typeof e[k] !== 'string' || e[k].trim() === '') add('review-metadata', file, `published entry needs non-empty "${k}"`);
    }
    if (typeof e.reviewed_at === 'string' && e.reviewed_at && !/^\d{4}-\d{2}-\d{2}$/.test(e.reviewed_at)) {
      add('review-metadata', file, '"reviewed_at" must be an ISO date (YYYY-MM-DD)');
    }
    (e.medicine || []).forEach((m, i) => {
      for (const k of ['name_bn', 'dose_bn', 'interval_bn']) {
        if (typeof m[k] !== 'string' || m[k].trim() === '') add('medicine-complete', file, `medicine[${i}] needs non-empty "${k}"`);
      }
      if (!Number.isInteger(m.pre_harvest_interval_days)) add('medicine-complete', file, `medicine[${i}] needs an integer "pre_harvest_interval_days"`);
    });
    for (const [p, v] of bnFields(e)) if (!hasBangla(v)) add('language', file, `${p} must contain Bangla text`);
    for (const [p, v] of allStrings(e)) if (hasPlaceholder(v)) add('placeholder', file, `${p} still contains <placeholder> text`);
  }

  if (labels) errs.push(...checkLabelContract(items.map((i) => i.entry).filter((e) => typeOf(e) === 'object'), labels));
  return errs;
}

/** labels: [{disease_id, crop}] in model-index order (assets/models/labels.json). */
function checkLabelContract(entries, labels) {
  const errs = [];
  const add = (m) => errs.push({ rule: 'label-contract', message: `labels.json: ${m}` });
  const ids = new Set(entries.map((e) => e.id));
  const labelCrops = new Set(labels.map((l) => l.crop));
  for (const l of labels) {
    if (!PSEUDO_IDS.includes(l.disease_id) && !ids.has(l.disease_id)) add(`label "${l.disease_id}" has no KB entry`);
  }
  for (const crop of labelCrops) {
    for (const p of PSEUDO_IDS) {
      if (!labels.some((l) => l.crop === crop && l.disease_id === p)) add(`crop "${crop}" has no "${p}" class`);
    }
  }
  for (const e of entries) {
    if (labelCrops.has(e.crop) && !labels.some((l) => l.disease_id === e.id)) add(`KB entry "${e.id}" has no model label`);
  }
  return errs;
}

// ---- compile -------------------------------------------------------------------------
function stable(v) {
  if (Array.isArray(v)) return v.map(stable);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k, stable(v[k])]));
  return v;
}
const stringify = (v) => `${JSON.stringify(stable(v), null, 2)}\n`;
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

function readEntries(srcDir) {
  return fs.readdirSync(srcDir).filter((f) => f.endsWith('.json')).sort().map((f) => {
    const full = path.join(srcDir, f);
    try {
      return { file: f, entry: JSON.parse(fs.readFileSync(full, 'utf8')) };
    } catch (err) {
      return { file: f, entry: null, parseError: err.message };
    }
  });
}

/**
 * Validates and compiles. env "dev" keeps drafts; "stg"/"prod" exclude them (Design §5.3).
 * Returns {errors, kbJson, indexJson, sha256, counts}. Output is a pure function of its input.
 */
function build({ srcDir, meta, env, labels }) {
  if (!ENVS.includes(env)) throw new Error(`unknown env "${env}" (use ${ENVS.join('|')})`);
  const items = readEntries(srcDir);
  const errors = items.filter((i) => i.parseError).map((i) => ({ rule: 'schema', message: `${i.file}: invalid JSON (${i.parseError})` }));
  const valid = items.filter((i) => !i.parseError);
  errors.push(...validateEntries(valid, { labels: undefined }));

  const included = valid.map((i) => i.entry).filter((e) => e && (env === 'dev' || e.status === 'published'));
  if (labels) errors.push(...checkLabelContract(included, labels));
  included.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));

  const includesDrafts = included.some((e) => e.status !== 'published');
  const kb = { schema: SCHEMA_VERSION, version: meta.version, seq: meta.seq, includes_drafts: includesDrafts, entries: included };
  const index = {
    schema: SCHEMA_VERSION, version: meta.version, seq: meta.seq,
    entries: included.map(({ id, crop, name_en, ai_hint_en }) => ({ id, crop, name_en, ai_hint_en })),
  };
  const kbJson = stringify(kb);
  return {
    errors, kbJson, indexJson: stringify(index), sha256: sha256(kbJson),
    counts: { total: valid.length, included: included.length, drafts: included.filter((e) => e.status !== 'published').length },
  };
}

module.exports = { validateEntries, checkLabelContract, build, stringify, sha256, hasBangla, hasPlaceholder, ENVS, SCHEMA_VERSION };
