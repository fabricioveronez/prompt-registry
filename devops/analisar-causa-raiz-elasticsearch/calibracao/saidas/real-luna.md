# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo

- **Status do Cluster no Incidente**: **Crítico e degradado**, com rejeição de operações de escrita, resultados parciais de busca e falhas completas em parte das consultas.
- **Impacto na Aplicação Java**: A aplicação provavelmente sofreu aumento severo de latência, timeouts de busca e falhas em operações de indexação/bulk. Os logs também indicam respostas parciais e consultas sem sucesso em alguns momentos.
- **Causa Raiz Primária**: A execução prolongada do reindex iniciado às 02:00 manteve elevada a carga de indexação, provocando throttling, saturação do heap de 8 GB e esgotamento do thread pool de escrita. A pressão de memória culminou no acionamento do circuit breaker e na degradação das buscas.
- **Nível de Severidade**: **Crítico**

## 2. Diagnóstico Técnico & Detalhamento da Falha

O incidente apresenta uma cadeia consistente de saturação de recursos:

1. O job de reindexação iniciado às 02:00 deveria normalmente terminar por volta das 03:30, mas ainda estava em execução às 10:00, com somente 4,1 milhões de 10 milhões de documentos processados.
2. O volume de indexação aumentou de **4.200 para 12.400 documentos por segundo** entre 08:00 e 10:00.
3. A carga sustentada de escrita causou throttling no shard `logs-2026.05[7]`, registrado às 08:41, devido à incapacidade de a escrita de segmentos acompanhar a taxa de ingestão.
4. A fila do thread pool de escrita avançou de **150/200**, às 09:03, para **188/200**, às 09:51, até ficar completamente cheia às 09:58. Nesse ponto, o Elasticsearch passou a rejeitar operações bulk com `EsRejectedExecutionException`.
5. Paralelamente, o heap subiu de **61% para 94%** nas métricas agregadas. Nos logs, o uso do parent circuit breaker atingiu **86%** às 09:31 e **96%** às 09:58.
6. As pausas de GC evoluíram de uma pausa young de **620 ms** para pausas old de **1,1 s** e posteriormente **1,8 s**, com baixa recuperação do heap: de 7,6 GB para apenas 7,4 GB após a coleta.
7. A latência de busca aumentou de **850 ms para 6.700 ms no p99**, enquanto o cache de consultas caiu de **74% para 29%**. Esse comportamento indica perda de eficiência do cache sob pressão de memória e maior necessidade de execução efetiva das consultas.
8. Às 09:58, uma busca excedeu o timeout de 5 segundos, retornando apenas **11 de 12 shards**. Pouco depois, às 10:01, ocorreu `CircuitBreakingException`, impedindo a alocação adicional de memória para a busca.
9. Às 10:05, foram registradas falhas em todos os shards para **3 das últimas 20 consultas**, caracterizando degradação severa do serviço de busca.

Não há evidência, nos artefatos fornecidos, de `OutOfMemoryError`, perda de quórum, `ClusterBlockException` ou nós saindo do cluster. Portanto, o mecanismo observado foi contenção e proteção por circuit breaker, e não necessariamente uma indisponibilidade total por falha de processo.

A configuração informa heap de **8 GB**, 12 shards e uma réplica por shard. Isso representa até 24 cópias de shards no conjunto do cluster, aumentando o custo de indexação e manutenção, embora os dados fornecidos não permitam afirmar que a quantidade de réplicas, isoladamente, seja a causa principal. A configuração também não informa explicitamente o garbage collector nem os limites configurados dos thread pools de escrita e busca; o limite efetivo de 200 na fila de escrita foi observado nos logs.

## 3. Matriz de Correlação de Dados (Estruturada)

| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | Heap JVM de 8 GB; 12 shards; 1 réplica por shard; query cache de 512 MB; refresh interval de 1 s | O heap deve suportar simultaneamente indexação, buscas, buffers, cache e reindexação. O limiar exato do circuit breaker não foi informado na configuração | Heap limitado sob carga concorrente; o refresh de 1 s aumenta a frequência de trabalho de indexação e a existência de uma réplica amplia o custo de escrita |
| **Configuração** | Reindex agendado para 02:00, duração média esperada de 90 minutos | Execução esperada até aproximadamente 03:30 | O job ainda estava ativo às 10:00, indicando duração anormal e sobreposição prolongada com a carga operacional |
| **Configuração** | Garbage collector e limites explícitos dos thread pools não informados | Não é possível validar o GC ou comparar os limites configurados de search/write | A ausência desses parâmetros impede confirmar se havia tuning inadequado, mas os limites efetivos aparecem nos logs |
| **Métricas (2h)** | `search_p99_ms`: 850 ms às 08:00 para 6.700 ms às 10:00 | O SLA não foi fornecido; a tendência indica degradação severa | Correlaciona-se com GC elevado, saturação de heap, circuit breaker e perda de eficiência do cache |
| **Métricas (2h)** | `indexed_docs_per_s`: 4.200 para 12.400 | Não foi fornecido limite de ingestão sustentável | Aumento expressivo da escrita coincide com throttling e crescimento da fila do thread pool de escrita |
| **Métricas (2h)** | `heap_used_pct`: 61% para 94% | Pressão relevante acima de 85%; 94% representa condição crítica | Confirma a proximidade do limite de memória e antecede o acionamento do circuit breaker |
| **Métricas (2h)** | `cache_hit_pct`: 74% para 29% | Não foi fornecido SLA de cache | Mais consultas precisaram ser processadas, aumentando CPU/memória e contribuindo para a elevação da latência |
| **Logs** | GC young de 620 ms às 08:14; GC old de 1,1 s às 09:12 e 1,8 s às 09:58 | Não foi fornecido limite formal; pausas crescentes são anômalas para uma operação estável | Indica pressão crescente no heap e potencial bloqueio temporário das threads que atendem buscas e indexação |
| **Logs** | Throttling de indexação às 08:41 no shard `logs-2026.05[7]` | O shard não conseguia acompanhar a escrita de segmentos | Confirma que a capacidade de indexação foi excedida antes da saturação completa das filas |
| **Logs** | Fila de escrita em 150/200 às 09:03, 188/200 às 09:51 e 200/200 às 09:58 | Capacidade observada da fila: 200 tarefas | A fila cheia provocou `EsRejectedExecutionException` e falha de requisições bulk |
| **Logs** | Parent breaker em 6,9 GB/8 GB (86%) às 09:31 e 7,7 GB/8 GB (96%) às 09:58 | O limite efetivo foi ultrapassado às 09:58; o valor percentual exato configurado não está no snapshot | A memória disponível para novas operações tornou-se insuficiente, afetando buscas e indexação |
| **Logs** | Busca no shard levou 5.031 ms com timeout de 5.000 ms às 09:58 | Timeout da consulta: 5 s | A busca excedeu o limite operacional e retornou resultado parcial |
| **Logs** | `CircuitBreakingException` às 10:01 | Circuit breaker acionado para impedir consumo adicional de memória | Requisições de busca passaram a falhar em vez de apenas ficar lentas |
| **Logs** | 1.284 bulk requests rejeitados nos últimos 5 minutos às 10:03 | Rejeições deveriam ser próximas de zero em operação normal | Confirma impacto direto na ingestão e necessidade de retry/backoff na aplicação Java |
| **Logs** | Falha em todos os shards em 3 de 20 consultas às 10:05 | Não há evidência de indisponibilidade total do cluster | Serviço de busca permaneceu parcialmente funcional, porém em estado severamente degradado |

## 4. Cronologia e Cadeia Causal do Incidente

- **02:00 - Evento Desencadeador**: Início do job de reindexação agendado. A duração esperada era de aproximadamente 90 minutos, mas o job permaneceu ativo durante toda a janela observada.
- **08:02 - Carga prolongada confirmada**: O reindex havia criado 3,8 milhões de 10 milhões de documentos, demonstrando execução muito além da duração normal.
- **08:00–09:00 - Alteração de Métricas**: A taxa de indexação aumentou de 4.200 para 9.800 documentos por segundo. O heap subiu de 61% para 79% e o p99 de busca aumentou de 850 ms para 2.300 ms.
- **08:14 - Primeira evidência de pressão de memória**: GC young com pausa de 620 ms.
- **08:41 - Saturação de indexação**: O Elasticsearch ativou throttling no shard `logs-2026.05[7]` porque a escrita de segmentos não acompanhava a carga.
- **09:03–09:51 - Saturação progressiva do write pool**: A fila de escrita atingiu 150/200 e posteriormente 188/200. O heap chegou a 88% nas métricas de 09:30, enquanto a latência p99 alcançou 4.100 ms.
- **09:31 - Pressão crítica de memória**: O parent circuit breaker atingiu 86% de uso, próximo do limite operacional.
- **09:44 - Degradação de busca**: Consulta lenta no shard afetado, com duração de 2.380 ms.
- **09:58 - Ponto de ruptura**: A fila de escrita ficou cheia, gerando `EsRejectedExecutionException`. O GC old durou 1,8 s, o heap estava em 7,6 GB de 8 GB, uma busca excedeu o timeout de 5 segundos e o circuit breaker atingiu 96%.
- **09:58–10:01 - Efeito em cascata**: O cache de consultas caiu para 29%, a busca retornou apenas 11 de 12 shards e o `CircuitBreakingException` passou a bloquear novas alocações de memória.
- **10:03–10:05 - Impacto operacional máximo**: Foram contabilizadas 1.284 rejeições de bulk em cinco minutos e consultas com falha em todos os shards em 3 de 20 requisições.
- **Impacto na aplicação Java**: A aplicação consumidora teria recebido latências elevadas, respostas parciais, falhas de busca e rejeições de bulk. Timeouts HTTP, como 504, são uma consequência provável, mas não foram diretamente observados nos artefatos fornecidos.

