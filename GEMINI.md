# AuthEdge - Contexto de Desenvolvimento

Este projeto é uma plataforma de autenticação e autorização serverless projetada para alto desempenho, segurança e baixo custo.

## Visão Geral do Projeto
- **Arquitetura:** Serverless (AWS Lambda, API Gateway HTTP, Amazon Cognito, DynamoDB).
- **Tecnologias:** TypeScript (Node.js 20), Terraform, esbuild (bundling).
- **Segurança:** RBAC via grupos do Cognito, validação customizada de JWKS com cache em memória no Lambda Authorizer.

## Estrutura do Repositório
- `apps/api/`: Lambda principal que processa rotas de negócio (`/me`, `/admin`, `/health`).
- `apps/authorizer/`: Lambda Authorizer customizado para validação de JWT e RBAC.
- `packages/security/`: Lógica central de validação de tokens e gerenciamento de JWKS.
- `packages/shared/`: Utilitários de log estruturado (JSON) e integração com DynamoDB para auditoria.
- `iac/terraform/env/dev/`: Definições de infraestrutura como código para o ambiente de desenvolvimento.
- `docs/`: Documentação técnica (Arquitetura, Threat Model, Runbook).

## Comandos Principais

### Compilação e Build
Gera os bundles otimizados e arquivos .zip para as Lambdas:
```bash
npm install
npm run build
```

### Infraestrutura (Terraform)
Gerenciamento de recursos AWS:
```bash
# Inicializar
npm run infra:init

# Planejar/Aplicar mudanças
npm run infra:plan
npm run infra:apply
```

### Deploy Completo
Atalho para build e aplicação da infraestrutura:
```bash
npm run deploy
```

## Convenções de Desenvolvimento
- **Logs:** Use sempre o logger estruturado de `@authedge/shared`. Eventos que começam com `AUTHZ_` são automaticamente persistidos no DynamoDB para auditoria.
- **Segurança:** O Authorizer deve rejeitar requisições o mais cedo possível. Novas rotas protegidas devem ser registradas no `main.tf` e validadas no RBAC do Authorizer.
- **Tipagem:** O projeto utiliza TypeScript estrito. Certifique-se de manter as definições de tipo em `packages/shared/src/types.ts`.
- **Bundling:** O `esbuild` é usado para gerar arquivos ESM minificados. Evite bibliotecas pesadas que aumentem significativamente o tamanho do bundle.

## Fluxo de Autenticação
1. O cliente obtém o token (ID Token) via AWS Cognito.
2. O cliente chama o API Gateway enviando o token no header `Authorization: Bearer <TOKEN>`.
3. O Lambda Authorizer valida a assinatura (JWKS), emissor, expiração e aud do token.
4. O Authorizer verifica se o usuário pertence ao grupo necessário para a rota (ex: `admin` para `/admin`).
5. Se autorizado, o contexto do usuário (sub, email, grupos) é injetado na requisição para a Lambda de API.
