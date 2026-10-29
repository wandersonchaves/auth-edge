import { describe, it, expect, beforeAll } from 'vitest';
import { SignJWT, generateKeyPair, createLocalJWKSet, exportJWK, type JWK, type KeyLike } from 'jose';
import { SecurityManager } from './index.js';

const REGION = 'us-east-1';
const POOL_ID = 'us-east-1_TESTPOOL';
const CLIENT_ID = 'test-client-id';
const ISSUER = `https://cognito-idp.${REGION}.amazonaws.com/${POOL_ID}`;

let privateKey: KeyLike;
let otherPrivateKey: KeyLike;
let manager: SecurityManager;

async function sign(
  claims: Record<string, unknown>,
  opts: { key?: KeyLike; issuer?: string; audience?: string; expiresIn?: string } = {},
) {
  return new SignJWT(claims)
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setSubject('user-123')
    .setIssuer(opts.issuer ?? ISSUER)
    .setAudience(opts.audience ?? CLIENT_ID)
    .setIssuedAt()
    .setExpirationTime(opts.expiresIn ?? '5m')
    .sign(opts.key ?? privateKey);
}

beforeAll(async () => {
  const pair = await generateKeyPair('RS256');
  const other = await generateKeyPair('RS256');
  privateKey = pair.privateKey;
  otherPrivateKey = other.privateKey;
  const publicJwk: JWK = { ...(await exportJWK(pair.publicKey)), kid: 'test-key', alg: 'RS256', use: 'sig' };
  manager = new SecurityManager(REGION, POOL_ID, CLIENT_ID, createLocalJWKSet({ keys: [publicJwk] }));
});

describe('SecurityManager.verifyToken', () => {
  it('returns the user context for a valid token', async () => {
    const token = await sign({ email: 'a@b.com', 'cognito:groups': ['admin', 'user'] });
    await expect(manager.verifyToken(token)).resolves.toEqual({
      sub: 'user-123',
      email: 'a@b.com',
      groups: ['admin', 'user'],
    });
  });

  it('defaults to no groups and empty email when the claims are absent', async () => {
    const token = await sign({});
    await expect(manager.verifyToken(token)).resolves.toEqual({ sub: 'user-123', email: '', groups: [] });
  });

  it('rejects a token signed with an unknown key', async () => {
    const token = await sign({}, { key: otherPrivateKey });
    await expect(manager.verifyToken(token)).rejects.toThrow(/Invalid token/);
  });

  it('rejects a token from a different issuer', async () => {
    const token = await sign({}, { issuer: 'https://evil.example.com' });
    await expect(manager.verifyToken(token)).rejects.toThrow(/Invalid token/);
  });

  it('rejects a token issued for a different client (audience)', async () => {
    const token = await sign({}, { audience: 'another-client' });
    await expect(manager.verifyToken(token)).rejects.toThrow(/Invalid token/);
  });

  it('rejects an expired token', async () => {
    const token = await sign({}, { expiresIn: '-1m' });
    await expect(manager.verifyToken(token)).rejects.toThrow(/Invalid token/);
  });

  it('rejects a malformed token', async () => {
    await expect(manager.verifyToken('not-a-jwt')).rejects.toThrow(/Invalid token/);
  });
});

describe('SecurityManager.hasRole', () => {
  const user = { sub: 'u', email: '', groups: ['user'] };

  it('is true when the group is present', () => {
    expect(manager.hasRole(user, 'user')).toBe(true);
  });

  it('is false when the group is missing', () => {
    expect(manager.hasRole(user, 'admin')).toBe(false);
  });
});
