import { APIGatewayProxyEventV2WithRequestContext, APIGatewayProxyResultV2 } from 'aws-lambda';
import { logger } from '@authedge/shared';

export const handler = async (
  event: APIGatewayProxyEventV2WithRequestContext<any>
): Promise<APIGatewayProxyResultV2> => {
  const requestId = event.requestContext.requestId;
  const path = event.rawPath;
  const method = event.requestContext.http.method;

  // Extract authorizer context if available
  const authContext = event.requestContext.authorizer?.lambda;

  await logger.log({ 
    level: 'INFO', 
    event: 'API_REQUEST', 
    requestId, 
    userId: authContext?.userId,
    message: `Request: ${method} ${path}`
  });

  if (path === '/health') {
    return {
      statusCode: 200,
      body: JSON.stringify({ status: 'OK', timestamp: new Date().toISOString() }),
    };
  }

  if (path === '/me' && authContext) {
    return {
      statusCode: 200,
      body: JSON.stringify({
        userId: authContext.userId,
        email: authContext.email,
        roles: authContext.groups ? authContext.groups.split(',') : [],
      }),
    };
  }

  if (path === '/admin' && authContext) {
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Welcome to the Admin Dashboard',
        adminId: authContext.userId,
      }),
    };
  }

  return {
    statusCode: 404,
    body: JSON.stringify({ message: 'Not Found' }),
  };
};
