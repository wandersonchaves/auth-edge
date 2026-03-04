#!/bin/bash

# Preencha com os outputs do Terraform
API_URL="https://9ixyiz7df7.execute-api.us-east-1.amazonaws.com"
USER_POOL_ID="us-east-1_hjsvFyKMy"
CLIENT_ID="isimpinrqh06nh1ge75flmicf"
EMAIL="test@example.com"
PASSWORD="Password123!"

echo "--- 1. Preparando Usuário ---"
# Silenciamos o erro se o usuário já existe
aws cognito-idp sign-up \
  --client-id "$CLIENT_ID" \
  --username "$EMAIL" \
  --password "$PASSWORD" \
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
  --auth-parameters USERNAME="$EMAIL",PASSWORD="$PASSWORD" \
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
