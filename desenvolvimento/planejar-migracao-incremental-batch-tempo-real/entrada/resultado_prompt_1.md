# Relatório de Diagnóstico de Arquitetura: Projeto Forge

## 1. Mapeamento do Estado Atual

**Funcionamento do lote atual**

O Forge é o pipeline que transforma telemetria da Aegis em tabelas consultáveis. Hoje opera assim:

| Aspecto | Estado atual |
|---|---|
| Ingestão | Job cron `forge-batch-ingest`, a cada 60 min |
| Transformação | 14 etapas encadeadas em Spark, ~40 min no total |
| Destino | Tabelas no data warehouse, particionadas por hora |
| Latência efetiva | Dado visível entre ~40 min e ~1h40 após o evento (até 60 min de espera pelo fechamento da janela + ~40 min de processamento) |
| Margem da janela | ~20 min de folga entre o fim do processamento e o próximo disparo |

**Dependentes (consumidores)**

- **Sentinel:** lê as tabelas agregadas.
- **Cerebro:** indexa os eventos transformados.
- **Pepper (billing):** relatórios rodando de madrugada sobre as tabelas do Forge.

**Volumetria:** o snapshot não informa taxa de eventos, tamanho dos lotes, número de partições nem retenção do Relay. Esse é um dado crítico faltante (ver Lacunas).

**Gargalos e limitações para tempo real**

1. **Janela fixa de 60 min.** A latência mínima é estrutural: nenhum ajuste de cron resolve sem mudar o modelo.
2. **Folga de apenas ~20 min.** Com 40 min de processamento sobre 60 min de intervalo, qualquer degradação de performance ou crescimento de volume de cerca de 50% consome a margem.
3. **Falha em cascata.** Se um lote falha, o seguinte acumula o dobro de volume (~80 min de processamento sobre janela de 60), o que ultrapassa o intervalo e pode gerar sobreposição ou atraso permanente. Não há mecanismo de recuperação incremental.
4. **Pipeline monolítico de 14 etapas.** Os 40 min de duração indicam etapas acopladas. É preciso classificar cada etapa como stateless (map/filter/enriquecimento simples) ou stateful (joins, agregações, deduplicação, ordenação), pois isso define a dificuldade de migração.
5. **Semântica "hora fechada".** As tabelas particionadas por hora assumem completude da partição. Em streaming, dados atrasados (late events) e reprocessamento passam a ser questões centrais (watermarks, janelas, upserts).
6. **Contrato implícito com os consumidores.**
   - Sentinel e Pepper provavelmente dependem da atomicidade da partição horária. Escritas incrementais em partição aberta podem expor dados parciais.
   - Cerebro indexa eventos transformados; a indexação contínua exige idempotência (reindexar o mesmo evento não pode duplicar).
7. **Idempotência e exactly-once não documentados.** O modelo atual provavelmente se apoia em "reprocessar a partição inteira". Em modo contínuo isso precisa ser substituído por escrita idempotente ou transacional.

**Lacunas de informação (a validar antes da decisão final)**

- Taxa de eventos (média e pico) e tamanho médio do evento.
- Tecnologia do Relay (Kafka-compatível? fila? log?), retenção, particionamento e garantias de ordenação.
- Formato do warehouse (Delta/Iceberg/Hudi ou tabelas nativas?), pois define suporte a upsert/merge incremental.
- Quais das 14 etapas são stateful.
- SLA de latência desejado ("quase em tempo real" = segundos ou minutos?).
- Se o billing da Pepper exige reconciliação exata (provavelmente sim).

---

## 2. Análise de Caminhos Arquiteturais para Tempo Real

### Caminho A: Spark Structured Streaming (micro-batch contínuo)

Consumo contínuo do Relay com triggers de poucos segundos a poucos minutos, reaproveitando o ecossistema Spark existente.

- **Prós:**
  - Reaproveita a lógica das 14 etapas em Spark (DataFrame API é quase a mesma em batch e streaming), reduzindo reescrita e risco.
  - Alinha-se ao requisito de "pequenos blocos no lugar do lote de 1h": micro-batch é exatamente esse modelo.
  - Mesma equipe, mesmas ferramentas, mesma observabilidade e infraestrutura; curva de aprendizado baixa.
  - Checkpointing e semântica exactly-once com sinks transacionais (se o warehouse usar Delta/Iceberg/Hudi).
  - Permite migração gradual: o mesmo código pode rodar em batch (backfill/reprocessamento) e streaming.
  - Boa fundamentação para reprocessar histórico com o mesmo código, o que facilita rollback.
