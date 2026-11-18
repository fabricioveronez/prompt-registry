---
nome: Diagnosticar Migração de Batch para Tempo Real
descricao: Analisa a documentação de um sistema em processamento em lote (Forge), mapeia gargalos e acoplamentos e compara caminhos arquiteturais para tempo real, com recomendação e bloco de exportação para o próximo passo.
versao: 1.1.1
tags: [arquitetura, batch, streaming, tempo-real, migração]
inputs:
  - nome: dados_do_sistema_e_ambiente
    descricao: Documentação e dados do sistema Forge e de seu ambiente (funcionamento do lote atual, volumetria, janelas de execução, dependências)
---

# Diagnosticar Migração de Batch para Tempo Real

## Objetivo

Dado o snapshot de documentação e ambiente do sistema Forge, o prompt assume o papel de Arquiteto Principal de Sistemas Distribuídos. Ele mapeia o estado atual do processamento em lote (volumetria, janelas, dependências), identifica gargalos e acoplamentos, avalia ao menos dois caminhos arquiteturais para tempo real (ex.: CDC/Debezium, Kafka/RabbitMQ, Flink/Spark, Webhooks/Serverless) e recomenda um deles. Entrega um relatório técnico em Markdown para tech leads, arquitetos e engenheiros do projeto.

## Quando usar

- Ao iniciar a avaliação da migração de um sistema em lote para arquitetura orientada a eventos ou streaming.
- Quando é preciso mapear gargalos e acoplamentos que impedem o tempo real.
- Quando se quer comparar caminhos arquiteturais com prós, contras e uma recomendação justificada.
- Como primeiro passo de uma cadeia de prompts, pois a saída inclui um bloco `<passo1_result>` para alimentar o próximo prompt.

## Exemplo de uso

Substituir `{{dados_do_sistema_e_ambiente}}` pela documentação e pelos dados do ambiente do sistema Forge. A saída é o relatório com mapeamento do estado atual (incluindo eventos por segundo e volume por hora, com o que não está na documentação marcado como **[estimativa]** ou lacuna), análise dos caminhos, recomendação técnica e o bloco de exportação.

## Testes

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) usa a documentação do Forge do Checkpoint 05 em [`entrada/`](./entrada/) com `gpt-4.1-mini`, com 3 repetições e sem cache:

- **Determinístico:** as 4 seções, ao menos 2 caminhos, o bloco `<passo1_result>` com conteúdo (o passo seguinte da cadeia depende dele), os dependentes Sentinel, Cerebro e Pepper citados, resposta em até 120 s e custo de até US$ 0,02 por chamada.
- **Juiz (`gpt-5.6-luna`):** confere se a recomendação é incremental e reversível, se a falha em cascata do lote aparece, se não há números de volumetria inventados e se a justificativa compara custo, complexidade, latência e impacto. Passa com 3 de 4 critérios, desde que a recomendação seja incremental e não invente números.

```bash
npx promptfoo@latest eval -c desenvolvimento/diagnosticar-migracao-batch-tempo-real/promptfooconfig.yaml
```

## Limitações conhecidas

- A versão 1.1.0 exigia números firmes de volumetria, sem "estimado". Como a documentação de exemplo não traz volumetria, o modelo inventava valores (ex.: 1.000 eventos/s) e o juiz reprovou o build. A versão 1.1.1 pede que todo número ausente da documentação seja marcado como estimativa, com a premissa. Ela também deixou de pedir o número de partições, que o modelo deduzia de "particionadas por hora" sem marcar.
- Latências típicas de uma tecnologia (ex.: "segundos" com streaming) às vezes aparecem sem a marca de estimativa. O juiz aceita, porque são ordens de grandeza, não dados do sistema.
- A entrada do teste é fixa. Ela não cobre sistemas diferentes do Forge.
