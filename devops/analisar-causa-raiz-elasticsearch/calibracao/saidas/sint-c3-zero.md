# Relatório de Análise de Causa Raiz (RCA)

## 1. Resumo Executivo
- **Status do Cluster no Incidente**: Crítico
- **Impacto na Aplicação Java**: Timeouts de busca e rejeição de bulk.
- **Causa Raiz Primária**: A reindexação travada (38% às 08:02 e 41% às 09:58) saturou o heap de 8 GB, o que rompeu o circuit breaker.
- **Nível de Severidade**: Crítico

## 2. Diagnóstico Técnico & Detalhamento da Falha
O job deveria terminar às 03:30, mas quase não avançou em duas horas. Nesse período, o heap foi de 61% para 94% e o circuit breaker `parent` rompeu em 96%. A queda do cache hit, as pausas de GC e os timeouts são consequências da saturação, não causas.

Os dados não permitem concluir por que o reindex travou nem explicam por que a indexação foi a 12400 docs/s, já que o reindex avançou pouco. Os logs são de um único nó e não há dados da aplicação Java, então o impacto nela é inferido.

## 3. Matriz de Correlação de Dados (Estruturada)
| Artefato / Parâmetro | Evidência / Métrica Observada | Limite Configurável / Esperado | Impacto Cruzado |
| :--- | :--- | :--- | :--- |
| **Configuração** | Reindex com média de 90 min | Término às 03:30 | Job fora da janela |
| **Métricas (2h)** | Heap de 61% para 94% | Até 85% | Pressão de memória |
| **Logs** | `CircuitBreakingException` | Limite do `parent` | Falhas de busca |

## 4. Cronologia e Cadeia Causal do Incidente
- **02:00 - Evento Desencadeador**: Início da reindexação.
- **08:00 - Alteração de Métricas**: Heap começa a subir.
- **09:58 - Registro de Exceções**: Breaker rompido e fila de escrita cheia.
- **10:05 - Efeito em Cascata**: Falhas de busca em 3 de 20 consultas.

## 5. Plano de Ação e Recomendações
### Ações Imediatas (Mitigação)
- Abrir um projeto para substituir o Elasticsearch por outra plataforma de busca.

### Ações Preventivas (Longo Prazo & Engenharia)
- Triplicar a quantidade de nós do cluster e migrar todos os índices para um novo ambiente multirregião.
- Reescrever a camada de acesso a dados da aplicação Java.
