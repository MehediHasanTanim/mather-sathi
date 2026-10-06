'use strict';
const test = require('node:test');
const { before, after } = test;
const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, getBytes } = require('firebase/storage');
const { newEnv } = require('./helpers');

let env;
before(async () => { env = await newEnv(); });
after(async () => { await env.cleanup(); });

const asUser = (uid) => env.authenticatedContext(uid).storage();
const anon = () => env.unauthenticatedContext().storage();
const jpeg = { contentType: 'image/jpeg' };
const bytes = (n) => new Uint8Array(n).fill(1);
const MB = 1024 * 1024;
const seed = (path, data = bytes(10)) => env.withSecurityRulesDisabled(async (ctx) => uploadBytes(ref(ctx.storage(), path), data, jpeg));

test.describe('backups/{uid}', () => {
  test('the owner can upload a small JPEG and read it back', async () => {
    await assertSucceeds(uploadBytes(ref(asUser('alice'), 'backups/alice/h1.jpg'), bytes(300 * 1024), jpeg));
    await assertSucceeds(getBytes(ref(asUser('alice'), 'backups/alice/h1.jpg')));
  });

  test('only JPEGs are accepted', async () => {
    await assertFails(uploadBytes(ref(asUser('alice'), 'backups/alice/a.png'), bytes(100), { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(asUser('alice'), 'backups/alice/a.html'), bytes(100), { contentType: 'text/html' }));
  });

  test('files of 1 MB or more are rejected', async () => {
    await assertFails(uploadBytes(ref(asUser('alice'), 'backups/alice/big.jpg'), bytes(MB), jpeg));
    await assertSucceeds(uploadBytes(ref(asUser('alice'), 'backups/alice/ok.jpg'), bytes(MB - 1), jpeg));
  });

  test("another user cannot read or write someone else's backups", async () => {
    await seed('backups/alice/h2.jpg');
    await assertFails(getBytes(ref(asUser('bob'), 'backups/alice/h2.jpg')));
    await assertFails(uploadBytes(ref(asUser('bob'), 'backups/alice/h3.jpg'), bytes(10), jpeg));
  });

  test('signed-out clients get nothing', async () => {
    await seed('backups/alice/h4.jpg');
    await assertFails(getBytes(ref(anon(), 'backups/alice/h4.jpg')));
    await assertFails(uploadBytes(ref(anon(), 'backups/alice/h5.jpg'), bytes(10), jpeg));
  });
});

test.describe('contrib/{uid}: write-once, never readable by clients', () => {
  test('the owner can create a JPEG once; a second write to the same path is denied', async () => {
    await assertSucceeds(uploadBytes(ref(asUser('alice'), 'contrib/alice/c1.jpg'), bytes(100), jpeg));
    await assertFails(uploadBytes(ref(asUser('alice'), 'contrib/alice/c1.jpg'), bytes(100), jpeg));
  });

  test('not readable, not writable by others, same size and type limits', async () => {
    await seed('contrib/alice/c2.jpg');
    await assertFails(getBytes(ref(asUser('alice'), 'contrib/alice/c2.jpg')));
    await assertFails(uploadBytes(ref(asUser('bob'), 'contrib/alice/c3.jpg'), bytes(10), jpeg));
    await assertFails(uploadBytes(ref(asUser('alice'), 'contrib/alice/c4.png'), bytes(10), { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(asUser('alice'), 'contrib/alice/c5.jpg'), bytes(MB), jpeg));
  });
});

test.describe('kb/ and everything else', () => {
  test('signed-in clients can read the OTA KB, but never write it', async () => {
    await seed('kb/kb.json', bytes(20));
    await assertSucceeds(getBytes(ref(asUser('alice'), 'kb/kb.json')));
    await assertFails(getBytes(ref(anon(), 'kb/kb.json')));
    await assertFails(uploadBytes(ref(asUser('alice'), 'kb/kb.json'), bytes(20), { contentType: 'application/json' }));
  });

  test('unknown paths are denied', async () => {
    await assertFails(uploadBytes(ref(asUser('alice'), 'other/alice/x.jpg'), bytes(10), jpeg));
    await assertFails(getBytes(ref(asUser('alice'), 'other/alice/x.jpg')));
  });
});
