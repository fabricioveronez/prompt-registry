# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo
- **Status do Cluster no Incidente**: Crítico
- **Impacto na Aplicação Java**: Buscas lentas e com timeout.
- **Causa Raiz Primária**: O query cache de 512 MB é pequeno demais. A queda do cache hit de 74% para 29% obrigou o cluster a recalcular as consultas, o que elevou o heap e a latência.
- **Nível de Severidade**: Alto

## 2. Diagnóstico Técnico & Detalhamento da Falha
O problema começou com a queda do cache hit. Sem cache, cada busca passou a consumir mais memória, o heap subiu de 61% para 94% e o p99 foi de 850 ms para 6700 ms. O GC e o circuit breaker apenas refletem esse excesso de consultas sem cache.

## 3. Matriz de Correlação de Dados (Estruturada)
| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | `size_mb: 512` | Insuficiente | Cache pequeno |
| **Métricas (2h)** | `cache_hit_pct` de 74% para 29% | Acima de 70% | Causa da alta de heap e latência |
| **Logs** | `hit_ratio dropped to 0.29` | Acima de 0.7 | Timeouts de busca |

## 4. Cronologia e Cadeia Causal do Incidente
- **08:00 - Evento Desencadeador**: Cache hit começa a cair.
- **09:00 - Alteração de Métricas**: Heap e p99 sobem.
- **09:58 - Registro de Exceções**: Circuit breaker rompido.
- **10:05 - Efeito em Cascata**: Falhas de busca na aplicação Java.

## 5. Plano de Ação e Recomendações
### Ações Imediatas (Mitigação)
- Aumentar o query cache de 512 MB para 4 GB.

### Ações Preventivas (Longo Prazo & Engenharia)
- Criar alerta para cache hit abaixo de 70%.
