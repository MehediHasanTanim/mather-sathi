'use strict';
const crypto = require('node:crypto');

/**
 * Decides whether a built KB may be published, and what `kb_versions/current` should say.
 * Pure: no network. `current` is the pointer now in Firestore (or null).
 * Rules: never publish drafts to stg/prod; `seq` must strictly increase (a rollback is a NEW, higher seq with the
 * bad entry removed, so every client moves forward); the pointer carries the SHA-256 of exactly these bytes.
 */
function planPublish({ kbJson, env, current, now = new Date() }) {
  const errors = [];
  let kb;
  try { kb = JSON.parse(kbJson); } catch (e) { return { errors: [`kb.json is not valid JSON: ${e.message}`] }; }
  if (!Number.isInteger(kb.seq) || kb.seq < 1) errors.push('kb.json has no integer "seq"');
  if (!Number.isInteger(kb.schema)) errors.push('kb.json has no integer "schema"');
  if (typeof kb.version !== 'string') errors.push('kb.json has no "version"');
  if (!Array.isArray(kb.entries) || kb.entries.length === 0) errors.push('kb.json has no entries');
  if (env !== 'dev' && kb.includes_drafts) errors.push(`a KB with draft entries must not be published to ${env}`);
  if (env !== 'dev' && Array.isArray(kb.entries) && kb.entries.some((e) => e.status !== 'published')) errors.push(`${env} KB contains unpublished entries`);
  if (current && Number.isInteger(kb.seq) && kb.seq <= current.seq) errors.push(`seq ${kb.seq} is not higher than the published seq ${current.seq}: bump kb/meta.json seq`);
  if (errors.length) return { errors };
  const sha256 = crypto.createHash('sha256').update(kbJson).digest('hex');
  const path = `kb/kb_${kb.seq}.json`;
  return {
    errors: [],
    object: { path, contentType: 'application/json' },
    pointer: { version: kb.version, seq: kb.seq, sha256, path, minAppSchema: kb.schema, publishedAt: now.toISOString() },
  };
}

module.exports = { planPublish };
