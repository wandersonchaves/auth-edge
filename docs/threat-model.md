# Threat Model (STRIDE)

| Threat | Strategy | Mitigation |
|--------|----------|------------|
| Spoofing | Authentication | Cognito User Pool with JWT validation. |
| Tampering | Integrity | Token signature check (JWKS). |
| Repudiation | Accountability | Audit logs in DynamoDB for every auth attempt. |
| Information Disclosure | Confidentiality | IAM least privilege, CloudWatch retention policy. |
| Denial of Service | Availability | API Gateway Throttling (default AWS limits). |
| Elevation of Privilege | Authorization | RBAC via Lambda Authorizer (Path-based group checks). |
