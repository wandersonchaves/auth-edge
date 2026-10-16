# AuthEdge

Serverless authentication and authorization on AWS. Clients get a token from **Amazon Cognito** and call an **HTTP API** on API Gateway. A **Lambda authorizer** validates the JWT (with cached JWKS) and checks role-based access from Cognito groups before the request reaches the API Lambda. Access decisions are written to **DynamoDB** as an audit log. Everything is provisioned with **Terraform**.

## Flow

```
Client ──(1) sign in──► Cognito ──► JWT
Client ──(2) Bearer JWT──► API Gateway (HTTP API)
                               │ (3)
                               ▼
                        Lambda Authorizer ── JWKS (cached) ── Cognito
                               │ (4) signature + claims
                               │ (5) RBAC: Cognito groups × route
                               ▼ allow / deny + user context
                          API Lambda ──► DynamoDB (audit log)
```

## Design decisions

- **HTTP API instead of REST API:** lower cost and latency for this use case.
- **Custom Lambda authorizer** (`jose`) instead of the built-in JWT authorizer, to enforce RBAC per route.
- **JWKS caching** in the authorizer to avoid one Cognito round trip per request.
- **Pay-per-use:** no always-on servers.

See [`docs/architecture.md`](docs/architecture.md), [`docs/threat-model.md`](docs/threat-model.md) and [`docs/runbook.md`](docs/runbook.md).

## Repository layout

```
apps/authorizer   Lambda authorizer
apps/api          API Lambda
packages/security JWT and RBAC helpers
packages/shared   shared types
iac/terraform     infrastructure (env/dev)
```

## Deploy

Requires Node.js 20+, AWS CLI and Terraform 1.5+.

```bash
npm install && npm run build
cd iac/terraform/env/dev
terraform init
terraform apply
cd - && ./test-flow.sh     # end-to-end check: sign up, sign in, call the API, verify allow/deny
```

> Terraform state is not committed. Configure a remote backend (S3 + DynamoDB lock) before sharing an environment.

## Stack

TypeScript · AWS Lambda · API Gateway · Cognito · DynamoDB · CloudWatch · IAM · Terraform
