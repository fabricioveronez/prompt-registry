---
nome: Especificar Execução Tática da Migração para Tempo Real
descricao: Transforma o plano de migração do Forge em especificação executável, com padrões de resiliência e garantia de entrega, contratos de eventos, DLQ e retry, plano de observabilidade e checklist de validação do cutover.
versao: 1.0.0
tags: [implementação, resiliência, observabilidade, eventos, cutover]
inputs:
  - nome: resultado_prompt_2
    descricao: Plano de migração do Forge (saída do passo anterior), usado como base para detalhar a execução técnica
---

# Especificar Execução Tática da Migração para Tempo Real

## Objetivo

Com base no plano passo a passo de migração do Forge, o prompt assume o papel de Engenheiro de Software Senior e SRE Lead. Ele compara ao menos duas abordagens de garantia de entrega e resiliência (ex.: at-least-once com idempotência vs. exactly-once), escolhe uma com foco em integridade de dados e complexidade, e entrega um guia operacional (contratos de eventos/schemas, DLQ e retry exponencial, métricas de observabilidade) e um checklist de validação para autorizar o go-live.

## Quando usar

- Depois de definido o plano de migração do Forge, para transformá-lo em especificações executáveis.
- Quando é preciso decidir padrões de garantia de entrega, tratamento de erros e observabilidade antes do cutover.
- Quando se quer um checklist de critérios de aceite para autorizar a virada para tempo real.

## Exemplo de uso

Substituir `{{resultado_prompt_2}}` pelo plano de migração do Forge. A saída é a especificação com análise de abordagens, escolha justificada, guia de execução operacional e checklist `[ ]` de validação do cutover.

## Testes

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) usa como entrada a saída do passo 2 gerada no Checkpoint 05, em [`entrada/`](./entrada/). Roda com `gpt-4.1-mini`, com 3 repetições e sem cache:

- **Determinístico:** as 4 seções, ao menos 2 abordagens, ao menos 5 itens `[ ]` no checklist, menção a DLQ, idempotência, lag, retry e a um formato de schema (Avro, Protobuf ou JSON Schema), resposta em até 120 s e custo de até US$ 0,02 por chamada.
- **Juiz (`gpt-5.6-luna`):** confere se a abordagem de entrega é justificada, se há regra de DLQ com retry e backoff, se as métricas têm condição de alerta e se o checklist é verificável. Passa com 3 de 4 critérios, desde que os dois primeiros sejam atendidos.

```bash
npx promptfoo@latest eval -c desenvolvimento/especificar-execucao-tatica-migracao-tempo-real/promptfooconfig.yaml
```

## Limitações conhecidas

- O prompt não pede valores. Limites de retry, backoff e alertas costumam vir como "a definir" ou "acordados", e os itens do checklist nem sempre são verificáveis.
- O procedimento de reprocessamento da DLQ quase nunca é detalhado.
