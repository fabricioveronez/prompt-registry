---
nome: Analisar Causa Raiz de Incidente Elasticsearch
descricao: Correlaciona configuração, métricas (2h) e logs de um cluster Elasticsearch via Cerebro e entrega um relatório RCA de incidente que afetou uma aplicação Java
versao: 1.0.0
tags: [sre, elasticsearch, rca, observabilidade, java]
inputs:
  - nome: snapshot_config
    descricao: Dados de configuração do cluster Elasticsearch coletados via Cerebro (heap, GC, thread pools, shards e réplicas)
  - nome: snapshot_metricas
    descricao: Métricas do Cerebro das últimas 2 horas do período do incidente
  - nome: snapshot_logs
    descricao: Trechos de logs de um nó do cluster Elasticsearch / Cerebro do período do incidente
---

# Analisar Causa Raiz de Incidente Elasticsearch

## Objetivo

Determinar a causa raiz de um incidente de degradação ou indisponibilidade de uma aplicação Java integrada a um cluster Elasticsearch. O prompt correlaciona três artefatos do período do problema (configuração do cluster, métricas das últimas 2 horas e logs de um nó, todos via Cerebro) e entrega um relatório RCA estruturado. O relatório separa a causa raiz primária dos sintomas secundários e traz cronologia, matriz de correlação e plano de ação.

## Quando usar

- Após um incidente em que uma aplicação Java degradou ou ficou indisponível e há suspeita do cluster Elasticsearch.
- Quando já se têm a configuração do cluster, as métricas das últimas 2 horas e logs de um nó.
- Para produzir um RCA com estrutura fixa, útil em postmortems.
- Para correlacionar timestamps de logs com oscilações de métricas (Heap, GC, thread pools).

## Exemplo de uso

Os snapshots do incidente de exemplo estão em [`incidente/`](./incidente/), e um relatório real gerado a partir deles está em [`calibracao/saidas/real-luna.md`](./calibracao/saidas/real-luna.md).

## Gate de qualidade

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) testa o prompt em duas camadas, com 3 repetições e sem cache:

- **Determinística:** formato do relatório, latência e custo.
- **Juiz LLM:** aplica a [`rubrica-juiz.txt`](./rubrica-juiz.txt), com 4 critérios de 0 a 2. A saída passa com total de pelo menos 6 e nenhum critério zerado.

Rode a partir da raiz do repositório:

```bash
npx promptfoo@latest eval -c devops/analisar-causa-raiz-elasticsearch/promptfooconfig.yaml
```

Qualquer reprovação termina com exit code 100. Sempre que `rubrica-juiz.txt` mudar, recalibre o juiz:

```bash
npx promptfoo@latest eval -c devops/analisar-causa-raiz-elasticsearch/calibracao/promptfooconfig.yaml --no-cache --repeat 5 -o resultado-calibracao.json
node devops/analisar-causa-raiz-elasticsearch/calibracao/comparar.cjs resultado-calibracao.json
```

Na calibração, é normal o primeiro comando terminar com exit 100, porque algumas saídas devem reprovar. Quem decide o resultado é o `comparar.cjs`, que compara o juiz com o [`gabarito.json`](./calibracao/gabarito.json).

## Limitações conhecidas

- O prompt não pede que os limites dos dados sejam declarados. Nos testes, as saídas passaram no gate, mas com nota parcial em honestidade epistêmica.
- A rubrica e o gabarito são específicos do incidente de exemplo. Para testar outro incidente, é preciso escrever outra rubrica e calibrar de novo.
