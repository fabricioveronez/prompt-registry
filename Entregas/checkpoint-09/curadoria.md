# Curadoria: calibração do juiz

O gate reprova corretamente as saídas ruins testadas, e o juiz final concordou com o gabarito nas 40 execuções de calibração. Para chegar a isso, a versão baseada só no texto do enunciado precisou de ajustes: ela já ficava dentro da tolerância de 1 ponto, mas errava a decisão de aprovação na fronteira do corte.

> **PENDENTE, remover antes da entrega:** as notas de `gabarito.json` foram propostas pelo Claude Opus 5.5, que também construiu o gate e escreveu as saídas sintéticas. O enunciado pede a calibração contra a pontuação do aluno. Depois de revisar as notas, substitua este aviso por: "Notas revisadas por Alexandre em <data>; alteradas: <lista ou nenhuma>." Se alguma nota mudar, rode `node devops/analisar-causa-raiz-elasticsearch/calibracao/comparar.cjs Evidências/Checkpoint-09/calibracao-v2.json` e atualize os resultados abaixo.

## Como a calibração foi feita

1. **Conjunto de saídas:** 8 relatórios em `calibracao/saidas/`. Dois são reais: o resultado do Checkpoint 03 e uma execução do `gpt-5.6-luna`. Seis são sintéticos, escritos para testar pontos específicos da rubrica.
2. **Notas antes do juiz:** o `gabarito.json` foi gravado antes da primeira execução do juiz nesse conjunto. A exceção parcial é `real-luna`, que já tinha recebido 8/8 do juiz v1 quando foi pontuada, e essa nota não foi seguida.
3. **Execução do juiz:** o provider `echo` devolve cada saída fixa, de modo que só o juiz chama o modelo.
4. **Comparação:** o `comparar.cjs` verifica a diferença por critério, a decisão de aprovação e a coerência entre notas, `score` e `pass`.

| Saída | O que testa | Decisão esperada |
| --- | --- | --- |
| `real-cp03` | Saída real, com diagnóstico bom e sem limites declarados | Reprova (total 6, com um zero) |
| `real-luna` | Saída real, com plano extenso e limites periféricos | Aprova (total 6) |
| `sint-sintomas` | Culpa o cache | Reprova (total 0) |
| `sint-c4-zero` | Total 6, com certeza fabricada | Reprova pelo zero |
| `sint-c3-zero` | Total 6, com ação desproporcional | Reprova pelo zero |
| `sint-fronteira-6` | Exatamente no corte | Aprova |
| `sint-fronteira-5` | Um ponto abaixo do corte, sem zeros | Reprova |
| `sint-excelente` | Atende a todos os critérios | Aprova (total 8) |

## O que foi ajustado

| Versão | Execuções | Fora da tolerância | Decisões divergentes | Juiz incoerente |
| --- | --- | --- | --- | --- |
| v1: texto do enunciado | 24 | 0 | 4 | 0 |
| v2: com âncoras em C3 e C4 | 40 | 0 | 0 | 0 |

Os detalhes estão em `calibracao-v1.txt` e `calibracao-v2.txt`.

A v1 já cumpria a tolerância pedida, mas isso não bastava: 1 ponto de diferença muda a decisão quando a nota está perto do corte. Os ajustes foram:

- **Honestidade epistêmica:** uma ressalva genérica recebia nota 2, e por isso `sint-fronteira-5` era aprovado nas 3 execuções. A v2 separa limites periféricos (nota 1) de limites sobre a cadeia causal central (nota 2).
- **Palavras de hedge:** `real-cp03` oscilava entre 0 e 1 e foi aprovado em 1 de 3 execuções. Na v2, "provável" e "típico", sozinhos, não contam como limite.
- **"Travada":** o juiz penalizava essa palavra como certeza fabricada, embora a própria rubrica a use. A v2 registra que os logs a sustentam (38% às 08:02 e 41% às 09:58).
- **Ação proporcional:** um plano de 18 ações recebia nota 2. A v2 define que diluir o plano com ações sem sustentação nos dados vale nota 1.

Com isso, o juiz ficou mais exigente nas saídas reais. Em `real-luna`, o total caiu de 8/8 nas 3 execuções da v1 para 6/8 ou 7/8 nas 5 da v2.

## Correção técnica

A primeira configuração usava `value: file://rubrica-juiz.txt` no `llm-rubric`. Nesse caminho, o promptfoo 0.125.1 não renderiza as variáveis: o juiz receberia `{{snapshot_config}}` literal, sem os dados do incidente. Esse problema foi identificado no código do promptfoo antes de a configuração produzir notas. A rubrica passou para `options.rubricPrompt`, e o prompt renderizado foi conferido na saída da execução.

## Testes fora do conjunto de calibração

| Teste | Execuções reprovadas | Notas | Resultado |
| --- | --- | --- | --- |
| Prompt atual, saídas novas | 0 de 8 | C1=2, C2=2, C3=2, C4=1 em todas (7/8) | Passa |
| Prompt com instrução para culpar o cache | 3 de 3 | C1=0 e C2=0 em todas (1/8 ou 2/8) | Barrado, exit 100 |
| Prompt com instrução de "certeza absoluta" e migração | 1 de 3 | Totais 6/8, 7/8 e 5/8 | Barrado, exit 100 |

No último teste, o modelo seguiu só parte da instrução e manteve o diagnóstico correto, então as aprovações individuais são coerentes. Ele mostrou que uma única execução é pouco confiável. Por isso, o config usa `repeat: 3`, e qualquer repetição reprovada barra a mudança. Com `cache: false`, cada alteração recebe geração e julgamento novos, sem flags adicionais.

Esses dois prompts alterados foram cópias temporárias, e o `prompt.md` do repositório não mudou.

## Limitações

- **Risco de superajuste:** as âncoras foram escritas olhando para as mesmas saídas da calibração, e seis delas têm o mesmo autor das notas. Os testes da seção anterior reduzem esse risco, mas não o eliminam.
- **Mesmo modelo:** o gerador e o juiz usam `gpt-5.6-luna`, então podem compartilhar pontos cegos.
- **Regra do zero:** o corte de 6/8 é reforçado pelo `threshold`, mas a regra de nenhum critério zerado depende do `pass` devolvido pelo juiz. Não houve incoerência nas 40 execuções de calibração, porém essa conferência só roda no `comparar.cjs`, fora do gate.
- **Um único incidente:** a rubrica é específica desta reindexação. Outro incidente exige outra rubrica e nova calibração.
- **Honestidade epistêmica nas saídas reais:** as 8 saídas novas ficaram com C4=1, porque o prompt não pede que os limites dos dados sejam declarados. O gate passa, mas esse é o critério mais fraco do prompt atual.
