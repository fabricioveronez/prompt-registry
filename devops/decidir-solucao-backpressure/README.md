---
nome: Decidir Solução para Backpressure
descricao: Analisa um cenário de backpressure em sistemas distribuídos e compara caminhos de solução, entregando um relatório de trade-offs com recomendação e plano de implementação.
versao: 1.0.0
tags: [backpressure, resiliência, sre, mensageria, trade-offs]
inputs:
  - nome: snapshot_cenario
    descricao: Dados do cenário do problema (arquitetura atual, métricas, gargalo e comportamento de produtores e consumidores)
  - nome: snapshot_caminhos
    descricao: Lista dos caminhos possíveis (soluções viáveis propostas) para tratar o problema
---

# Decidir Solução para Backpressure

## Objetivo

Dado um snapshot do cenário do problema (arquitetura, métricas, gargalo, comportamento de produtores e consumidores) e um snapshot com os caminhos de solução viáveis, o prompt assume o papel de Arquiteto de Sistemas Distribuídos e SRE Sênior. Ele diagnostica o gargalo, avalia cada caminho (mecanismo, prós, contras, complexidade, riscos), compara os trade-offs e recomenda uma solução, ou uma combinação híbrida priorizada, em um relatório Markdown estruturado.

## Quando usar

- Quando há backpressure em filas, mensageria ou pipelines de dados e existem várias soluções candidatas (rate limiting, buffering, load shedding etc.).
- Quando é preciso justificar uma decisão técnica com comparação explícita de custo, esforço, impacto na latência e manutenção.
- Quando se quer um plano de implementação com critério de validação ao final da análise.

## Exemplo de uso

Substituir `{{snapshot_cenario}}` pela descrição da arquitetura, métricas e comportamento de produtores e consumidores, e `{{snapshot_caminhos}}` pela lista de soluções viáveis. A saída é o relatório com as seções: análise do cenário, avaliação dos caminhos, matriz de trade-offs, recomendação e plano de implementação.

## Testes

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) roda o cenário do Relay em [`entrada/`](./entrada/) (o mesmo do Checkpoint 04) com `gpt-4.1-mini`, com 3 repetições e sem cache:

- **Determinístico:** as 5 seções do relatório, os 4 caminhos do snapshot avaliados, a matriz com uma linha por caminho, a escolha marcada com 🏆, resposta em até 60 s e custo de até US$ 0,01 por chamada.
- **Juiz (`gpt-5.6-luna`):** confere se a recomendação protege o SLA de 60 s do Sentinel, não aceita perda de telemetria, trata o orçamento estourado e usa os números do cenário. Passa com 3 de 4 critérios, desde que os dois primeiros sejam atendidos.

```bash
npx promptfoo@latest eval -c devops/decidir-solucao-backpressure/promptfooconfig.yaml
```

## Limitações conhecidas

- Nos testes, o modelo escolhe sempre "priorizar o Sentinel" e raramente usa a retenção de 4h na justificativa. Por isso o juiz fica em 3 de 4 critérios.
- Uma instrução no prompt para aceitar descarte de mensagens foi ignorada pelo modelo, porque o cenário proíbe perda. O teste mede a saída, não o texto do prompt, então uma mudança desse tipo só reprova se piorar a resposta.
- O teste usa um único cenário. Outro cenário exige outra entrada e outra rubrica.
