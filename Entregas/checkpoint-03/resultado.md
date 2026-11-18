# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo
- **Status do Cluster no Incidente**: Crítico — circuit breaker de memória (`parent`) rompido, com falhas de busca e rejeição massiva de bulk requests.
- **Impacto na Aplicação Java**: Timeouts de busca (consultas excedendo 5000ms), respostas parciais (11/12 shards) e falhas completas em parte das queries, além de rejeição de escritas em lote — sintomas típicos de HTTP 504/503 percebidos pela aplicação.
- **Causa Raiz Primária**: O job de reindex agendado (`task 88123`, início 02:00, duração média esperada de 90 min) não terminou no horário previsto (~03:30) e permaneceu em execução até pelo menos 10:05, sobrepondo-se ao início do horário comercial. Essa execução anômala e prolongada, somada ao `refresh_interval` agressivo de 1s, saturou o heap JVM de 8GB e a fila de escrita, rompendo o circuit breaker de memória do cluster.
- **Nível de Severidade**: Crítico

## 2. Diagnóstico Técnico & Detalhamento da Falha

O `cerebro.yaml` define um heap JVM de 8GB para o nó, `refresh_interval` de 1s (bastante agressivo — refresh forçado de segmentos Lucene a cada segundo, o que aumenta significativamente o custo de I/O e memória sob carga de indexação intensa) e um job de reindex noturno com duração média esperada de 90 minutos, programado para concluir por volta das 03:30.

O primeiro log relevante (08:02:11) já mostra a tarefa 88123 em apenas 38% de progresso — ou seja, 4h30min além do horário previsto de término, o job continuava ativo e consumindo recursos de indexação. Esse é o evento anômalo que dá início à cadeia causal: o reindex não terminou dentro do SLA implícito e passou a competir por heap e threads de escrita com o tráfego normal de indexação e busca que cresce naturalmente no início do horário comercial.

Como consequência, entre 08:00 e 10:00 as métricas mostram uma degradação progressiva e consistente: `heap_used_pct` sobe de 61% para 94%, `indexed_docs_per_s` quase triplica (4200 → 12400, reflexo do reindex somado ao tráfego real), `search_p99_ms` dispara de 850ms para 6700ms, e o `cache_hit_pct` desaba de 74% para 29% (evicção de cache sob pressão de memória).

Os logs confirmam a mecânica da falha em cascata:
- **08:41** — `IndexingMemoryController` já precisa throttlar a indexação do shard `[logs-2026.05][7]`, primeiro sinal formal de saturação.
- **09:03–09:51** — a fila do thread pool de escrita cresce progressivamente (150/200 → 188/200), enquanto pausas de GC old aumentam em duração (1.1s → 1.8s) sem conseguir liberar heap de forma eficaz (7.6GB → 7.4GB, uma liberação mínima), evidenciando pressão de memória real e não apenas transitória.
- **09:58:41** — a fila de escrita atinge o limite (200/200) e passam a ocorrer `EsRejectedExecutionException`, rejeitando bulk requests da aplicação Java.
- **09:58:46** — uma busca excede o timeout (5031ms > 5000ms configurado), o `SearchService` retorna resultados parciais (11/12 shards) e o circuit breaker `[parent]` rompe oficialmente em 96% de uso (7.7GB/8GB).
- **10:01:12** — `CircuitBreakingException: Data too large, would be [7.9gb/8gb]` confirma que novas alocações de memória passaram a ser bloqueadas preventivamente pelo próprio Elasticsearch.
- **10:03:39 e 10:05:50** — o efeito se consolida: 1284 bulk requests rejeitados em 5 minutos e falha completa em parte das queries (3 de 20).

Em resumo, o mecanismo de falha é um **efeito cascata clássico de saturação de heap**: reindex fora do SLA + `refresh_interval` agressivo → pressão contínua de memória → GC incapaz de acompanhar → circuit breaker rompido → rejeição de threads de escrita e leitura → erros percebidos pela aplicação Java.

## 3. Matriz de Correlação de Dados (Estruturada)

| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | Reindex `task 88123` agendado às 02:00, `avg_duration_min: 90` | Término esperado ~03:30 | Job ainda em 38–41% entre 08:02 e 09:58 — execução 5–8x mais longa que o previsto, colidindo com o horário comercial |
| **Configuração** | `refresh_interval: 1s` | Padrão ES é 1s, mas agressivo sob indexação pesada simultânea | Amplifica overhead de refresh/merge de segmentos Lucene durante o pico de indexação do reindex |
| **Configuração** | `jvm_heap: 8g` | Circuit breaker `parent` padrão ≈95% do heap (≈7.6GB) | Heap atingiu 94% (métricas) e o breaker rompeu em 96%/7.7GB (logs) — dimensionamento insuficiente para reindex + tráfego concorrente |
| **Métricas (2h)** | `heap_used_pct` sobe de 61% → 94% (08:00–10:00) | Zona de alerta recomendada: >85% | Correlaciona diretamente com o aumento das pausas de GC e o rompimento do circuit breaker às 09:58 |
| **Métricas (2h)** | `search_p99_ms` sobe de 850ms → 6700ms; `cache_hit_pct` cai de 74% → 29% | SLA típico de busca: p99 < 1000ms | Evicção de cache sob pressão de memória agrava ainda mais a latência de busca |
| **Logs** | `EsRejectedExecutionException` (fila write 200/200, 09:58:41) e `CircuitBreakingException` (09:58:46 e 10:01:12) | Fila de escrita: 200; breaker: ~95% do heap | Rejeição de bulk requests e bloqueio de buscas — origem direta dos timeouts/504 na aplicação Java |

## 4. Cronologia e Cadeia Causal do Incidente
- **02:00 — Evento Desencadeador**: Job de reindex `88123` disparado conforme agendamento, com duração média esperada de 90 minutos (término previsto ~03:30).
- **08:02–09:20 — Job fora do SLA**: Logs mostram o reindex ainda em 38% (08:02) e 40% (09:20), muito além do horário de conclusão esperado, indicando execução anômala/travada que se estende pelo horário comercial.
- **08:14–09:51 — Alteração de Métricas**: `heap_used_pct` sobe de 61% para 88%; pausas de GC evoluem de young (620ms) para old (1.1s–1.8s) sem liberação efetiva de memória; fila do thread pool de escrita cresce de vazia até 188/200; throttling de indexação inicia às 08:41.
- **09:31–09:58 — Registro de Exceções**: Circuit breaker se aproxima do limite (86%, 09:31); queries lentas aparecem (2380ms, depois 5031ms); às 09:58:41 a fila de escrita satura (200/200) gerando `EsRejectedExecutionException`; às 09:58:46 o circuit breaker rompe oficialmente (96%) e uma busca retorna resultado parcial (11/12 shards).
- **10:01–10:05 — Efeito em Cascata**: `CircuitBreakingException` explícita às 10:01:12; 1284 bulk requests rejeitados em 5 minutos às 10:03:39; falha completa em 3 de 20 queries às 10:05:50 — a aplicação Java passa a receber timeouts de busca e falhas de escrita em massa.

## 5. Plano de Ação e Recomendações

### Ações Imediatas (Mitigação)
- Cancelar manualmente a tarefa de reindex travada: `POST _tasks/88123/_cancel` para liberar heap e a fila de escrita imediatamente.
- Aumentar temporariamente o `refresh_interval` do índice `logs-2026.05` (ex.: para `30s`) enquanto durar qualquer job de reindex, reduzindo overhead de segmentos.
- Monitorar a recuperação do heap após o cancelamento; se não recuperar, avaliar restart controlado do `cerebro-node-3` como último recurso.
- Aplicar backpressure temporário na aplicação Java (retry com backoff exponencial) para requisições que estejam recebendo `EsRejectedExecutionException`/`CircuitBreakingException`, evitando amplificar a carga durante a recuperação.

### Ações Preventivas (Longo Prazo & Engenharia)
- Adicionar throttling explícito ao job de reindex via parâmetro `requests_per_second` da Reindex API, evitando que ele compita livremente por recursos com tráfego de produção.
- Criar alerta de SLA para jobs agendados: disparar aviso se a execução ultrapassar, por exemplo, 150% do `avg_duration_min` configurado (135 min neste caso).
- Reavaliar o dimensionamento do heap JVM (considerando RAM física disponível, respeitando o teto de ~50% da RAM e o limite prático de ~31GB para compressed oops) para suportar picos de reindex + tráfego concorrente.
- Revisar a real necessidade de `refresh_interval: 1s` para esse índice, avaliando aumento do intervalo para reduzir custo de merge/refresh sob carga.
- Refatorar a aplicação Java para tratar `CircuitBreakingException` e `EsRejectedExecutionException` com retry/backoff e, quando aplicável, paginação (scroll/search_after) em vez de buscas que agravem o uso de memória.
- Considerar isolar jobs de reindex em nó(s) dedicado(s) ou usar reindex remoto com throttling, evitando concorrência direta com o nó que serve tráfego de produção.
