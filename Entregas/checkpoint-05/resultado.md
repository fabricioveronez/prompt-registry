# Especificação Tática e Detalhes da Execução: Projeto Forge

## 1. Padrões de Implementação e Resiliência

### Abordagem A: At-least-once com Idempotência no Sink (effectively-once)

O Spark lê do Relay com checkpoint e pode reentregar eventos após falha ou reinício. A deduplicação acontece na escrita, com `MERGE`/upsert por chave determinística (`event_id`, ou hash de `source + partition + offset` quando não houver ID).

- **Prós:**
  - Funciona com qualquer Relay que ofereça offsets replayáveis, sem exigir transações no broker. Isso importa porque a tecnologia e a retenção do Relay ainda são pendências da Fase 1.
  - Reprocessar um intervalo (backfill, correção de late data) é seguro, porque reexecutar o mesmo lote produz o mesmo estado final.
  - O mesmo código roda em batch e streaming, e a idempotência é a propriedade que permite essa unificação.
  - A falha de micro-batch se resolve retomando do último checkpoint, sem intervenção manual.
  - O rollback por feature flag não deixa lixo, pois as tabelas `*_stream` são independentes do batch.
- **Contras:**
  - `MERGE` por chave é mais caro que `append` e gera mais reescrita de arquivos, o que pressiona o problema de small files.
  - Exige formato transacional no warehouse (Delta/Iceberg/Hudi). Se o warehouse for nativo sem merge transacional, a abordagem precisa de adaptação.
  - A chave de deduplicação precisa ser estável e única. Uma chave mal definida causa perda silenciosa ou duplicidade.
  - Há uma janela transitória em que duplicatas existem antes da deduplicação, o que exige que os consumidores leiam apenas dados já publicados.
  - A deduplicação em streaming (`dropDuplicatesWithinWatermark`) acumula estado, que precisa ser dimensionado e limitado pelo watermark.

### Abordagem B: Exactly-once Transacional Ponta a Ponta

Combina leitura com offsets controlados, escrita transacional atômica (commit do batch de dados e do offset na mesma transação, ou escrita idempotente por `txnAppId`/`txnVersion`) e, se aplicável, produtores transacionais no Relay.

- **Prós:**
  - Elimina duplicidade por construção no caminho de dados, com a menor chance de divergência na reconciliação do billing.
  - A visibilidade atômica por commit reforça o contrato de partição consistente para Sentinel e Pepper.
  - Menos lógica de deduplicação no consumidor.
- **Contras:**
  - Depende de capacidades que ainda não estão confirmadas (suporte transacional do Relay e do warehouse). Na prática, "exactly-once" costuma valer só dentro do par Spark + sink, e não ponta a ponta.
  - Maior acoplamento ao formato do warehouse e à versão do engine, o que dificulta trocar de tecnologia.
  - Falhas fora do escopo transacional (efeitos colaterais como a indexação do Cerebro) continuam exigindo idempotência no consumidor, então o ganho é parcial.
  - Throughput e latência de commit são piores, e a depuração de transações presas é mais complexa.
  - Reprocessamentos fora da ordem original (backfill) são mais difíceis de encaixar no modelo de offsets transacionais.

## 2. Escolha da Abordagem e Justificativa

- **Melhor Escolha:** **Abordagem A (At-least-once com idempotência no sink)**. O sink usa commit transacional, aproveitando o que o warehouse oferecer da Abordagem B (escrita atômica por micro-batch), sem depender de exactly-once no Relay.
- **Justificativa:**
  - **Integridade dos dados:** a correção vem de uma propriedade que podemos provar e testar na Fase Shadow (reexecutar o mesmo intervalo e obter o mesmo resultado), em vez de uma garantia herdada de componentes ainda não confirmados. A reconciliação com divergência zero no billing valida o resultado de forma objetiva.
  - **Complexidade:** menor dependência de capacidades desconhecidas do Relay. A idempotência também atende ao Cerebro (indexação por ID de evento), onde o exactly-once do pipeline não ajudaria.
  - **Alinhamento com a estratégia:** a idempotência sustenta o código único batch/stream, o backfill e o rollback por flag definidos no plano.
  - **Condição de revisão:** se na Fase 1 o Relay e o warehouse confirmarem suporte transacional pleno e o custo de `MERGE` se mostrar inviável (small files, latência), reavaliar a Abordagem B apenas para as tabelas de maior volume.

