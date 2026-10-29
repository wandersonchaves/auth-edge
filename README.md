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

## Status

The code, tests and Terraform are in this repository. I deployed the `dev` environment and ran `test-flow.sh` end to end (sign up, sign in, public route, protected route, admin deny/allow), then **tore the environment down to avoid AWS cost**. There is no live demo URL; `npm run deploy` recreates everything.

Scope and limits: one Cognito user pool, two groups (`admin`, `user`), one path rule (`/admin*` requires `admin`). The authorizer expects a Cognito **ID token** (the `aud` claim must equal the app client id). It is a portfolio project, not a production system.

## Repository layout

```
apps/authorizer   Lambda authorizer
apps/api          API Lambda
packages/security JWT and RBAC helpers
packages/shared   shared types
iac/terraform     infrastructure (env/dev)
```

## Tests and CI

```bash
npm install
npm run typecheck
npm test        # vitest: JWT verification and RBAC helper
```

`packages/security` is tested with locally generated keys (no network): valid token, wrong signature, wrong issuer, wrong audience, expired and malformed tokens, plus the group check. GitHub Actions runs typecheck, tests and build on every push and pull request.

Not covered yet: the authorizer handler itself (route rule and audit-log writes) and Terraform validation in CI.

## Deploy

Requires Node.js 20+, AWS CLI and Terraform 1.5+.

```bash
npm install && npm run build
cd iac/terraform/env/dev
terraform init
terraform apply
cd - && TEST_PASSWORD='choose-a-throwaway-password' ./test-flow.sh   # end-to-end: sign up, sign in, call the API, verify allow/deny
```

> Terraform state is not committed. Configure a remote backend (S3 + DynamoDB lock) before sharing an environment.

## Stack

TypeScript · AWS Lambda · API Gateway · Cognito · DynamoDB · CloudWatch · IAM · Terraform
