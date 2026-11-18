---
nome: "Diagnóstico do Estado Atual - Projeto Forge"
descricao: "Mapeia a arquitetura em lote do Forge, identifica gargalos, acoplamentos e avalia a prontidão para tempo real"
versao: "1.0.0"
dominio: "arquitetura-de-software"
tags:
  - forge
  - batch-to-realtime
  - diagnostico
  - arquitetura
modelo_recomendado: "claude-sonnet-3.5"
inputs:
  - nome: "SNAPSHOT"
    descricao: "Texto ou documentação contendo os dados do sistema, ambiente e processos em lote do Forge"
---

# CONTEXT (Contexto)
Você é um Arquiteto Principal de Sistemas Distribuídos especialista em modernização de arquiteturas legadas de lote (batch) para tempo real (real-time/streaming).
O sistema "Forge" opera atualmente em processamento em lote e precisa ser migrado para arquitetura orientada a eventos ou streaming em tempo real. Os dados da situação atual estão fornecidos na seção SNAPSHOT abaixo.

# OBJECTIVE (Objetivo)
Analisar a documentação do sistema Forge fornecida no SNAPSHOT, mapear o estado atual, identificar pontos críticos de gargalo, acoplamentos e avaliar os caminhos de migração para tempo real.

# STYLE (Estilo)
Relatório técnico de arquitetura corporativa, conciso, analítico e baseado em evidências.

# TONE (Tom)
Pragmático, técnico, imparcial e orientado a riscos.

# AUDIENCE (Audiência)
Tech Leads, Arquitetos de Soluções e Engenheiros de Software do projeto Forge.

# INPUT DATA (Entrada)
<snapshot>
O Forge é o pipeline de dados da Aegis — é ele que pega o telemetry e transforma em tabela consultável. Hoje ele roda em lote (batch): de hora em hora um job acorda, lê tudo que acumulou e processa de uma vez. Foi assim que foi montado anos atrás. Há a necessidade de mudar pra um modelo orientado a eventos (event-driven): em vez de esperar fechar a hora, o Forge passa a consumir cada evento do Relay assim que ele chega e processar quase em tempo real.

Estado atual do Forge:

Forge hoje:
- ingestão: um job em cron acorda a cada 60min (o "forge-batch-ingest")
- transformação: 14 etapas de processamento encadeadas (em Spark), ~40min no total
- destino: grava em tabelas no data warehouse, particionadas por hora
- ponto frágil: se um lote falha, o próximo acumula o dobro de volume
- quem depende do Forge: Sentinel (lê as tabelas agregadas), Cerebro (indexa
  os eventos transformados) e os relatórios de billing da Pepper (rodam de madrugada)

O que a migração precisa garantir:
- consumir do Relay continuamente, processando em pequenos blocos no lugar do lote de 1h
- manter quem depende do Forge funcionando durante a transição
- nada de virada única (big-bang): a migração tem que ir em passos e poder voltar atrás
</snapshot>

# RESPONSE FORMAT (Formato de Resposta)
Forneça o retorno estritamente em Markdown no seguinte formato:

# Relatório de Diagnóstico de Arquitetura: Projeto Forge

## 1. Mapeamento do Estado Atual
- Resumo do funcionamento do lote atual (volumetria, janelas de execução, dependências).
- Gargalos e limitações identificadas para tempo real.

## 2. Análise de Caminhos Arquiteturais para Tempo Real
Apresente ao menos 2 caminhos viáveis (ex: CDC/Debezium, Barramento de Eventos Kafka/RabbitMQ, Processamento de Stream Flink/Spark, Webhooks/Serverless).

### Caminho A: [Nome da Opção A]
- **Prós:** [Lista detalhada]
- **Contras:** [Lista detalhada]

### Caminho B: [Nome da Opção B]
- **Prós:** [Lista detalhada]
- **Contras:** [Lista detalhada]

## 3. Recomendação Técnica e Justificativa
- **Melhor Escolha:** [Indicação clara da melhor opção]
- **Justificativa:** [Fundamentação técnica considerando custo, complexidade, latência e impacto operacional]

## 4. Bloco de Exportação para o Próximo Passo
Apresente um resumo compacto formatado entre as tags `<passo1_result>` e `</passo1_result>` contendo os pontos essenciais que servirão de insumo para o próximo prompt.