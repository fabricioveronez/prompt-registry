---
# Diagnóstico de Causa Raiz em Pods Kubernetes

## Descrição
Prompt analítico desenvolvido para equipes de SRE e Plantão. Processa snapshots de diagnóstico do Kubernetes (cruzando `kubectl get pods`, `kubectl describe` e `kubectl logs`) e retorna a causa raiz provável juntamente com a ação recomendada.

## Metadados
- **Versão**: 1.0.0
- **Domínio**: DevOps / SRE
- **Técnica**: Chain-of-Thought (CoT)
- **Modelo Recomendado**: Claude 3.5 Sonnet, GPT-4o ou Gemini Pro (modelos com raciocínio analítico elevado)

## Como Usar
1. Extraia o snapshot do cluster/namespace problemático.
2. Insira o texto do snapshot na variável `{SNAPSHOT}` do file `prompt.md`.
3. Execute no LLM de sua preferência.

## Casos de Teste Suportados
- **Entrada 1 (Pod reiniciando)**: Detecta OOMKilled, falha de Liveness Probe ou Uncaught Exceptions em logs.
- **Entrada 2 (Pods que não sobem)**: Identifica ImagePullBackOff, erros de Secret/ConfigMap ausente ou Pending por falta de CPU/Memória na nó.
- **Entrada 3 (Tudo saudável)**: Retorna resumo limpo confirmando saúde sem falsos positivos.
```
---