- **Contras:**
  - Latência na ordem de segundos a minutos, não milissegundos. Adequada ao requisito "quase tempo real", insuficiente se houver exigência sub-segundo.
  - Operações stateful (joins, agregações com janela) exigem gestão de estado, watermarks e tuning de checkpoint.
  - Muitos arquivos pequenos nas tabelas do warehouse se não houver compactação (small files problem), o que impõe jobs de manutenção.
  - Cluster passa a ser always-on, com custo contínuo em vez de picos de hora em hora.
  - Etapas que dependem de "ter visto a hora inteira" precisam ser redesenhadas.

### Caminho B: Stream processing nativo com Flink sobre o Relay

Reescrita do pipeline em Apache Flink (ou equivalente), com processamento evento a evento e estado gerenciado.

- **Prós:**
  - Menor latência (milissegundos a segundos) e modelo mais maduro de event-time, watermarks e late data.
  - Gerenciamento de estado robusto para etapas stateful complexas.
  - Backpressure e recuperação de falhas finos, sem o efeito "dobro de volume" do lote.
  - Escala por operador de forma independente.
- **Contras:**
  - Exige reescrita das 14 etapas (de Spark para Flink), com risco alto de divergência de comportamento e regressão.
  - Nova stack: treinamento, operação, observabilidade, runbooks. Aumenta o custo organizacional.
  - Maior complexidade de operação (estado, savepoints, upgrades).
  - Pode ser sobredimensionado se o SLA real for de minutos.
  - Dificulta a coexistência com o código batch legado durante a transição (dois codebases).

### Caminho C (complementar): Camada de eventos derivados + consumidores reativos

Publicar os eventos transformados em um tópico/barramento (ex.: tópico "forge.enriched") e fazer Cerebro (e eventualmente Sentinel) consumirem o stream em vez de ler tabelas.

- **Prós:**
  - Desacopla consumidores do formato físico das tabelas.
  - Cerebro passa a indexar em tempo real, sem esperar o warehouse.
  - Habilita novos consumidores sem alterar o Forge.
- **Contras:**
  - Não substitui A ou B: ainda é preciso um processador de stream por trás.
  - Exige governança de schema (schema registry), versionamento e contratos.
  - Aumenta a superfície operacional (novo tópico, retenção, ACLs).
  - Alterar Sentinel e Pepper é desnecessário e arriscado no curto prazo.

*Nota:* CDC/Debezium não se aplica diretamente, pois a fonte é o Relay (barramento de eventos), não um banco transacional. Webhooks/Serverless também não são recomendados para pipeline de 14 etapas com estado e volume contínuo.

---

## 3. Recomendação Técnica e Justificativa

- **Melhor Escolha:** **Caminho A (Spark Structured Streaming)** como núcleo, com migração em estrangulamento gradual (strangler pattern) e execução em paralelo (shadow) com o batch. O Caminho C pode ser adotado depois, de forma incremental, apenas para o Cerebro.

- **Justificativa:**
  - **Latência:** o requisito é "pequenos blocos" e "quase em tempo real". Micro-batch de segundos a poucos minutos reduz a latência de ~1h40 para algo na ordem de minutos, atendendo ao objetivo com folga.
  - **Complexidade e risco:** reaproveitar Spark preserva o conhecimento da equipe e a lógica das 14 etapas. O Flink obrigaria a reescrita total, o que contradiz a exigência de migração gradual e reversível.
  - **Custo:** troca-se o pico horário por cluster contínuo dimensionado para a carga média (e menor que o pico do lote, que processa 1h de dados de uma vez). Autoscaling mitiga. O custo deve ser validado com a volumetria real.
  - **Impacto operacional:** elimina o efeito cascata de falhas: um micro-batch que falha reprocessa poucos minutos a partir do checkpoint, e não 2h de dados.
  - **Reversibilidade:** manter o batch como caminho de referência permite voltar atrás a qualquer momento (a lógica Spark é a mesma).

**Plano de migração em passos (sem big-bang)**

