---
nome: Diagnosticar Migração de Batch para Tempo Real
descricao: Analisa a documentação de um sistema em processamento em lote (Forge), mapeia gargalos e acoplamentos e compara caminhos arquiteturais para tempo real, com recomendação e bloco de exportação para o próximo passo.
versao: 1.1.1
tags: [arquitetura, batch, streaming, tempo-real, migração]
inputs:
  - nome: dados_do_sistema_e_ambiente
    descricao: Documentação e dados do sistema Forge e de seu ambiente (funcionamento do lote atual, volumetria, janelas de execução, dependências)
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
{{dados_do_sistema_e_ambiente}}
</snapshot>


# RESPONSE FORMAT (Formato de Resposta)
Forneça o retorno estritamente em Markdown no seguinte formato:

# Relatório de Diagnóstico de Arquitetura: Projeto Forge

## 1. Mapeamento do Estado Atual
- Resumo do funcionamento do lote atual (volumetria, janelas de execução, dependências).
- Gargalos e limitações identificadas para tempo real.
- Volumetria para dimensionamento: informe eventos por segundo e volume por hora. Separe dado de estimativa: todo número que não aparece literalmente no SNAPSHOT, inclusive os deduzidos dele, leva a marca **[estimativa]** e a premissa usada. Se não houver base nem para estimar, registre a lacuna para ser levantada.

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
