---
nome: "Detalhes da Execução - Projeto Forge"
descricao: "Gera o detalhamento técnico de execução, especificações de código/infraestrutura, testes e observabilidade"
versao: "1.0.0"
dominio: "engenharia-de-sistemas"
tags:
  - forge
  - execucao
  - real-time
  - devops
modelo_recomendado: "claude-sonnet-3.5"
inputs:
  - nome: "SNAPSHOT"
    descricao: "Plano passo a passo de migração gerado no resultado do Prompt 2"
---

# CONTEXT (Contexto)
Você é um Engenheiro de Software Senior & SRE Lead especializado na implementação tática de sistemas em tempo real. O plano passo a passo de migração do Forge está definido (fornecido na seção SNAPSHOT). Agora você deve gerar o detalhamento de execução técnica direta para os desenvolvedores e operadores.

# OBJECTIVE (Objetivo)
Transformar o plano de migração do SNAPSHOT em especificações executáveis de implementação, observabilidade, padrões de resiliência e validação final.

# STYLE (Estilo)
Manual de execução técnica e especificação tática acionável.

# TONE (Tom)
Direto, prescritivo e minucioso.

# AUDIENCE (Audiência)
Engenheiros de Software, Engenheiros de Dados e Analistas SRE.

# INPUT DATA (Entrada)
<snapshot>
# Plano Estratégico de Migração: Projeto Forge

## 1. Análise Estratégica de Transição

### Estratégia A: Strangler Fig com Dual-Run (Shadow → Consumidor a Consumidor)

O streaming roda em paralelo ao batch, gravando em tabelas separadas (`*_stream`). Os consumidores migram um a um (Cerebro → Sentinel → Pepper), sob feature flag. O batch continua como fonte de verdade até a estabilidade comprovada.

- **Prós:**
  - Rollback imediato e barato em qualquer fase: basta desligar a feature flag e o consumidor volta a ler o batch, que nunca foi tocado.
  - A reconciliação batch vs. stream em dados reais de produção gera evidência objetiva de corretude antes de qualquer consumidor depender do streaming.
  - O raio de impacto é pequeno e crescente: começa pelo consumidor mais tolerante (Cerebro) e deixa o billing (Pepper) por último.
  - Preserva o contrato implícito de "partição horária fechada" para Sentinel e Pepper, que só passam a ver a partição publicada por watermark.
  - Os riscos desconhecidos (late data, small files, idempotência) aparecem na Fase Shadow, sem impacto no negócio.
  - Não exige janela de parada nem coordenação simultânea entre equipes.
- **Contras:**
  - Custo duplicado durante a coexistência: cluster do batch e cluster de streaming always-on rodando juntos, mais armazenamento das tabelas `*_stream`.
  - Prazo total maior do que um cutover direto.
  - Complexidade operacional temporária: duas fontes, duas observabilidades, lógica de reconciliação e feature flags para manter.
  - Risco de "migração eterna": sem critérios de saída e prazos, o dual-run pode se prolongar e o batch nunca ser desativado.
  - A reconciliação exige definir tolerância de divergência (principalmente com late data), o que demanda alinhamento entre as equipes.

### Estratégia B: Cutover Direto (Big Bang)

Substitui o `forge-batch-ingest` pelo pipeline de streaming em uma única virada, com todos os consumidores passando a ler as novas tabelas ao mesmo tempo, após testes em ambiente de homologação.

- **Prós:**
  - Prazo total menor e sem período de custo duplicado.
  - Sem manutenção de dois caminhos de dados nem lógica de reconciliação.
  - Fonte de verdade única e simples desde o dia da virada.
  - Menor esforço de coordenação de fases e de feature flags.
- **Contras:**
  - Risco concentrado: qualquer divergência afeta Sentinel, Cerebro e Pepper simultaneamente.
  - Rollback difícil e lento: com o batch desligado, voltar exige reativar o cron e reprocessar o histórico, dependendo da retenção do Relay.
  - Homologação raramente reproduz volume, picos e late data reais, e as lacunas (volumetria, retenção do Relay, formato do warehouse) ainda estão abertas.
  - Risco financeiro direto no billing da Pepper, que provavelmente exige reconciliação exata.
  - Contradiz os requisitos declarados: sem big-bang e reversível.
  - Dados parciais em partição aberta podem quebrar Sentinel e Pepper, que dependem da atomicidade horária.

