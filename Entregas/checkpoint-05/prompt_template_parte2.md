---
nome: "Passo a Passo da Migração - Projeto Forge"
descricao: "Estrutura a estratégia de transição e o roteiro incremental de migração de lote para tempo real"
versao: "1.0.0"
dominio: "devops-arquitetura"
tags:
  - forge
  - plano-migracao
  - streaming
  - rollout
modelo_recomendado: "claude-sonnet-3.5"
inputs:
  - nome: "SNAPSHOT"
    descricao: "Relatório de diagnóstico e decisão arquitetural gerado no resultado do Prompt 1"
---

# CONTEXT (Contexto)
Você é um Especialista em Migração de Sistemas e Engenharia de Confiabilidade (SRE). O diagnóstico do Forge foi concluído (fornecido na seção SNAPSHOT). Agora é necessário definir a estratégia de transição (passo a passo) para garantir coexistência entre lote e tempo real sem parada do negócio.

# OBJECTIVE (Objetivo)
Com base no diagnóstico do SNAPSHOT, elaborar a estratégia de rollout e o plano passo a passo de migração incremental do Forge.

# STYLE (Estilo)
Plano estratégico de engenharia de software com foco em controle de mudanças e mitigação de risco.

# TONE (Tom)
Estruturado, preventivo e focado na continuidade operacional.

# AUDIENCE (Audiência)
Equipes de Desenvolvimento, SRE/DevOps e Gestores de Projeto.

# INPUT DATA (Entrada)
<snapshot>
{{RESULTADO_PROMPT_1}}
</snapshot>

# RESPONSE FORMAT (Formato de Resposta)
Forneça o retorno estritamente em Markdown no seguinte formato:

# Plano Estratégico de Migração: Projeto Forge

## 1. Análise Estratégica de Transição
Apresente ao menos 2 estratégias de transição aplicáveis (ex: Padrão Strangler Fig / Padrão de Coexistência Dual-Run vs. Cutover Direto / Big Bang).

### Estratégia A: [Nome da Estratégia A]
- **Prós:** [Lista detalhada]
- **Contras:** [Lista detalhada]

### Estratégia B: [Nome da Estratégia B]
- **Prós:** [Lista detalhada]
- **Contras:** [Lista detalhada]

## 2. Escolha da Estratégia e Justificativa
- **Melhor Escolha:** [Indicação clara da estratégia]
- **Justificativa:** [Explicação focada na redução de risco e suporte a Rollback]

## 3. Roteiro Passo a Passo da Migração (Roadmap Incremental)
- **Fase 1: Preparação e Infraestrutura Base** (Passos detalhados)
- **Fase 2: Coexistência e Dupla Escrita (Dual Run / Shadow)** (Passos detalhados)
- **Fase 3: Virada de Chave (Cutover)** (Passos detalhados)
- **Fase 4: Desativação e Cleanup do Processamento em Lote** (Passos detalhados)

## 4. Matriz de Riscos e Plano de Fallback/Rollback
- Principais riscos de migração e como reverter cada fase caso ocorra falha.

## 5. Bloco de Exportação para o Próximo Passo
Apresente um resumo compacto formatado entre as tags `<passo2_result>` e `</passo2_result>` contendo a estratégia selecionada e as fases definidas.