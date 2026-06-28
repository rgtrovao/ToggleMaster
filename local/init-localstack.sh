#!/bin/bash
# Executado pelo LocalStack após a inicialização dos serviços.
# Cria a fila SQS e a tabela DynamoDB necessárias para o projeto.
set -e

echo ">>> Criando recursos LocalStack..."

awslocal sqs create-queue \
    --queue-name togglemaster-events \
    --region us-east-1

awslocal dynamodb create-table \
    --table-name ToggleMasterAnalytics \
    --attribute-definitions AttributeName=event_id,AttributeType=S \
    --key-schema AttributeName=event_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1

echo ">>> Fila SQS 'togglemaster-events' e tabela DynamoDB 'ToggleMasterAnalytics' criadas."
