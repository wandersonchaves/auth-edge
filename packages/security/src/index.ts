import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import type { UserContext } from '@authedge/shared';

const JWKS_CACHE: Record<string, JWTVerifyGetKey> = {};

export class SecurityManager {
  private jwks: JWTVerifyGetKey;
  private issuer: string;

  // `jwks` is optional so tests can inject a local key set instead of calling Cognito.
  constructor(
    private region: string,
    private userPoolId: string,
    private clientId: string,
    jwks?: JWTVerifyGetKey,
  ) {
    const jwksUrl = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}/.well-known/jwks.json`;
    this.issuer = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}`;
    
    if (jwks) {
      this.jwks = jwks;
      return;
    }

    // One remote key set per JWKS URL, reused across invocations of a warm Lambda.
    // jose also caches the fetched keys inside the key set.
    if (!JWKS_CACHE[jwksUrl]) {
      JWKS_CACHE[jwksUrl] = createRemoteJWKSet(new URL(jwksUrl));
    }
    this.jwks = JWKS_CACHE[jwksUrl];
  }

  async verifyToken(token: string): Promise<UserContext> {
    try {
      const { payload } = await jwtVerify(token, this.jwks, {
        issuer: this.issuer,
        audience: this.clientId,
      });

      return {
        sub: payload.sub as string,
        email: payload.email as string || '',
        groups: (payload['cognito:groups'] as string[]) || [],
      };
    } catch (err) {
      throw new Error(`Invalid token: ${err instanceof Error ? err.message : 'unknown'}`);
    }
  }

  hasRole(user: UserContext, requiredRole: string): boolean {
    return user.groups.includes(requiredRole);
  }
}