## 2. Escolha da Estratégia e Justificativa

- **Melhor Escolha:** **Estratégia A: Strangler Fig com Dual-Run**, usando o Caminho A (Spark Structured Streaming) definido no diagnóstico.

- **Justificativa:**
  - **Redução de risco:** o batch permanece intacto e em produção até a Fase 4. Todo erro do streaming é detectado na reconciliação, antes de afetar um consumidor.
  - **Suporte a rollback:** a reversão é uma ação de configuração (feature flag por consumidor), não uma operação de recuperação de dados. O mesmo código Spark roda em batch, o que permite backfill e reprocessamento por intervalo.
  - **Ordem por criticidade:** Cerebro tolera atualização contínua (com indexação idempotente); Sentinel depende da semântica de hora fechada; Pepper exige exatidão financeira e só migra após vários ciclos de faturamento reconciliados.
  - **Lacunas ainda abertas:** volumetria, retenção do Relay, formato do warehouse e classificação das 14 etapas ainda não são conhecidos. Uma estratégia incremental absorve essas descobertas; um big-bang as transformaria em incidentes.
  - **Custo aceitável:** o custo duplicado é temporário e limitado por critérios de saída e prazos. É um preço pequeno frente ao risco de erro de billing ou parada dos dependentes.

## 3. Roteiro Passo a Passo da Migração (Roadmap Incremental)

### Fase 1: Preparação e Infraestrutura Base

1. **Fechar as lacunas do diagnóstico:**
   - Levantar volumetria (taxa média e de pico, tamanho do evento).
   - Confirmar tecnologia, retenção, particionamento e garantias de ordenação do Relay.
   - Confirmar o formato do warehouse (Delta/Iceberg/Hudi ou nativo) e o suporte a merge/upsert transacional.
2. **Classificar as 14 etapas** em stateless e stateful (joins, agregações, deduplicação, ordenação) e mapear as que dependem de "ter visto a hora inteira".
3. **Definir o SLA de latência alvo** (segundos ou minutos) com as áreas de negócio e escolher o intervalo de trigger.
4. **Validar a retenção do Relay.** Se for insuficiente para reprocessamento, arquivar os eventos brutos em armazenamento frio.
5. **Provisionar a infraestrutura de streaming:** cluster com autoscaling, armazenamento de checkpoints versionados, ambientes e CI/CD.
6. **Adaptar o código Spark** para rodar em batch e streaming a partir de uma base única; implementar chaves de deduplicação e escrita idempotente/transacional.
7. **Preparar observabilidade:** métricas de lag de consumo, duração de micro-batch, volume de estado, arquivos pequenos e frescor do dado, com alertas e runbooks.
8. **Definir critérios de saída por fase**, com donos e prazos, para evitar a migração eterna.
9. **Preparar a base de rollback:** feature flags por consumidor, camada de leitura (view) que alterne entre fonte batch e stream e jobs de compactação agendados.

### Fase 2: Coexistência e Dupla Escrita (Dual Run / Shadow)

1. **Subir o streaming em modo shadow**, gravando em tabelas `*_stream`, sem nenhum consumidor lendo delas. O batch continua como fonte de verdade.
2. **Construir a reconciliação automatizada** batch vs. stream por partição horária: contagens, checksums, diferenças por chave e por agregação.
3. **Definir tolerâncias com os consumidores:**
   - Cerebro e Sentinel: divergência dentro de limite acordado.
   - Pepper: exatidão (divergência zero) em campos de billing.
4. **Tratar late data:** configurar watermarks e janela de tolerância, e definir a política de reprocessamento da partição.
5. **Executar testes de resiliência no shadow:** falha de micro-batch, reinício a partir do checkpoint, pico de volume, atraso do Relay.
6. **Operar o shadow por período mínimo acordado** (incluindo picos de uso e fechamento de ciclo de faturamento), até a reconciliação ficar dentro da tolerância de forma consistente.
7. **Piloto com o Cerebro:** passar o Cerebro a consumir o stream sob feature flag, com indexação idempotente, iniciando com parcela do tráfego/índices e ampliando gradualmente.
8. **Preparar o Sentinel:** criar a visão/partição consolidada que só publica a hora quando o watermark a fecha, preservando o contrato de hora fechada.

### Fase 3: Virada de Chave (Cutover)

