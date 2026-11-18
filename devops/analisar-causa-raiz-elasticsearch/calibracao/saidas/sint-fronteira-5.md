# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo
- **Status do Cluster no Incidente**: Crítico
- **Impacto na Aplicação Java**: Timeouts de busca e rejeição de bulk.
- **Causa Raiz Primária**: A reindexação travada saturou o heap de 8 GB, levando ao rompimento do circuit breaker, a timeouts de busca e à queda do cache.
- **Nível de Severidade**: Crítico

## 2. Diagnóstico Técnico & Detalhamento da Falha
O job de reindexação deveria terminar às 03:30, mas ainda estava em 41% às 09:58. O heap foi de 61% para 94% e o circuit breaker `parent` rompeu em 96%.

Vários fatores atuaram juntos nessa degradação: o reindex, as pausas de GC, a baixa eficiência do cache e a fila de escrita cheia. Eles se reforçaram mutuamente, e o relatório os trata como fatores que contribuíram para o incidente.

Os logs vêm de um único nó, então podem existir outros fatores não visíveis aqui.

## 3. Matriz de Correlação de Dados (Estruturada)
| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | Reindex com média de 90 min | Término às 03:30 | Job fora da janela |
| **Métricas (2h)** | Heap de 61% para 94% | Até 85% | Pressão de memória |
| **Logs** | `CircuitBreakingException` | Limite do `parent` | Falhas de busca |

## 4. Cronologia e Cadeia Causal do Incidente
- **02:00 - Evento Desencadeador**: Início da reindexação.
- **08:00 - Alteração de Métricas**: Heap começa a subir e cache hit começa a cair.
- **09:58 - Registro de Exceções**: Breaker rompido e fila de escrita cheia.
- **10:05 - Efeito em Cascata**: Falhas de busca em 3 de 20 consultas.

## 5. Plano de Ação e Recomendações
### Ações Imediatas (Mitigação)
- Reiniciar o `cerebro-node-3` para liberar o heap e acompanhar o reindex.

### Ações Preventivas (Longo Prazo & Engenharia)
- Criar um alerta para heap acima de 85%.