## 3. Guia de Execução Operacional

### Contratos de Eventos / Schemas

- **Formato recomendado:** **Avro com Schema Registry** se o Relay for baseado em Kafka ou similar. Protobuf é alternativa válida se o ecossistema já o usa. Use **JSON Schema** apenas se o Relay transportar JSON e a migração de formato for inviável agora. Confirmar na Fase 1.
- **Campos obrigatórios do envelope:** `event_id` (único e determinístico), `event_time` (usado para watermark e partição horária), `ingest_time`, `source`, `schema_version`.
- **Compatibilidade:** modo `BACKWARD` (ou `FULL` para tabelas consumidas pela Pepper). Só adicionar campos opcionais com default; proibido remover ou renomear campos sem versão nova.
- **Validação:** checar o schema na entrada do pipeline. Registros inválidos vão para a DLQ, nunca descartados em silêncio.
- **Testes de contrato:** executar no CI contra Sentinel, Cerebro e Pepper antes de cada mudança de schema. Para Sentinel e Pepper, incluir teste de que apenas partições fechadas por watermark são visíveis.
- **Congelamento:** nenhuma mudança de schema ou lógica durante a virada de cada consumidor.

### Tratamento de Erros e Filas de Exceção

- **Classificação dos erros:**
  - *Transitórios* (timeout, indisponibilidade do Relay ou do warehouse, conflito de commit): retry.
  - *Permanentes* (schema inválido, campo obrigatório ausente, falha de parsing): DLQ, sem retry.
  - *Fatais* (corrupção de checkpoint, perda de estado): alerta de severidade alta e runbook.
- **Retry exponencial:** backoff com jitter (por exemplo, base de 1–2 s, fator 2, teto de 1–5 min, 5 a 8 tentativas). Valores finais a calibrar no shadow. Esgotadas as tentativas, o registro ou lote segue para a DLQ.
- **DLQ:** armazenar o payload original, o motivo do erro, o `schema_version`, o offset/partição de origem e o timestamp, em tabela ou tópico dedicado e retido além da retenção do Relay.
- **Reprocessamento da DLQ:** job controlado e idempotente que reaplica os registros corrigidos. Cada reprocessamento é registrado e reconciliado.
- **Falha de micro-batch:** o job retoma do último checkpoint. Se o lag ou o SLA de frescor for violado, reverter a flag do consumidor para o batch.
- **Política de limite:** se a taxa da DLQ ultrapassar o limite acordado, o consumidor não avança para o cutover, pois o dado ausente comprometeria a reconciliação.

### Plano de Observabilidade

| Métrica | O que mede | Alerta sugerido (calibrar no shadow) |
|---|---|---|
| **Lag do consumidor** | Offsets pendentes e tempo de atraso em relação ao Relay | Lag crescente por N micro-batches consecutivos |
| **Latência ponta a ponta** | `ingest_time` até a disponibilidade na tabela/visão publicada | Acima do SLA definido na Fase 1 |
| **Frescor do dado** | Idade da última partição publicada por watermark | Partição horária não publicada após o prazo esperado |
| **Vazão de eventos** | Eventos/s lidos, processados e gravados | Queda brusca ou desvio da linha de base |
| **Erros por segundo** | Falhas de parsing, validação e escrita; taxa da DLQ | Acima do limite acordado por consumidor |
| **Duração do micro-batch** | Tempo de processamento versus o trigger | Duração próxima ou acima do intervalo de trigger |
| **Volume de estado** | Tamanho do estado de deduplicação e agregações | Crescimento contínuo (watermark mal ajustado) |
| **Small files** | Contagem e tamanho médio de arquivos por partição | Média abaixo do alvo, disparar compactação |
| **Divergência da reconciliação** | Diferença batch vs. stream por contagem, checksum e chave | Qualquer divergência no billing; acima da tolerância nos demais |
| **Late data** | Volume de eventos descartados ou reprocessados por chegada tardia | Acima do limite de tolerância |
| **Custo** | Gasto do cluster e do armazenamento em coexistência | Acima do orçamento do dual-run |

