#!/usr/bin/env node
// Keep plaintext credentials in memory; only age ciphertext is written to disk.
import { createPrivateKey, sign } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import {
  existsSync,
  readFileSync,
  writeFileSync,
  renameSync,
  unlinkSync,
} from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function createAppleClientSecret(
  key,
  keyId,
  now = Math.floor(Date.now() / 1000)
) {
  if (!/^[A-Z0-9]{10}$/.test(keyId))
    throw new Error('Expected a ten-character Apple key ID.');
  if (
    key.asymmetricKeyType !== 'ec' ||
    key.asymmetricKeyDetails.namedCurve !== 'prime256v1'
  ) {
    throw new Error('Apple SSO requires a P-256 EC private key.');
  }
  const encode = (value) =>
    Buffer.from(JSON.stringify(value)).toString('base64url');
  const header = encode({ alg: 'ES256', kid: keyId });
  const payload = encode({
    iss: 'DNA6966LGZ',
    sub: 'chat.mindroom.matrix.apple',
    aud: 'https://appleid.apple.com',
    iat: now - 60,
    exp: now + 180 * 86400,
  });
  const input = `${header}.${payload}`;
  const signature = sign('sha256', Buffer.from(input), {
    key,
    dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
  return `${input}.${signature}`;
}

function writeCiphertext(path, plaintext, recipients) {
  const ciphertext = execFileSync(
    'age',
    ['-e', ...recipients.flatMap((value) => ['-r', value])],
    {
      input: plaintext,
      stdio: ['pipe', 'pipe', 'pipe'],
    }
  );
  const temporary = `${path}.${process.pid}.next`;
  let created = false;
  try {
    writeFileSync(temporary, ciphertext, { flag: 'wx', mode: 0o644 });
    created = true;
    renameSync(temporary, path);
    created = false;
  } finally {
    if (created) unlinkSync(temporary);
  }
}

export function renewAppleSecrets({ keyPath, directory, recipients }) {
  const match = /^AuthKey_([A-Z0-9]{10})\.p8$/.exec(basename(keyPath));
  if (!match)
    throw new Error('Expected downloaded AuthKey_<key ID>.p8 filename.');
  if (recipients.length !== 2 || recipients.some((value) => !value))
    throw new Error('Owner and server recipients are required.');
  const keyId = match[1];
  const pem = readFileSync(keyPath);
  const token = createAppleClientSecret(createPrivateKey(pem), keyId);
  const backup = join(directory, `sso-apple-key-${keyId}.p8.age`);
  // Preserve an existing recovery copy when refreshing the JWT with the same key.
  if (!existsSync(backup)) writeCiphertext(backup, pem, [recipients[0]]);
  const secret = join(directory, 'sso-apple-secret.age');
  writeCiphertext(secret, `${token}\n`, recipients);
  const claims = JSON.parse(Buffer.from(token.split('.')[1], 'base64url'));
  return {
    keyId,
    secret,
    backup,
    expires: new Date(claims.exp * 1000).toISOString(),
  };
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    if (process.argv.length !== 3)
      throw new Error(
        'Usage: node refresh-apple-sso-secret.mjs /path/AuthKey_<key ID>.p8'
      );
    const host = dirname(fileURLToPath(import.meta.url));
    const owner = readFileSync(
      resolve(host, '../../common/ssh-keys.nix'),
      'utf8'
    ).match(/\bbas\s*=\s*"([^"]+)"/)?.[1];
    const server = readFileSync(
      join(host, 'secrets/secrets.nix'),
      'utf8'
    ).match(/\bhetznerMatrixHost\s*=\s*"([^"]+)"/)?.[1];
    console.log(
      JSON.stringify(
        renewAppleSecrets({
          keyPath: process.argv[2],
          directory: join(host, 'secrets'),
          recipients: [owner, server],
        }),
        null,
        2
      )
    );
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
