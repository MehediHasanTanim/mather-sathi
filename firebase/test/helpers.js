'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const PROJECT = 'demo-krishi';

function hostPort(envVar, fallbackPort) {
  const v = process.env[envVar] || `127.0.0.1:${fallbackPort}`;
  const [host, port] = v.split(':');
  return { host, port: Number(port) };
}

/** Test environment against the running emulators (use `npm run test:emulated`). */
async function newEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8'), ...hostPort('FIRESTORE_EMULATOR_HOST', 8080) },
    storage: { rules: fs.readFileSync(path.join(__dirname, '../storage.rules'), 'utf8'), ...hostPort('FIREBASE_STORAGE_EMULATOR_HOST', 9199) },
  });
}

module.exports = { newEnv };