1. **Cutover do Cerebro** (se ainda não completo): 100% dos eventos via stream, com monitoramento intensivo e o batch como fallback.
2. **Cutover do Sentinel:**
   - Habilitar a leitura da visão publicada por watermark via feature flag.
   - Validar, durante vários dias, que dashboards e agregados batem com o batch.
   - Manter o batch rodando em paralelo durante todo o período de observação.
3. **Cutover da Pepper (billing), por último:**
   - Manter o batch como fonte de verdade até a reconciliação ser exata por vários ciclos de faturamento consecutivos.
   - Fazer a primeira virada em um relatório não crítico ou em execução paralela (relatórios gerados pelas duas fontes e comparados antes de qualquer decisão).
   - Só então promover o stream a fonte oficial, com aprovação formal do negócio/financeiro.
4. **Congelar mudanças** de lógica no pipeline durante cada virada, para manter a comparação válida.
5. **Registrar a decisão** de go/no-go de cada consumidor, com evidências de reconciliação e critérios atendidos.

### Fase 4: Desativação e Cleanup do Processamento em Lote

1. **Período de estabilidade pós-cutover:** confirmar que todos os consumidores operam apenas pelo stream por um prazo acordado, sem acionar rollback.
2. **Desligar o cron `forge-batch-ingest`**, preservando o código batch no repositório (disponível para backfill e reprocessamento).
3. **Manter as tabelas batch** (somente leitura) por período de retenção definido antes de arquivá-las ou removê-las.
4. **Remover feature flags, views de alternância e a reconciliação** que deixaram de ser necessárias.
5. **Consolidar a operação:** compactação agendada, retenção de checkpoints, dimensionamento do cluster com base na carga real e revisão de custo.
6. **Atualizar documentação, runbooks e on-call**, e conduzir retrospectiva com as equipes.
7. **Avaliar o Caminho C** (tópico `forge.enriched` para o Cerebro) como evolução opcional, em iniciativa separada.

## 4. Matriz de Riscos e Plano de Fallback/Rollback

| Risco | Fase | Mitigação | Rollback / Fallback |
|---|---|---|---|
| Duplicidade ou perda de eventos | 2, 3 | Escrita idempotente/transacional, chaves de deduplicação, checkpoints, reconciliação contínua | Desligar a flag do consumidor e voltar ao batch; reprocessar o intervalo a partir da retenção do Relay |
| Late data distorcendo agregações | 2, 3 | Watermarks, janela de tolerância, reprocessamento da partição | Voltar a flag para o batch; reprocessar a partição afetada |
| Small files degradando o warehouse | 2, 3 | Compactação agendada, ajuste do trigger | Aumentar o trigger e executar compactação; se persistir, voltar ao shadow |
| Divergência no billing da Pepper | 3 | Billing por último, vários ciclos reconciliados, aprovação do financeiro | Batch segue como fonte de verdade; reverter flag e regerar o relatório pelo batch |
| Retenção do Relay insuficiente para reprocessar | 1, 2, 3 | Validar na Fase 1; arquivar eventos brutos | Reprocessar a partir do arquivo frio |
| Consumidor lê partição aberta (dados parciais) | 3 | Publicação por watermark; testes de contrato com Sentinel e Pepper | Reverter a visão para a partição batch |
| Reindexação duplicada no Cerebro | 2, 3 | Indexação idempotente por ID de evento | Reverter a flag para o batch e reindexar o intervalo afetado |
| Falha de micro-batch ou lag crescente | 2, 3, 4 | Alertas de lag e frescor, autoscaling, runbooks | Retomar do último checkpoint; se o SLA for violado, reverter a flag |
| Custo duplicado fora do previsto | 2, 3 | Orçamento, autoscaling, prazo máximo de coexistência | Reduzir o shadow a amostra e acelerar a decisão de go/no-go |
| Migração eterna (batch nunca desligado) | 3, 4 | Critérios de saída, donos e prazos | Escalar para a gestão com a decisão formal de prosseguir ou encerrar |
| Regressão de lógica nas 14 etapas | 1, 2 | Código único batch/stream, testes de equivalência, reconciliação | Corrigir no shadow, sem impacto em consumidores |

**Reversão por fase:**