1. **Fase 0 – Descoberta:** classificar as 14 etapas (stateless/stateful), levantar volumetria, tecnologia do Relay e formato do warehouse; definir SLA de latência.
2. **Fase 1 – Shadow:** rodar o streaming em paralelo, gravando em tabelas *separadas* (`*_stream`), sem consumidores. Comparar com o batch (contagens, checksums, diferenças por partição horária).
3. **Fase 2 – Reconciliação:** automatizar a validação batch vs. stream; só avançar com divergência dentro de tolerância acordada.
4. **Fase 3 – Consumidor piloto:** migrar primeiro o Cerebro (tolera atualização contínua, desde que a indexação seja idempotente) usando feature flag para alternar entre fonte batch e stream.
5. **Fase 4 – Sentinel:** expor as tabelas agregadas via visão/partição consolidada que preserve a semântica de "hora fechada" (publicar a partição só quando o watermark a fechar), mantendo o contrato atual.
6. **Fase 5 – Pepper (billing):** por último. Manter o batch como fonte de verdade até haver reconciliação consistente por vários ciclos de faturamento.
7. **Fase 6 – Desativação:** só após estabilidade comprovada, aposentar o `forge-batch-ingest`, mantendo o código batch disponível para backfill.

**Mecanismos de rollback:** feature flag por consumidor; tabelas batch mantidas intactas até a Fase 6; checkpoints versionados; capacidade de reprocessar por intervalo a partir da retenção do Relay.

**Riscos principais**

| Risco | Mitigação |
|---|---|
| Duplicidade/perda de eventos | Escrita idempotente/transacional, chaves de deduplicação, checkpoint |
| Late data afetando agregações | Watermarks, janela de tolerância, reprocessamento da partição |
| Small files no warehouse | Compactação agendada, ajuste de trigger |
| Divergência no billing | Billing por último, reconciliação contínua, batch como fonte de verdade |
| Retenção do Relay insuficiente para reprocessar | Validar retenção na Fase 0; arquivar eventos brutos se necessário |

---

## 4. Bloco de Exportação para o Próximo Passo

<passo1_result>
**Sistema:** Forge (pipeline Aegis: telemetry → tabelas consultáveis). Fonte alvo: Relay.

**Estado atual:** batch horário (cron `forge-batch-ingest`, 60 min); 14 etapas Spark encadeadas (~40 min); grava no data warehouse particionado por hora; latência efetiva ~40 min a ~1h40; folga ~20 min; falha de um lote → próximo acumula 2x volume.

**Dependentes:** Sentinel (tabelas agregadas), Cerebro (indexa eventos transformados), Pepper billing (relatórios de madrugada).

**Requisitos da migração:** consumo contínuo do Relay em pequenos blocos; não quebrar dependentes durante a transição; sem big-bang; reversível.

**Gargalos críticos:** janela fixa de 60 min; folga baixa; falha em cascata; pipeline monolítico de 14 etapas; contrato implícito de "partição horária fechada"; idempotência/exactly-once não documentados.

**Caminhos avaliados:** A) Spark Structured Streaming (micro-batch); B) Flink nativo (reescrita); C) camada de eventos derivados para consumidores (complementar). CDC/Debezium e Webhooks/Serverless descartados.

**Recomendação:** Caminho A com migração por estrangulamento e shadow run; Caminho C opcional depois, só para o Cerebro. Ordem de migração dos consumidores: Cerebro → Sentinel → Pepper (billing por último).

**Plano em fases:** 0 Descoberta → 1 Shadow (tabelas `*_stream`) → 2 Reconciliação automatizada → 3 Cerebro (feature flag) → 4 Sentinel (partição publicada por watermark) → 5 Pepper → 6 Desativação do batch.

**Rollback:** feature flag por consumidor; tabelas batch intactas até a fase 6; checkpoints versionados; reprocessamento por intervalo via retenção do Relay.

**Lacunas a resolver (Fase 0):** volumetria (média/pico, tamanho do evento); tecnologia, retenção e particionamento do Relay; formato do warehouse (Delta/Iceberg/Hudi?); classificação stateless/stateful das 14 etapas; SLA de latência alvo; exigência de reconciliação exata do billing.

**Riscos-chave:** duplicidade/perda de eventos; late data; small files; divergência no billing; retenção insuficiente do Relay.
</passo1_result>
