---
nome: Especificar Execução Tática da Migração para Tempo Real
descricao: Transforma o plano de migração do Forge em especificação executável, com padrões de resiliência e garantia de entrega, contratos de eventos, DLQ e retry, plano de observabilidade e checklist de validação do cutover.
versao: 1.0.0
tags: [implementação, resiliência, observabilidade, eventos, cutover]
inputs:
  - nome: resultado_prompt_2
    descricao: Plano de migração do Forge (saída do passo anterior), usado como base para detalhar a execução técnica
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
{{resultado_prompt_2}}
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
- **Contratos de Eventos / Schemas:** Padrões recomendados (ex: JSON Schema, Avro, Protobuf).
- **Tratamento de Erros e Filas de Exceção:** Estratégias de DLQ (Dead Letter Queue) e Retry exponencial.
- **Plano de Observabilidade:** Métricas cruciais (lag do consumidor, latência de ponta a ponta, vazão de eventos, erros por segundo).

## 4. Checklist de Validação para Cutover e Critérios de Aceite
- Lista de verificação em formato de caixa de seleção `[ ]` para autorização do go-live.