## 5. Plano de Ação e Recomendações

### Ações Imediatas (Mitigação)

- **Suspender ou limitar temporariamente o reindex** `88123`, caso operacionalmente possível, para liberar capacidade de heap e escrita. Validar antes o impacto funcional da interrupção:
  ```http
  GET /_tasks?actions=*reindex&detailed=true
  POST /_tasks/<task_id>/_cancel
  ```
- **Reduzir temporariamente a taxa de ingestão e o tamanho dos bulks** na aplicação Java, aplicando backoff exponencial e respeitando `EsRejectedExecutionException`. Evitar retries agressivos, pois podem ampliar a fila.
- **Priorizar a recuperação do cluster**, pausando jobs de ingestão não essenciais e evitando novas operações de reindexação ou force merge durante a saturação.
- **Investigar imediatamente o shard `logs-2026.05[7]`**, incluindo distribuição, tamanho, segmentos e capacidade de escrita:
  ```http
  GET /_cluster/health/logs-2026.05?level=shards
  GET /_cat/shards/logs-2026.05?v
  GET /_nodes/stats/jvm,indices,thread_pool,breaker
  ```
- **Não aumentar indiscriminadamente o limite do circuit breaker**. O breaker está protegendo o nó contra esgotamento de memória; elevar o limite sem remover a causa pode transformar rejeições controladas em `OutOfMemoryError`.
- **Reduzir a concorrência de buscas pesadas**, aplicando limites de timeout, tamanho de página e agregações. Para paginação profunda, utilizar `search_after` com PIT quando aplicável.
- **Verificar a fila de requisições na aplicação Java** e separar os circuitos de ingestão e busca, evitando que retries de bulk prejudiquem o tráfego de leitura.
- **Validar a saúde global do cluster**, incluindo nós, shards primários/réplicas e eventuais shards não alocados:
  ```http
  GET /_cluster/health
  GET /_cluster/allocation/explain
  ```

### Ações Preventivas (Longo Prazo & Engenharia)

- **Reprojetar o reindex** para execução controlada: throttling explícito, batches menores, limitação de slices, janela operacional adequada e monitoramento de progresso. O job deve falhar ou alertar quando exceder sua duração esperada de 90 minutos.
- **Revisar o sizing do heap e da memória do nó**. O heap de 8 GB mostrou-se insuficiente para a combinação observada de reindexação, ingestão, buscas, buffers e cache. Qualquer aumento deve considerar a memória física disponível, o limite recomendado para compressed ordinary object pointers e a memória necessária fora do heap.
- **Dimensionar o cluster pela carga de escrita e leitura**, considerando o custo adicional da réplica. Avaliar mais nós, melhor distribuição de shards e capacidade de I/O antes de simplesmente aumentar heap.
- **Revisar o `refresh_interval` de 1 s** durante cargas massivas. Para reindexações controladas, pode ser vantajoso aumentar temporariamente o intervalo ou desabilitar refresh durante a carga, desde que a consistência de leitura e o procedimento de recuperação sejam avaliados.
- **Reavaliar o query cache de 512 MB** e sua política de uso. O cache não deve ser utilizado como substituto de dimensionamento de heap; investigar as consultas com baixa reutilização e a elevada taxa de eviction.
- **Otimizar as consultas da aplicação Java**: evitar retorno de documentos desnecessários, limitar `_source`, eliminar agregações excessivamente amplas, implementar paginação adequada e evitar buscas profundas com `from/size`.
- **Configurar observabilidade e alertas** para heap acima de 85%, old GC, latência p99, queue/rejected do `write` e `search`, circuit breakers, cache hit ratio, tempo de reindex e shards não alocados.
- **Definir limites de concorrência e filas na aplicação**, com bulk sizing, rate limiting, retry com jitter e circuit breaker no cliente Java.
- **Executar testes de carga e chaos testing** reproduzindo simultaneamente reindexação, ingestão e buscas, validando que o cluster permaneça abaixo dos limites de heap, GC e thread pools.
- **Documentar explicitamente a configuração do garbage collector e dos thread pools**. Esses parâmetros não estavam presentes no snapshot e devem ser coletados para permitir diagnóstico completo em futuros incidentes.