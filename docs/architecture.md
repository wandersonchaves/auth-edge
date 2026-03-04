# AuthEdge Architecture

## Design Goals
- High availability via Serverless (multi-AZ by default).
- Low cost (Pay-as-you-go).
- Performance: Lambda Authorizer with JWKS caching.
- Security: RBAC using Cognito groups.

## Components
- **API Gateway (HTTP API):** Entry point, cheaper than REST API.
- **Lambda Authorizer:** Custom validation for JWT using `jose` and Cognito groups.
- **Cognito:** Managed Identity Provider.
- **DynamoDB:** Audit logging for compliance.

## Flow
1. Client requests token from Cognito.
2. Client calls API Gateway with Bearer token.
3. API Gateway invokes Authorizer Lambda.
4. Authorizer validates token signature and claims.
5. Authorizer checks RBAC (Groups vs Path).
6. Authorizer allows/denies and passes user context to API Lambda.
7. API Lambda executes business logic.
