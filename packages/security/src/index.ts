import { createRemoteJWKSet, jwtVerify } from 'jose';
import { UserContext } from '@authedge/shared';

const JWKS_CACHE: Record<string, any> = {};

export class SecurityManager {
  private jwks: any;
  private issuer: string;

  constructor(private region: string, private userPoolId: string, private clientId: string) {
    const jwksUrl = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}/.well-known/jwks.json`;
    this.issuer = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}`;
    
    // Simple in-memory singleton cache per instance
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
