// Stub until task 5.6 adds emulator-backed @firebase/rules-unit-testing tests.
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

test("rules files exist and deny reads of reports", () => {
  const fsRules = fs.readFileSync(path.join(__dirname, "../firestore.rules"), "utf8");
  assert.match(fsRules, /allow read, update, delete: if false/);
  assert.ok(fs.existsSync(path.join(__dirname, "../storage.rules")));
});
