#!/bin/bash

# Reads the deployed environment from Terraform outputs (run `npm run deploy` first).
TF_DIR="$(dirname "$0")/iac/terraform/env/dev"
API_URL=$(terraform -chdir="$TF_DIR" output -raw api_endpoint)
USER_POOL_ID=$(terraform -chdir="$TF_DIR" output -raw user_pool_id)
CLIENT_ID=$(terraform -chdir="$TF_DIR" output -raw app_client_id)
EMAIL="${TEST_EMAIL:-test@example.com}"
if [ -z "$TEST_PASSWORD" ]; then
  echo "Set TEST_PASSWORD to a throwaway value for the test user." >&2
  exit 1
fi

echo "--- 1. Preparando Usuário ---"
# Silenciamos o erro se o usuário já existe
aws cognito-idp sign-up \
  --client-id "$CLIENT_ID" \
  --username "$EMAIL" \
  --password "$TEST_PASSWORD" \
  --user-attributes Name=email,Value="$EMAIL" 2>/dev/null

aws cognito-idp admin-confirm-sign-up \
  --user-pool-id "$USER_POOL_ID" \
  --username "$EMAIL" 2>/dev/null

aws cognito-idp admin-add-user-to-group --user-pool-id "$USER_POOL_ID" --username "$EMAIL" --group-name user 2>/dev/null
aws cognito-idp admin-add-user-to-group --user-pool-id "$USER_POOL_ID" --username "$EMAIL" --group-name admin 2>/dev/null

echo "--- 2. Realizando Login e Obtendo Token ---"
TOKEN=$(aws cognito-idp initiate-auth \
  --client-id "$CLIENT_ID" \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="$EMAIL",PASSWORD="$TEST_PASSWORD" \
  --query 'AuthenticationResult.IdToken' \
  --output text)

if [ "$TOKEN" == "None" ] || [ -z "$TOKEN" ]; then
  echo "❌ Erro ao obter token. Verifique as credenciais."
  exit 1
fi

echo "✅ Token obtido com sucesso!"
echo "------------------------------------------------------------"
echo "COPIE O TOKEN ABAIXO PARA TESTAR NO JWT.IO:"
echo "$TOKEN"
echo "------------------------------------------------------------"

echo -e "\n--- 3. Testando Endpoints ---"

echo -e "\n[PUBLIC] GET /health"
curl -s "$API_URL/health" | jq .

echo -e "\n[PROTECTED] GET /me"
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/me" | jq .

echo -e "\n[PROTECTED] GET /admin"
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/admin" | jq .

echo -e "\n--- Testes Concluídos ---"
