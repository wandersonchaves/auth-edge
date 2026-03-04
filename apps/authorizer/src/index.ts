import { APIGatewayProxyEventV2WithRequestContext, APIGatewaySimpleAuthorizerWithContextResult } from 'aws-lambda';
import { SecurityManager } from '@authedge/security';
import { logger, AuthorizerContext } from '@authedge/shared';

const security = new SecurityManager(
  process.env.AWS_REGION || 'us-east-1',
  process.env.USER_POOL_ID!,
  process.env.CLIENT_ID!
);

export const handler = async (
  event: any // Using any for V2 simple authorizer payload
): Promise<APIGatewaySimpleAuthorizerWithContextResult<AuthorizerContext>> => {
  const requestId = event.requestContext?.requestId || 'unknown';
  const methodArn = event.routeKey; // e.g. "GET /admin"
  const token = event.headers?.authorization?.split(' ')[1];

  if (!token) {
    await logger.log({ level: 'WARN', event: 'TOKEN_INVALID', requestId, message: 'Missing token' });
    return { isAuthorized: false };
  }

  try {
    const user = await security.verifyToken(token);
    
    // RBAC Logic
    const path = event.rawPath;
    let isAuthorized = true;

    if (path.startsWith('/admin') && !security.hasRole(user, 'admin')) {
      isAuthorized = false;
      await logger.log({ 
        level: 'WARN', 
        event: 'AUTHZ_DENY', 
        requestId, 
        userId: user.sub, 
        message: 'Forbidden: Admin access required',
        details: { path, groups: user.groups }
      });
    }

    if (isAuthorized) {
      await logger.log({ 
        level: 'INFO', 
        event: 'AUTHZ_ALLOW', 
        requestId, 
        userId: user.sub, 
        message: 'Access granted',
        details: { path }
      });
    }

    return {
      isAuthorized,
      context: {
        userId: user.sub,
        email: user.email,
        groups: user.groups.join(','),
      },
    };
  } catch (err) {
    await logger.log({ 
      level: 'ERROR', 
      event: 'TOKEN_INVALID', 
      requestId, 
      message: 'Token verification failed', 
      details: { error: (err as Error).message } 
    });
    return { isAuthorized: false };
  }
};
