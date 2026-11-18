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

# Avaliar Manifesto de NetworkPolicy Corrigido

## Objetivo

Avaliar criticamente o manifesto Kubernetes corrigido produzido por um modelo de linguagem a partir de um prompt de correção de NetworkPolicy, comparando-o com os dados originais. A avaliação segue quatro critérios ponderados: fidelidade aos dados (40%), conformidade com NetworkPolicy (30%), sintaxe e validade do YAML (15%) e resolução de divergências (15%). O resultado é uma tabela de pontuação, uma nota final de 0.0 a 5.0 e um parecer (aprovado para deploy ou reprovado).

## Quando usar

- Após executar o prompt de correção de manifesto de NetworkPolicy, para validar a resposta antes do deploy.
- Para detectar alucinação de serviços, labels, namespaces ou portas no manifesto gerado.
- Para obter uma nota objetiva e um parecer de aprovação ou reprovação do manifesto.

## Exemplo de uso

Substituir `{{snapshot_inputs_originais}}` pelas entradas usadas na correção (manifesto, padrão de NetworkPolicy e lista de serviços) e `{{snapshot_resultado_correcao}}` pela resposta da correção. Um exemplo de cada está em [`entrada/`](./entrada/). A saída traz a tabela de notas por critério, a nota final de 0,0 a 5,0 e o parecer `APROVADO PARA DEPLOY` ou `REPROVADO - NECESSITA REVISÃO`.

## Testes

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) usa as entradas do Checkpoint 06 em [`entrada/`](./entrada/) com `gpt-4.1-mini`, com 3 repetições e sem cache. Como o prompt já emite nota e status, todos os testes são determinísticos:

- **Correção conforme** (a do CP06): deve sair `APROVADO PARA DEPLOY` com nota final de pelo menos 4,0.
- **Correção não conforme** (com os labels inventados `app: sentinel-api` e `prometheus` e com egress aberto): deve sair `REPROVADO` com nota de no máximo 3,0, apontando as alucinações e o egress aberto.
- **Ambas:** as 4 seções do formato, a nota final coerente com a média ponderada da tabela (folga de 0,3), resposta em até 60 s e custo de até US$ 0,01 por chamada.

```bash
npx promptfoo@latest eval -c devops/avaliar-manifesto-network-policy-corrigido/promptfooconfig.yaml
```

## Limitações conhecidas

- A nota final nem sempre é a média ponderada exata: o modelo às vezes arredonda para meio ponto (ex.: 1,725 virou 2,0). O teste aceita diferença de até 0,3, porque a decisão de aprovar ou reprovar não muda.
- A avaliação é feita só pela leitura. O prompt não executa `kubectl` nem valida o YAML contra a API do Kubernetes.
