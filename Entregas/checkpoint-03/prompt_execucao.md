
# Role
Você é um SRE Sênior especialista em observabilidade, troubleshooting de aplicações Java e administração avançada de clusters Elasticsearch monitorados via Cerebro.

# Contexto
Ocorreu um incidente de degradação/indisponibilidade em uma aplicação Java integrada a um cluster Elasticsearch. Para determinar a causa raiz, foram coletados três artefatos (snapshots) do período exato do problema:
1. Configuração do cluster via Cerebro.
2. Métricas do Cerebro (últimas 2 horas).
3. Trecho dos logs de um nó do cluster.

# Instruções de Processamento & Raciocínio (Chain of Thought)
Antes de gerar o relatório final, analise e correlacione rigorosamente os dados dos três artefatos seguindo os passos abaixo:

1. **Análise Individual dos Artefatos**:
   - Examine `<snapshot_config>`: Mapeie limites de memória Heap (JVM), garbage collector configurado, limites de thread pool (write/search), quantidade de shards e réplicas.
   - Examine `<snapshot_metricas>`: Mapeie comportamentos atípicos nas últimas 2 horas (picos de CPU, uso de Heap >85%, GC pauses, latência de indexação/busca, unassigned shards, thread pool rejections).
   - Examine `<snapshot_logs>`: Identifique erros críticos (`OutOfMemoryError`, `CircuitBreakingException`, `EsRejectedExecutionException`, `ClusterBlockException`, falhas de GC ou perdas de quórum).

2. **Matriz de Correlação Cruzada**:
   - Alinhe os timestamps dos logs com as oscilações de métricas nas últimas 2 horas.
   - Verifique se os limites definidos em `<snapshot_config>` foram atingidos no momento do pico de métricas ou do surgimento dos erros nos logs.

3. **Determinação da Causa Raiz**:
   - Separe a **Causa Raiz Primária** (ex: query Java sem paginação estourando o circuito de memória, Heap subdimensionado, sobrecarga de réplicas) dos **Sintomas Secundários** (ex: timeouts HTTP 504 na aplicação Java, GC pauses elevados).

---

# Seção de Snapshots (Injeção de Dados)

Insira os dados coletados abaixo dentro das respectivas tags XML:

<snapshot_config>
# cerebro.yaml — configuração do cluster Elasticsearch (repositório de infra)
cerebro:
  shards: 12
  replicas_per_shard: 1
  jvm_heap: 8g
  refresh_interval: 1s
  reindex_job:
    schedule: "0 2 * * *"     # roda todo dia às 02:00
    avg_duration_min: 90      # normalmente termina ~03:30
  query_cache:
    enabled: true
    size_mb: 512
</snapshot_config>

<snapshot_metricas>
timestamp              search_p99_ms   indexed_docs_per_s   heap_used_pct   cache_hit_pct
2026-05-13 08:00 UTC   850             4200                 61              74
2026-05-13 08:30 UTC   1100            4100                 68              71
2026-05-13 09:00 UTC   2300            9800                 79              58
2026-05-13 09:30 UTC   4100            11200                88              41
2026-05-13 10:00 UTC   6700            12400                94              29

</snapshot_metricas>

