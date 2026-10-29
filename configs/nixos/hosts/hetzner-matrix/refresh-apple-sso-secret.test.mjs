import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { test } from 'node:test';
import { execFileSync } from 'node:child_process';
import {
  mkdtempSync,
  readFileSync,
  writeFileSync,
  rmSync,
  unlinkSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  createAppleClientSecret,
  renewAppleSecrets,
} from './refresh-apple-sso-secret.mjs';

test('creates a valid ES256 JWT for the existing Apple web service', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
  });
  const now = 1_800_000_000;
  const token = createAppleClientSecret(privateKey, 'TESTKEY123', now);
  const [header, payload, signature] = token.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url')), {
    alg: 'ES256',
    kid: 'TESTKEY123',
  });
  assert.deepEqual(JSON.parse(Buffer.from(payload, 'base64url')), {
    iss: 'DNA6966LGZ',
    sub: 'chat.mindroom.matrix.apple',
    aud: 'https://appleid.apple.com',
    iat: now - 60,
    exp: now + 180 * 86400,
  });
  assert.equal(Buffer.from(signature, 'base64url').length, 64);
  assert.equal(
    verify(
      'sha256',
      Buffer.from(`${header}.${payload}`),
      {
        key: publicKey,
        dsaEncoding: 'ieee-p1363',
      },
      Buffer.from(signature, 'base64url')
    ),
    true
  );
});

test('rejects an unsuitable key or malformed Apple key ID', () => {
  const wrong = generateKeyPairSync('ec', {
    namedCurve: 'secp384r1',
  }).privateKey;
  assert.throws(() => createAppleClientSecret(wrong, 'TESTKEY123'), /P-256/);
  const valid = generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
  }).privateKey;
  assert.throws(() => createAppleClientSecret(valid, 'wrong'), /key ID/);
});

test('encrypts the JWT to owner and server, and the private key only to owner', () => {
  const directory = mkdtempSync(join(tmpdir(), 'apple-sso-renew-test-'));
  try {
    const recipients = ['owner', 'server'].map((name) => {
      const identity = join(directory, name);
      execFileSync('age-keygen', ['-o', identity], { stdio: 'pipe' });
      return execFileSync('age-keygen', ['-y', identity], {
        encoding: 'utf8',
      }).trim();
    });
    const { privateKey } = generateKeyPairSync('ec', {
      namedCurve: 'prime256v1',
    });
    const pem = privateKey.export({ type: 'pkcs8', format: 'pem' });
    const keyPath = join(directory, 'AuthKey_TESTKEY123.p8');
    writeFileSync(keyPath, pem, { mode: 0o600 });
    const pending = join(
      directory,
      `sso-apple-key-TESTKEY123.p8.age.${process.pid}.next`
    );
    writeFileSync(pending, 'existing ciphertext');
    assert.throws(
      () => renewAppleSecrets({ keyPath, directory, recipients }),
      /EEXIST/
    );
    assert.equal(readFileSync(pending, 'utf8'), 'existing ciphertext');
    unlinkSync(pending);
    const result = renewAppleSecrets({ keyPath, directory, recipients });
    const decrypt = (identity, path) =>
      execFileSync('age', ['-d', '-i', join(directory, identity), path], {
        encoding: 'utf8',
        stdio: 'pipe',
      });
    assert.equal(decrypt('owner', result.backup), pem);
    assert.throws(() => decrypt('server', result.backup));
    const token = decrypt('server', result.secret).trim();
    assert.equal(
      JSON.parse(Buffer.from(token.split('.')[1], 'base64url')).sub,
      'chat.mindroom.matrix.apple'
    );
    assert.equal(readFileSync(result.backup, 'utf8').includes(pem), false);
    const backup = readFileSync(result.backup);
    renewAppleSecrets({ keyPath, directory, recipients });
    assert.deepEqual(readFileSync(result.backup), backup);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