- **Dashboards:** um por consumidor (Cerebro, Sentinel, Pepper), com visão comparativa batch vs. stream.
- **Runbooks:** um por alerta, com ação, dono e critério de reversão da flag.
- **Rastreabilidade:** propagar `event_id` e `schema_version` nos logs para auditar qualquer divergência até o evento de origem.

## 4. Checklist de Validação para Cutover e Critérios de Aceite

**Pré-requisitos (Fase 1)**
- [ ] Volumetria média e de pico levantada e usada no dimensionamento do cluster
- [ ] Tecnologia, retenção, particionamento e ordenação do Relay confirmados
- [ ] Retenção suficiente para reprocessamento, ou arquivo frio dos eventos brutos operando
- [ ] Formato do warehouse confirmado, com suporte a merge/upsert transacional validado
- [ ] 14 etapas classificadas como stateless/stateful, e dependências de "hora inteira" mapeadas
- [ ] SLA de latência aprovado pelo negócio e trigger definido
- [ ] Critérios de saída, donos e prazos por fase registrados

**Resiliência e qualidade (Fase 2)**
- [ ] Escrita idempotente comprovada: reexecução do mesmo intervalo gera resultado idêntico
- [ ] Teste de reinício a partir do checkpoint, de falha de micro-batch, de pico de volume e de atraso do Relay executados com sucesso
- [ ] Late data tratado (watermark e política de reprocessamento da partição) e testado
- [ ] Schemas versionados, compatibilidade verificada e testes de contrato passando
- [ ] DLQ operante, com reprocessamento testado e taxa dentro do limite
- [ ] Compactação agendada e small files sob controle
- [ ] Shadow operado pelo período mínimo acordado, incluindo picos e fechamento de ciclo de faturamento
- [ ] Reconciliação dentro da tolerância de forma consistente

**Observabilidade e rollback**
- [ ] Dashboards, alertas e runbooks publicados e validados pelo on-call
- [ ] Feature flag por consumidor testada em ambos os sentidos (ligar e reverter)
- [ ] Visão de alternância batch/stream validada
- [ ] Tabelas batch intactas e atualizadas durante todo o período
- [ ] Mudanças de lógica congeladas durante a virada

**Go-live por consumidor**
- [ ] **Cerebro:** indexação idempotente validada; sem reindexação duplicada; piloto parcial ampliado até 100% sem incidentes
- [ ] **Sentinel:** visão por watermark publica somente horas fechadas; dashboards e agregados batem com o batch por vários dias
- [ ] **Pepper:** divergência zero nos campos de billing por vários ciclos de faturamento consecutivos; relatório paralelo comparado; **aprovação formal do financeiro**
- [ ] Decisão de go/no-go registrada com evidências de reconciliação e critérios atendidos

**Encerramento (Fase 4)**
- [ ] Período de estabilidade cumprido sem acionar rollback
- [ ] Cron `forge-batch-ingest` desligado, com o código batch preservado para backfill
- [ ] Retenção das tabelas batch definida antes de arquivar ou remover
- [ ] Flags, views de alternância e reconciliação removidas
- [ ] Documentação, runbooks e on-call atualizados; retrospectiva realizada
- [ ] Caminho C (`forge.enriched`) avaliado como iniciativa separada