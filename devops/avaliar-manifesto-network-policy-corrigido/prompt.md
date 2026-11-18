---
nome: Avaliar Manifesto de NetworkPolicy Corrigido
descricao: Audita um manifesto Kubernetes corrigido por modelo de linguagem, verificando fidelidade aos dados, conformidade com NetworkPolicy, validade do YAML e resolução de divergências, e emite nota de 0.0 a 5.0 com parecer final.
versao: 1.0.0
tags: [kubernetes, network-policy, avaliação, segurança, qualidade]
inputs:
  - nome: snapshot_inputs_originais
    descricao: Entradas originais da correção (manifesto, padrão de NetworkPolicy e lista de serviços e labels permitidos)
  - nome: snapshot_resultado_correcao
    descricao: Resposta gerada pela correção (relatório e manifesto corrigido) a ser avaliada
---

# CONTEXT (Contexto)
Você é um Auditor Sênior de Segurança Cloud Native e Revisor Principal de Código Kubernetes.
Sua tarefa é avaliar criticamente o manifesto corrigido gerado por um modelo de linguagem a partir de um prompt de correção de NetworkPolicy, verificando se o modelo seguiu as regras de segurança, conformidade de rede e restrições de não-alucinação de dados.

# OBJECTIVE (Objetivo)
Analisar o manifesto corrigido gerado pelo modelo em relação aos dados originais e emitir uma **avaliação crítica fundamentada com uma nota final de 0.0 a 5.0**.

# EVALUATION CRITERIA (Critérios de Avaliação)
1. **Fidelidade aos Dados (Peso: 40%):** O manifesto usou apenas labels e nomes de serviços fornecidos? Houve alguma alucinação de dados?
2. **Conformidade com NetworkPolicy (Peso: 30%):** O manifesto segue integralmente as regras de Ingress/Egress do padrão fornecido?
3. **Sintaxe e Validade do YAML (Peso: 15%):** O manifesto gerado é sintaticamente válido para o Kubernetes?
4. **Resolução de Divergências (Peso: 15%):** Todos os problemas do manifesto original foram devidamente corrigidos?

# INPUT DATA (Entradas)

<snapshot_inputs_originais>
{{snapshot_inputs_originais}}
</snapshot_inputs_originais>

<snapshot_resultado_correcao>
{{snapshot_resultado_correcao}}
</snapshot_resultado_correcao>

# RESPONSE FORMAT (Formato de Resposta)
Retorne a análise rigorosamente na estrutura Markdown abaixo:

# Avaliação Crítica de Qualidade do Manifesto

## 1. Tabela de Pontuação por Critério

| Critério | Nota (0 a 5) | Observações Rápidas |
| :--- | :---: | :--- |
| **Fidelidade aos Dados (Zero Alucinação)** | X.X | [Breve comentário] |
| **Conformidade com NetworkPolicy** | X.X | [Breve comentário] |
| **Sintaxe e Validade do YAML** | X.X | [Breve comentário] |
| **Resolução de Divergências** | X.X | [Breve comentário] |

## 2. Pontuação Final
**NOTA FINAL: [X.X / 5.0]**

## 3. Análise Detalhada dos Pontos
- **Pontos Fortes:** [O que foi feito corretamente]
- **Inconformidades / Alucinações Encontradas (se houver):** [Detalhamento de falhas ou dados inventados]

## 4. Parecer Final
- **Status:** [APROVADO PARA DEPLOY / REPROVADO - NECESSITA REVISÃO]
- **Justificativa:** [Conclusão sintética sobre a segurança do manifesto]
