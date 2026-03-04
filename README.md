# AuthEdge - Serverless Authentication Platform

Platform for secure authentication and authorization using AWS Serverless (Cognito, Lambda, API Gateway).

## Prerequisites
- Node.js 20+
- AWS CLI configured
- Terraform 1.5+

## Quick Start (Deploy)
1. **Install dependencies:**
   ```bash
   npm install
   ```
2. **Build the project:**
   ```bash
   npm run build
   ```
3. **Deploy via Terraform:**
   ```bash
   npm run infra:init
   npm run infra:apply
   ```

## Testing the Platform
After deployment, you'll get the `api_endpoint`, `user_pool_id`, and `app_client_id` in the outputs.

### 1. Create a User (AWS CLI)
```bash
# Create user
aws cognito-idp sign-up \
  --client-id <app_client_id> \
  --username user@example.com \
  --password "Password123!" \
  --user-attributes Name=email,Value=user@example.com

# Confirm user (Admin bypass)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id <user_pool_id> \
  --username user@example.com

# Add user to a group (user or admin)
aws cognito-idp admin-add-user-to-group \
  --user-pool-id <user_pool_id> \
  --username user@example.com \
  --group-name user
```

### 2. Login and get JWT
```bash
aws cognito-idp initiate-auth \
  --client-id <app_client_id> \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=user@example.com,PASSWORD="Password123!" \
  --query 'AuthenticationResult.IdToken' \
  --output text
```

### 3. Call the API
```bash
export TOKEN="<jwt_token>"
export API_URL="<api_endpoint>"

# Public Health Check
curl $API_URL/health

# Protected /me
curl -H "Authorization: Bearer $TOKEN" $API_URL/me

# Protected /admin (requires 'admin' group)
curl -H "Authorization: Bearer $TOKEN" $API_URL/admin
```