<snapshot_logs>
[2026-05-13T08:02:11,540][INFO ][o.e.t.LoggingTaskListener              ][cerebro-node-3] reindex task [88123] (scheduled 02:00) progress, created [3.8M]/[10M] docs (38%)
[2026-05-13T08:14:33,019][WARN ][o.e.m.j.JvmGcMonitorService            ][cerebro-node-3] [gc][young] duration [620ms], collections [1] in [10s], heap [4.9gb]->[3.1gb]/[8gb]
[2026-05-13T08:41:07,222][INFO ][o.e.i.IndexingMemoryController         ][cerebro-node-3] now throttling indexing for shard [logs-2026.05][7]: segment writing can't keep up
[2026-05-13T09:03:55,810][WARN ][o.e.t.ThreadPool                       ][cerebro-node-3] write thread pool queue at [150/200]
[2026-05-13T09:12:48,402][WARN ][o.e.m.j.JvmGcMonitorService            ][cerebro-node-3] [gc][old] duration [1.1s], collections [2] in [60s], heap [6.3gb]->[5.9gb]/[8gb]
[2026-05-13T09:20:02,118][INFO ][o.e.t.LoggingTaskListener              ][cerebro-node-3] reindex task [88123] (scheduled 02:00) progress, created [4.0M]/[10M] docs (40%)
[2026-05-13T09:31:17,653][WARN ][o.e.i.b.HierarchyCircuitBreakerService ][cerebro-node-3] [parent] usage [6.9gb/8gb] (86%), approaching limit
[2026-05-13T09:44:29,901][WARN ][o.e.s.SearchService                    ][cerebro-node-3] slow query on shard [logs-2026.05][7] took [2380ms]
[2026-05-13T09:51:08,377][WARN ][o.e.t.ThreadPool                       ][cerebro-node-3] write thread pool queue at [188/200]
[2026-05-13T09:58:41,102][WARN ][o.e.t.ThreadPool                       ][cerebro-node-3] write thread pool queue full [200/200], rejecting bulk — EsRejectedExecutionException
[2026-05-13T09:58:43,210][WARN ][o.e.m.j.JvmGcMonitorService            ][cerebro-node-3] [gc][old] duration [1.8s], collections [4] in [60s], heap [7.6gb]->[7.4gb]/[8gb]
[2026-05-13T09:58:44,005][INFO ][o.e.t.LoggingTaskListener              ][cerebro-node-3] reindex task [88123] (scheduled 02:00) still running, created [4.1M]/[10M] docs (41%), ETA unknown
[2026-05-13T09:58:45,889][WARN ][o.e.i.IndexingMemoryController         ][cerebro-node-3] indexing buffer above limit, throttling shard [logs-2026.05][7]
[2026-05-13T09:58:46,330][DEBUG][o.e.s.query.QueryPhase                 ][cerebro-node-3] shard [logs-2026.05][7] search took [5031ms] (timeout [5000ms])
[2026-05-13T09:58:46,512][ERROR][o.e.s.SearchService                    ][cerebro-node-3] search returned partial results: 11/12 shards succeeded
[2026-05-13T09:58:46,701][WARN ][o.e.i.b.HierarchyCircuitBreakerService ][cerebro-node-3] [parent] circuit breaker tripped, usage [7.7gb/8gb] (96%) over limit
[2026-05-13T09:58:47,001][WARN ][o.e.i.cache.query.IndicesQueryCache    ][cerebro-node-3] query cache eviction rate spiking, hit_ratio dropped to 0.29
[2026-05-13T10:01:12,778][ERROR][o.e.s.SearchService                    ][cerebro-node-3] CircuitBreakingException: [parent] Data too large, would be [7.9gb/8gb]
[2026-05-13T10:03:39,255][WARN ][o.e.t.ThreadPool                       ][cerebro-node-3] write thread pool rejected [1284] bulk requests in last 5min
[2026-05-13T10:05:50,640][ERROR][o.e.s.SearchService                    ][cerebro-node-3] all shards failed for index [logs-2026.05] on 3 of last 20 queries
</snapshot_logs>
---

# Formato de Saída (Relatório Estruturado de Causa Raiz)

Sua resposta DEVE seguir estritamente o modelo de relatório abaixo em Markdown:

# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo
- **Status do Cluster no Incidente**: [Ex: Crítico / Degradado / Indisponível]
- **Impacto na Aplicação Java**: [Breve descrição do sintoma na aplicação]
- **Causa Raiz Primária**: [Declaração direta e objetiva em 1-2 frases]
- **Nível de Severidade**: [Crítico / Alto / Médio]

## 2. Diagnóstico Técnico & Detalhamento da Falha
Explicação técnica aprofundada do mecanismo de falha no Elasticsearch/Java, justificando o diagnóstico com base nas métricas e registros dos logs.

## 3. Matriz de Correlação de Dados (Estruturada)
| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | [Ex: Heap de 4GB definido] | [Recomendado: 32GB] | [Subdimensionamento de memória] |
| **Métricas (2h)** | [Ex: GC Pause de 12s às 14:10] | [SLA < 200ms] | [Bloqueio das threads do cluster] |
| **Logs** | [Ex: `CircuitBreakingException`] | [Threshold de 95%] | [Rejeição de requisições da aplicação Java] |

## 4. Cronologia e Cadeia Causal do Incidente
- **[HH:MM] - Evento Desencadeador**: [Disparo da carga, query agressiva ou alteração]
- **[HH:MM] - Alteração de Métricas**: [Elevação de CPU, Heap ou Thread Pools no Cerebro]
- **[HH:MM] - Registro de Exceções**: [Primeiros erros registrados nos logs]
- **[HH:MM] - Efeito em Cascata**: [Efeito percebido pela aplicação Java (timeouts, rejections)]

## 5. Plano de Ação e Recomendações
### Ações Imediatas (Mitigação)
- [Ação de curto prazo com parâmetros de ajuste ou comandos]

### Ações Preventivas (Longo Prazo & Engenharia)
- [Melhorias de arquitetura, ajuste de Sizing, refatoração de queries na aplicação Java]