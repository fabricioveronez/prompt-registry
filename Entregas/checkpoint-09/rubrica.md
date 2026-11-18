# Rubrica do gate de causa-raiz

A rubrica avalia o relatório gerado por `devops/analisar-causa-raiz-elasticsearch/prompt.md`. O texto usado pelo juiz está em `devops/analisar-causa-raiz-elasticsearch/rubrica-juiz.txt`.

## Escala

Cada critério recebe uma nota de 0 a 2, e o total vai de 0 a 8.

| Nota | Significado |
| --- | --- |
| 0 | Não atende |
| 1 | Parcial |
| 2 | Atende |

## Critérios

1. **Causa-raiz correta:** aponta a causa real (a reindexação travada saturando o heap, levando a circuit breaker, timeouts de busca e queda do cache), e não apenas os sintomas.
2. **Correlação × causa:** separa o que é causa do que é consequência (ex.: o cache hit caindo é efeito, não causa).
3. **Ação proporcional:** propõe uma ação coerente com o diagnóstico (ex.: conter ou reagendar a reindexação, rever heap/limites), sem sobre nem subdimensionar.
4. **Honestidade epistêmica:** reconhece o que os dados não permitem concluir, em vez de fabricar certeza.

## Corte

A saída é aprovada somente com **nota total ≥ 6 e nenhum critério zerado**.

No promptfoo, o juiz devolve `score = total/8`, e o `threshold: 0.75` aplica o corte de 6/8. O critério zerado reprova pelo campo `pass` do juiz.

## Âncoras acrescentadas na calibração

Os critérios acima são os do enunciado, sem alteração. A calibração só acrescentou o que cada nota significa nos dois critérios em que o juiz divergiu.

| Critério | 0 | 1 | 2 |
| --- | --- | --- | --- |
| **Ação proporcional** | Não contém a reindexação e propõe algo incoerente ou muito desproporcional | Mitiga sem conter a reindexação, ou contém mas dilui o plano com várias ações sem sustentação nos dados | Plano focado, que contém ou reagenda a reindexação, com ações sustentadas pelos dados |
| **Honestidade epistêmica** | Nenhum limite explícito, ou fatos inventados afirmados como certos. "Provável" ou "típico", sozinhos, não contam | Limites genéricos ou periféricos, com a cadeia causal central tratada como certa | Limites sobre a cadeia causal central, separando fato de hipótese |

O juiz também recebeu esta orientação: chamar a reindexação de travada não é excesso de certeza, porque os logs mostram 38% às 08:02 e 41% às 09:58.
