#!/usr/bin/env node
// Phase 0 stub. Task 3.1 implements every rule in Design §5.3 and compiles kb.json / kb_index.json.
const fs = require("node:fs");
const path = require("node:path");

const srcDir = path.join(__dirname, "../../kb/src");
const files = fs.readdirSync(srcDir).filter((f) => f.endsWith(".json"));
console.log(`kb_build: ${files.length} entries found (validator not implemented yet)`);
process.exit(0);
