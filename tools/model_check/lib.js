'use strict';
// Validates the offline-model handoff files (docs/model-handoff.md). Mirrors lib/features/offline/model_contract.dart.
const fs = require('node:fs');
const path = require('node:path');

const ENUMS = {
  input_type: ['float32', 'uint8'],
  resize: ['area', 'bilinear'],
  normalization: ['zero_one', 'minus_one_one', 'imagenet', 'none'],
  output: ['probabilities', 'logits'],
};

function validateMeta(meta) {
  const errs = [];
  if (!meta || typeof meta !== 'object') return ['model_meta.json must be an object'];
  for (const [k, allowed] of Object.entries(ENUMS)) {
    if (!allowed.includes(meta[k])) errs.push(`${k} must be one of ${allowed.join('|')}, got ${JSON.stringify(meta[k])}`);
  }
  if (typeof meta.version !== 'string' || !meta.version) errs.push('version must be a non-empty string');
  if (typeof meta.file !== 'string' || !/^[A-Za-z0-9_.-]+\.tflite$/.test(meta.file)) errs.push('file must be a plain *.tflite file name');
  if (!Number.isInteger(meta.input_size) || meta.input_size < 32 || meta.input_size > 1024) errs.push('input_size must be an integer in 32..1024');
  if (!Number.isInteger(meta.labels) || meta.labels < 2) errs.push('labels must be an integer >= 2');
  if (meta.input_type === 'uint8' && meta.normalization !== 'none') errs.push('a uint8 input needs normalization "none"');
  if (meta.input_type === 'float32' && meta.normalization === 'none') errs.push('a float32 input needs a normalization');
  return errs;
}

function validateLabels(labels) {
  if (!Array.isArray(labels) || labels.length === 0) return ['labels.json must be a non-empty array'];
  const errs = [];
  const seen = new Set();
  labels.forEach((l, i) => {
    if (!l || typeof l.disease_id !== 'string' || typeof l.crop !== 'string' || !l.disease_id || !l.crop) {
      errs.push(`labels[${i}] needs string "disease_id" and "crop"`);
      return;
    }
    // disease ids are unique across the whole file (healthy/unknown repeat per crop, so key on crop + id)
    const key = `${l.crop}/${l.disease_id}`;
    if (seen.has(key)) errs.push(`labels[${i}] duplicates ${key}`);
    seen.add(key);
  });
  return errs;
}

/** Checks the files in `modelsDir`. No model bundled is fine (cloud-only build): returns {present:false, errors:[]}. */
function checkModelDir(modelsDir) {
  const metaFile = path.join(modelsDir, 'model_meta.json');
  const labelsFile = path.join(modelsDir, 'labels.json');
  const anyPresent = [metaFile, labelsFile].some((f) => fs.existsSync(f)) ||
    (fs.existsSync(modelsDir) && fs.readdirSync(modelsDir).some((f) => f.endsWith('.tflite')));
  if (!anyPresent) return { present: false, errors: [] };

  const errors = [];
  let meta = null, labels = null;
  for (const [file, set] of [[metaFile, (v) => (meta = v)], [labelsFile, (v) => (labels = v)]]) {
    if (!fs.existsSync(file)) { errors.push(`${path.basename(file)} is missing`); continue; }
    try { set(JSON.parse(fs.readFileSync(file, 'utf8'))); } catch (e) { errors.push(`${path.basename(file)}: invalid JSON (${e.message})`); }
  }
  if (meta) errors.push(...validateMeta(meta).map((m) => `model_meta.json: ${m}`));
  if (labels) errors.push(...validateLabels(labels).map((m) => `labels.json: ${m}`));
  if (meta && labels && Number.isInteger(meta.labels) && Array.isArray(labels) && meta.labels !== labels.length) {
    errors.push(`labels.json has ${labels.length} labels but model_meta.json says ${meta.labels}`);
  }
  if (meta && typeof meta.file === 'string') {
    const tflite = path.join(modelsDir, meta.file);
    if (!fs.existsSync(tflite)) errors.push(`${meta.file} is missing`);
    else if (fs.statSync(tflite).size > 30 * 1024 * 1024) errors.push(`${meta.file} is over 30 MB (APK budget is about 60 MB in total)`);
  }
  return { present: true, errors, meta, labels };
}

module.exports = { validateMeta, validateLabels, checkModelDir };