- **Fase 1:** nada em produção foi alterado; basta descartar a infraestrutura provisionada.
- **Fase 2:** desligar o job de streaming e descartar as tabelas `*_stream`; o batch nunca foi afetado.
- **Fase 3:** desativar a feature flag do consumidor afetado para voltar à fonte batch. As tabelas batch permanecem intactas e atualizadas, por isso a reversão é imediata e sem perda de dados.
- **Fase 4:** reativar o cron e o código batch preservado e reprocessar o intervalo necessário via retenção do Relay (ou arquivo frio). Esta é a fase de menor reversibilidade, por isso só começa após estabilidade comprovada.

## 5. Bloco de Exportação para o Próximo Passo

<passo2_result>
**Sistema:** Forge (pipeline Aegis: telemetria → tabelas consultáveis). Fonte: Relay. Dependentes: Sentinel, Cerebro, Pepper (billing).

**Estratégia selecionada:** Strangler Fig com Dual-Run (shadow → consumidor a consumidor), sobre Spark Structured Streaming (Caminho A). Cutover direto (big-bang) descartado: risco concentrado, rollback lento, contradiz os requisitos de gradualidade e reversibilidade.

**Princípios:** batch como fonte de verdade até a Fase 4; rollback por feature flag por consumidor; tabelas batch intactas; código único batch/stream; critérios de saída com donos e prazos.

**Fases definidas:**
1. **Preparação e Infraestrutura Base:** fechar lacunas (volumetria, Relay, formato do warehouse, etapas stateless/stateful, SLA); provisionar cluster, checkpoints, observabilidade; escrita idempotente; flags e views de alternância; critérios de saída.
2. **Coexistência e Dupla Escrita (Shadow):** streaming em `*_stream` sem consumidores; reconciliação automatizada com tolerâncias (billing: divergência zero); watermarks e late data; testes de resiliência; piloto do Cerebro (idempotente, flag); preparar visão por watermark para o Sentinel.
3. **Virada de Chave:** ordem Cerebro → Sentinel (hora fechada publicada por watermark) → Pepper (por último, após vários ciclos de faturamento reconciliados e aprovação do financeiro); congelamento de mudanças; go/no-go documentado.
4. **Desativação e Cleanup do Batch:** período de estabilidade; desligar `forge-batch-ingest` mantendo o código para backfill; retenção das tabelas batch; remover flags e reconciliação; compactação e revisão de custo; Caminho C (`forge.enriched`) como evolução opcional e separada.

**Rollback:** Fases 1–2 sem impacto em produção; Fase 3 por desativação da flag (imediato, sem perda); Fase 4 por reativação do cron e reprocessamento via retenção do Relay ou arquivo frio.

**Riscos-chave:** duplicidade/perda de eventos; late data; small files; divergência no billing; retenção insuficiente do Relay; partição aberta exposta aos consumidores; custo duplicado; migração eterna; regressão nas 14 etapas.

**Pendências herdadas (Fase 1):** volumetria média/pico, tecnologia e retenção do Relay, formato do warehouse, classificação das 14 etapas, SLA de latência, exigência de reconciliação exata do billing, duração mínima do shadow e tolerâncias de divergência.
</passo2_result>
</snapshot>

# RESPONSE FORMAT (Formato de Resposta)
Forneça o retorno estritamente em Markdown no seguinte formato:

# Especificação Tática e Detalhes da Execução: Projeto Forge

## 1. Padrões de Implementação e Resiliência
Apresente ao menos 2 abordagens de garantia de entrega e resiliência (ex: At-least-once com Idempotência vs. Exactly-once processing).

### Abordagem A: [Nome da Abordagem A]
- **Prós:** [Lista detalhada]
- **Contras:** [Lista detalhada]

### Abordagem B: [Nome da Abordagem B]
- **Prós:** [Lista detalhada]
- **Contras:** [Lista detalhada]

## 2. Escolha da Abordagem e Justificativa
- **Melhor Escolha:** [Indicação da melhor escolha]
- **Justificativa:** [Fundamentação sobre integridade de dados e complexidade]

## 3. Guia de Execução Operacional
- **Contratos de Eventos / Schemas:** Padrões recommended (ex: JSON Schema, Avro, Protobuf).
- **Tratamento de Erros e Filas de Exceção:** Estratégias de DLQ (Dead Letter Queue) e Retry exponencial.
- **Plano de Observabilidade:** Métricas cruciais (lag do consumidor, latência de ponta a ponta, vazão de eventos, erros por segundo).

## 4. Checklist de Validação para Cutover e Critérios de Aceite
- Lista de verificação em formato de caixa de seleção `[ ]` para autorização do go-live.