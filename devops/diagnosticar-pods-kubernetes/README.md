---
nome: Diagnosticar Pods Kubernetes
descricao: Analisa um snapshot de pods, eventos e logs do Kubernetes e entrega a causa raiz provável com ações para o plantão
versao: 1.1.0
tags: [kubernetes, troubleshooting, sre, diagnóstico, incidentes]
inputs:
  - nome: snapshot
    descricao: Snapshot do Kubernetes com status dos pods (STATUS, RESTARTS), eventos e logs, a ser analisado
---

# Diagnosticar Pods Kubernetes

## Objetivo

Analisar um snapshot do Kubernetes (status dos pods, eventos e logs) e identificar a causa raiz provável dos pods em estado problemático. O prompt cruza `STATUS`/`RESTARTS`, eventos e linhas de erro dos logs, e gera um relatório com ações recomendadas para o engenheiro de plantão. Se todos os pods estiverem saudáveis, ele devolve um relatório curto de status saudável.

## Quando usar

- Durante um incidente, para triar rapidamente pods em `CrashLoopBackOff`, `ImagePullBackOff`, `Pending`, `Terminating` ou `OOMKilled`.
- Quando você tem status, eventos e logs de um workload e quer uma causa raiz correlacionada, não apenas o status.
- Para confirmar que uma aplicação está saudável após um deploy ou mudança.

## Exemplo de uso

Com o snapshot saudável de [`incidente/snapshot_teste3.txt`](./incidente/snapshot_teste3.txt), a saída é:

```markdown
## ✅ Status da Aplicação: Saudável
- **Pods Analisados**: 4
- **Status**: Todos os pods estão operando normalmente (`Running`), com reinicializações mínimas e logs sem erros.
- **Ação Recomendada**: Nenhuma ação necessária no momento.
```

## Testes

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) roda os 3 snapshots de `incidente/` com `gpt-4.1-mini`, com 3 repetições e sem cache:

- **Entrada 1:** cita o pod `sentinel-api-7d9c8b6f4-h4m2t` e a causa de memória.
- **Entrada 2:** cita os dois pods problemáticos, a tag `2.9.2` com `ImagePullBackOff` e a falta de CPU.
- **Entrada 3:** indica que está saudável e não traz relatório de falha.
- **Todas:** respondem em até 5 s, com custo de até US$ 0,01 por chamada.

```bash
npx promptfoo@latest eval -c devops/diagnosticar-pods-kubernetes/promptfooconfig.yaml
```

## Limitações conhecidas

- Com `gpt-4o-mini`, o relatório de dois pods excede 5 s. Com mais pods problemáticos, o `gpt-4.1-mini` também pode exceder esse limite.
- Na Entrada 2, os testes verificam se pods e causas aparecem na saída, não se cada causa está associada ao pod certo.
- Os testes não avaliam a qualidade da ação recomendada.
- O teste com um segundo fornecedor ainda não foi executado.
