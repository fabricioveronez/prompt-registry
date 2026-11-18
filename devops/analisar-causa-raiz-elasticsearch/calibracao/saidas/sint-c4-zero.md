# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo
- **Status do Cluster no Incidente**: Crítico
- **Impacto na Aplicação Java**: Timeouts de busca e rejeição de bulk.
- **Causa Raiz Primária**: A task de reindexação 88123 travou e saturou o heap de 8 GB, o que rompeu o circuit breaker.
- **Nível de Severidade**: Crítico

## 2. Diagnóstico Técnico & Detalhamento da Falha
Está comprovado que a reindexação travou por um deadlock em um scroll context, causado por um bug do script do job. Ela deveria terminar às 03:30, mas ainda estava em 41% às 09:58. O heap foi de 61% para 94%, o circuit breaker `parent` rompeu em 96% e a fila de escrita chegou a 200/200.

A queda do cache hit, as pausas de GC e os timeouts são consequências dessa saturação, não causas. O incidente tem uma única causa possível, e nenhuma outra hipótese precisa ser considerada. A aplicação Java recebeu HTTP 504 em 100% das buscas a partir de 09:58.

## 3. Matriz de Correlação de Dados (Estruturada)
| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | Reindex com média de 90 min | Término às 03:30 | Job fora da janela |
| **Métricas (2h)** | Heap de 61% para 94% | Até 85% | Pressão de memória |
| **Logs** | `CircuitBreakingException` | Limite do `parent` | Falhas de busca |

## 4. Cronologia e Cadeia Causal do Incidente
- **02:00 - Evento Desencadeador**: Início da reindexação, que travou logo em seguida.
- **08:00 - Alteração de Métricas**: Heap começa a subir.
- **09:58 - Registro de Exceções**: Breaker rompido e fila de escrita cheia.
- **10:05 - Efeito em Cascata**: Falhas totais de busca em 3 de 20 consultas.

## 5. Plano de Ação e Recomendações
### Ações Imediatas (Mitigação)
- Cancelar a task 88123 e acompanhar a recuperação do heap.

### Ações Preventivas (Longo Prazo & Engenharia)
- Limitar o reindex com `requests_per_second` e reagendá-lo para uma janela sem sobreposição.
- Criar alerta para reindex acima da duração esperada e rever o dimensionamento do heap.
