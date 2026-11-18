# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo
- **Status do Cluster no Incidente**: Crítico
- **Impacto na Aplicação Java**: Timeouts de busca, resultados parciais e rejeição de bulk. O impacto é inferido dos logs do cluster, pois não há dados da aplicação.
- **Causa Raiz Primária**: A reindexação 88123 travou (38% às 08:02 e 41% às 09:58) e permaneceu ativa fora da janela. A hipótese mais forte é que ela saturou o heap de 8 GB, levando ao circuit breaker, aos timeouts de busca e à queda do cache.
- **Nível de Severidade**: Crítico

## 2. Diagnóstico Técnico & Detalhamento da Falha
O job deveria terminar às 03:30, mas avançou só 3% em quase duas horas. Nesse período, o heap foi de 61% para 94% e, às 09:58, o breaker `parent` rompeu em 96% e a fila de escrita chegou a 200/200.

**Causa**: a reindexação travada ocupando recursos. **Consequências**: pausas de GC, queda do cache hit de 74% para 29% (eviction sob pressão de memória), timeouts de busca e rejeição de bulk. A queda do cache piora a latência, mas é efeito da pressão, não sua origem.

**O que os dados não permitem concluir**:
- Por que o reindex travou: não há logs do job nem do índice de origem.
- A origem do aumento para 12400 docs/s: o reindex criou cerca de 0,3M de documentos em duas horas, ou cerca de 43 docs/s, então ele não explica esse volume. Pode haver outra carga de ingestão.
- Se os demais nós sofreram o mesmo: os logs são só do `cerebro-node-3`.

## 3. Matriz de Correlação de Dados (Estruturada)
| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | Reindex com média de 90 min | Término às 03:30 | Job fora da janela |
| **Métricas (2h)** | Heap de 61% para 94% | Até 85% | Pressão de memória |
| **Logs** | `CircuitBreakingException` | Limite do `parent` | Falhas de busca |

## 4. Cronologia e Cadeia Causal do Incidente
- **02:00 - Evento Desencadeador**: Início da reindexação, que não termina até 03:30.
- **08:00 - Alteração de Métricas**: Heap e p99 sobem, e o cache hit cai.
- **09:58 - Registro de Exceções**: Breaker rompido e fila de escrita cheia.
- **10:05 - Efeito em Cascata**: Falhas de busca em 3 de 20 consultas.

## 5. Plano de Ação e Recomendações
### Ações Imediatas (Mitigação)
- Cancelar a task 88123 e confirmar se o heap recua. Se não recuar, a hipótese precisa ser revista e a origem dos 12400 docs/s deve ser investigada.

### Ações Preventivas (Longo Prazo & Engenharia)
- Limitar o reindex com `requests_per_second`, reagendá-lo para uma janela sem sobreposição e alertar quando passar da duração esperada.
- Rever heap e limites depois de medir a carga real, sem aumentar o limite do breaker antes disso.
