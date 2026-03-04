# Runbook / Troubleshooting

### Issues
- **Invalid Signature:** Ensure `USER_POOL_ID` and `CLIENT_ID` are correct in the Authorizer environment variables.
- **Access Denied (403):** Check if the user is in the correct Cognito group (`admin` or `user`).
- **Lambda Errors:** Check CloudWatch logs.
- **Audit Logging Failures:** Verify IAM permission `dynamodb:PutItem` for the lambda role.

### Commands for Troubleshooting
```bash
# Get lambda logs
aws logs tail /aws/lambda/auth-edge-authorizer --follow
aws logs tail /aws/lambda/auth-edge-api --follow
```
