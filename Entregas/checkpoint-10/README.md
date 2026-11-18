# Checkpoint 10: o playbook em produção contínua

Todos os 9 prompts de `devops/` e `desenvolvimento/` agora têm uma suíte promptfoo. O workflow [`.github/workflows/avaliar-prompts.yml`](../../.github/workflows/avaliar-prompts.yml) roda essas suítes em todo pull request e push na `main`, comenta o resultado no PR e falha o build quando um prompt regride.

## 1. Cobertura de testes

| Prompt | Camada determinística | Juiz LLM | Origem |
| --- | --- | --- | --- |
| `devops/padronizar-comunicacao-alertas` | 5 campos, @ no escalonamento, até 8 linhas, 5 s, US$ 0,01 | não | CP08 |
| `devops/diagnosticar-pods-kubernetes` | pods, causas e falso positivo por snapshot, 5 s, US$ 0,01 | não | CP08 |
| `devops/corrigir-manifesto-network-policy` | estrutura do YAML, sem allow-all, regras de egress e ingress, comentários, 5 s, US$ 0,01 | não | CP08 |
| `devops/analisar-causa-raiz-elasticsearch` | 5 seções, 120 s, US$ 0,05 | rubrica calibrada, corte 6/8 | CP09 |
| `devops/avaliar-manifesto-network-policy-corrigido` | aprova a correção conforme, reprova a com labels inventados, nota coerente com os pesos, 60 s, US$ 0,01 | não | **CP10** |
| `devops/decidir-solucao-backpressure` | 5 seções, 4 caminhos, matriz completa, escolha 🏆, 60 s, US$ 0,01 | restrições do cenário, corte 0,75 | **CP10** |
| `desenvolvimento/diagnosticar-migracao-batch-tempo-real` | 4 seções, 2 caminhos, bloco `<passo1_result>`, dependentes, 120 s, US$ 0,02 | fidelidade aos dados, corte 0,75 | **CP10** |
| `desenvolvimento/planejar-migracao-incremental-batch-tempo-real` | 5 seções, 4 fases, bloco `<passo2_result>`, rollback, 120 s, US$ 0,02 | plano reversível, corte 0,75 | **CP10** |
| `desenvolvimento/especificar-execucao-tatica-migracao-tempo-real` | 4 seções, 2 abordagens, checklist, DLQ, retry, idempotência, lag, schema, 120 s, US$ 0,02 | especificação executável, corte 0,75 | **CP10** |

O critério para usar juiz foi o mesmo do enunciado: determinístico onde der, juiz onde precisar de julgamento. O avaliador de manifesto já produz nota e status, então o teste compara esses campos com o esperado e não precisa de outro modelo. Os relatórios de decisão e de migração precisam de julgamento: "a recomendação respeita o SLA de 60 s" ou "o plano é reversível" não se reduzem a uma busca de texto. Nesses casos, os asserts determinísticos pegam a quebra de formato e de contrato, e o juiz pega a perda de qualidade.

As entradas vieram das execuções originais dos checkpoints 04, 05 e 06 e ficam em `entrada/` na pasta de cada prompt. Os três prompts da cadeia do Forge recebem a saída gravada do passo anterior, e não uma execução ao vivo. Com isso, uma regressão no passo 1 não aparece como falha dos passos 2 e 3.

### O que os testes acharam antes do pipeline

- **Respostas cortadas.** O provider OpenAI do promptfoo limita a saída a 1024 tokens por padrão. Os 4 relatórios longos eram cortados no meio, o que fazia sumir o bloco de exportação e a recomendação. O assert de formato reprovou, e o `tokenUsage` confirmou `completion: 1024` em todas as respostas. Os configs passaram a usar `max_tokens: 8192`.
- **Asserts frágeis.** O modelo alterna entre "retry", "retries" e "backoff", e um `icontains: retry` reprovava 1 a cada 3 saídas. O avaliador às vezes arredonda a nota final para meio ponto (1,725 virou 2,0), o que reprovava a checagem de média ponderada com folga de 0,2. As duas checagens foram corrigidas e conferidas nas saídas gravadas (18 de 18 e 12 de 12).
- **Rubricas que cobravam mais do que o prompt pede.** Ver a decisão 2 abaixo.

## 2. O pipeline

```text
pull request / push na main / segunda 06:00 / manual
        │
        ├── Cobertura de testes ── todo prompt.md tem promptfooconfig.yaml?   (grátis)
        ├── Detectar prompts afetados ── quais pastas de prompt mudaram?      (grátis)
        │
        └── Avaliar <prompt>  (matriz, até 4 em paralelo, uma por prompt afetado)
                promptfoo/promptfoo-action@v1 → 3 repetições, sem cache → comentário no PR
        │
        └── Gate de regressão ── cobertura ok, detecção ok, nenhuma avaliação reprovada
```

- **Cobertura de testes:** [`verificar-cobertura.sh`](../../.github/scripts/verificar-cobertura.sh) falha se algum prompt não tiver suíte. É o que mantém a cobertura total quando alguém adicionar um prompt novo.
- **Detectar prompts afetados:** [`prompts-afetados.sh`](../../.github/scripts/prompts-afetados.sh) compara o PR com a base (ou o push com o commit anterior) e marca a suíte de cada pasta de prompt alterada: `prompt.md`, config, rubrica, entradas. Mudança em `.github/` roda tudo. Sem commit base, também roda tudo.
- **Avaliar:** usa a action oficial com o config de cada prompt. `use-config-prompts: true` mantém o `prompt-sem-frontmatter.cjs` do config, e o glob `prompts` só serve para o comentário citar o arquivo do prompt. A versão do promptfoo é fixada em `0.125.1`, a mesma usada localmente.
- **Gate de regressão:** é o único check que precisa ser obrigatório na proteção da `main`. A matriz tem nomes de job variáveis e é pulada quando nenhum prompt muda, então não serve como check obrigatório.

## 3. Estratégia de gate

**O build falha quando qualquer assert de qualquer suíte afetada reprova em qualquer uma das 3 repetições, incluindo o juiz.** Também falha se algum prompt estiver sem suíte, ou se a chave do fornecedor estiver ausente.

| Camada | Regra | Por quê |
| --- | --- | --- |
| Cobertura | todo `prompt.md` tem `promptfooconfig.yaml` | um prompt sem teste é um prompt sem gate |
| Determinística | formato, contrato com o próximo passo, termos obrigatórios, latência e custo por chamada; 3 de 3 | são estáveis por construção; uma falha é sinal, não ruído |
| Juiz (novos prompts) | `score >= 0,75` e os 2 critérios essenciais atendidos; 3 de 3 | cada rubrica tem 4 critérios ancorados no que o prompt promete |
| Juiz (Elasticsearch) | total `>= 6/8` e nenhum critério zerado; 3 de 3 | regra calibrada contra gabarito no CP09 |

"Regressão" é o que o enunciado define: a mudança piora o prompt em relação à versão anterior. Os limites são absolutos, mas foram fixados de modo que a versão atual de cada prompt passa. Como a `main` só recebe mudança que passou no gate, e o push na `main` roda de novo, a versão anterior sempre cumpre esses limites. Uma reprovação significa que a mudança levou o prompt para baixo de um nível que a versão anterior atingia.

## 4. Justificativa das decisões

### Decisão 1: o que faz o build falhar

| Opção | Ganha | Perde |
| --- | --- | --- |
| **A. Só asserts determinísticos; juiz como comentário** | build nunca falha por flutuação do juiz; mais barato | a regressão de qualidade passa: um relatório bem formatado com recomendação errada é aprovado |
| **B. Determinísticos + juiz, maioria de 2 em 3** (`repeat-min-pass: 2`) | absorve uma oscilação isolada do juiz | aceita uma saída ruim a cada três; e, na action, a regra vale para o teste inteiro, então também relaxa os asserts determinísticos |
| **C. Taxa mínima da suíte** (`fail-on-threshold: 90`) | uma só alavanca para toda a suíte | mistura prompts: uma suíte com 9 testes pode perder um caso inteiro e passar |
| **D. Determinísticos + juiz, 3 de 3 (escolhida)** | pega regressão de formato e de qualidade; regra simples de explicar | uma oscilação do juiz reprova o build; por isso a rubrica precisa ser estável antes de entrar no gate (decisão 2) |

Escolhi D porque A deixa passar exatamente o tipo de regressão que motivou o juiz no CP09: o prompt com instrução para culpar o cache continuava gerando um relatório no formato pedido, e foi o juiz que deu C1=0 e C2=0 (causa-raiz errada) nas 3 execuções. Os asserts determinísticos daquele config conferem só formato, latência e custo, e nenhum deles mede se a causa está certa. B e C trocam o problema do falso positivo pelo do falso negativo, e esconder uma saída ruim em três é pior num gate de produção do que pedir uma rubrica mais bem escrita. O custo de D é ter que medir a estabilidade do juiz antes de ligá-lo. Isso foi feito, e os números estão abaixo.

### Decisão 2: o threshold do juiz e a flutuação

| Opção | Ganha | Perde |
| --- | --- | --- |
| **A. Corte alto (1,0: todos os critérios)** | máxima exigência | a versão atual já não passaria: o backpressure fica em 3 de 4 em todas as execuções |
| **B. Corte baixo (0,5) sem critério essencial** | quase nunca reprova por flutuação | aprova uma recomendação que aceita perda de telemetria, desde que o resto esteja bom |
| **C. Vários juízes e média** | reduz a variância de um juiz só | dobra ou triplica o custo do juiz e a latência do pipeline |
| **D. 0,75 com 2 critérios essenciais e âncoras (escolhida)** | tolera um critério secundário fraco, mas não o essencial; âncoras reduzem a ambiguidade | exige calibrar a rubrica contra a versão atual; margem zero no backpressure |

A flutuação que apareceu nos testes não vinha do juiz ser aleatório: vinha da rubrica ser ambígua. Com os critérios iniciais, o juiz reprovou a versão atual de três prompts:

| Prompt | Execuções do juiz aprovadas antes | Ambiguidade | Âncora adicionada | Depois |
| --- | --- | --- | --- | --- |
| especificar | 3 de 9 | exigia valores de retry e o procedimento de reprocessamento da DLQ, que o prompt não pede | "o prompt não pede valores: a ausência de números não reprova" | 9 de 9 |
| planejar | 1 de 3 | exigia reversão nas 4 fases, inclusive na de preparação, que não afeta produção | reversão nas fases que afetam produção | 9 de 9 |
| diagnosticar | 5 de 6 | contava "latência de segundos" como número inventado | ordens de grandeza de uma tecnologia não contam; o critério mira volumetria | 9 de 9 |
| backpressure | 9 de 9 | nenhuma | nenhuma | 9 de 9 |

A regra que saiu disso: **a rubrica de um gate de regressão cobra só o que o prompt promete.** Um critério que a versão atual não cumpre é meta de melhoria, não regressão. Ele vai para "Limitações conhecidas" no `README.md` do prompt. Se entrasse no gate, todo PR reprovaria até alguém reescrever o prompt.

Com as rubricas finais, foram 36 execuções do juiz nos 4 prompts novos, todas aprovadas, mais 3 de 3 no Elasticsearch. Com zero falhas em 9 execuções por prompt, a regra de três dá um limite superior de cerca de 33% de falha por execução em cada prompt (8% somando as 36). É evidência de estabilidade, não prova. A execução semanal da suíte completa vai acumulando histórico para estreitar esse intervalo.

**Risco conhecido:** o backpressure tirou exatamente 0,75 em todas as execuções, porque o modelo nunca usa a retenção de 4h na justificativa. A nota é estável, mas qualquer outro critério que falhe reprova o build. Isso está correto, porque seria uma piora real, mas é o prompt mais sensível do gate.

### Decisão 3: suíte inteira ou só os prompts alterados

| Opção | Tempo por PR de 1 prompt | Custo por PR de 1 prompt | Risco |
| --- | --- | --- | --- |
| **A. Sempre a suíte inteira** | ~4 a 5 min (9 jobs, 4 em paralelo) | ~US$ 0,12 | menor: pega também a regressão do fornecedor |
| **B. Só alterados, sem varredura periódica** | ~1,5 min | ~US$ 0,01 a 0,05 | uma atualização do modelo pelo fornecedor degrada os prompts sem nenhum PR, e ninguém fica sabendo |
| **C. Só alterados + suíte completa quando o pipeline muda e toda segunda (escolhida)** | ~1,5 min | ~US$ 0,01 a 0,05 por PR + ~US$ 0,12 por semana | regressão do fornecedor detectada em até 7 dias |

Custos medidos na linha de base local ([`execucao-local-baseline.txt`](./execucao-local-baseline.txt)): US$ 0,077 de geração nas 9 suítes. O JSON do promptfoo 0.125.1 não traz o custo do juiz, mas ele consumiu cerca de 46 mil tokens nas 5 suítes com juiz, em sua maioria de entrada; estimo menos de US$ 0,05. O tempo de avaliação vai de 5 s a 43 s por suíte; o restante de cada job é checkout e `npx`.

Escolhi C porque a suíte inteira, a cada PR, gasta 5 a 10 vezes mais para testar prompts que não mudaram, e a única regressão que ela pegaria a mais, a do fornecedor, não depende do PR. Essa regressão é coberta pela execução semanal. O risco de "só alterados" seria uma dependência escondida entre prompts, e ele foi eliminado no desenho dos testes: cada pasta tem seu próprio script de frontmatter e suas próprias entradas, e a cadeia do Forge usa saídas gravadas.

### Decisão 4: o custo de chamar modelo a cada PR

| Opção | Ganha | Perde |
| --- | --- | --- |
| **A. Cache do promptfoo entre execuções** (`actions/cache`) | reexecutar o mesmo commit fica quase grátis | o assert de latência mede o cache, não o modelo; o juiz reaproveita um veredito antigo; e o prompt alterado sempre erra o cache, então o PR não economiza nada |
| **B. Provider falso (`echo`) no PR, modelo real só na `main`** | PR sem custo | a regressão só aparece depois do merge, que é o que o gate deveria impedir |
| **C. Rodar só com rótulo ou aprovação manual** | paga só quando alguém pede | depende de lembrar; o PR pode ser mesclado sem rodar |
| **D. Chamadas reais, limitadas na origem (escolhida)** | resultado real em todo PR | custa centavos por PR |

O custo foi controlado pelo escopo, e não pelo cache:

- só as suítes afetadas rodam (decisão 3);
- um push novo no mesmo PR cancela a execução anterior (`concurrency` com `cancel-in-progress`);
- modelos pequenos para gerar (`gpt-4o-mini`, `gpt-4.1-mini`, `gpt-5.4-mini`), e o juiz só onde precisa;
- cada suíte tem assert de `cost` por chamada, que reprova o build se uma mudança no prompt multiplicar o consumo de tokens;
- `max-parallel: 4` e `max-concurrency: 4` limitam a rajada de chamadas ao fornecedor;
- `timeout-minutes: 20` corta um job travado.

### Decisão 5: onde guardar a chave do fornecedor

| Opção | Ganha | Perde |
| --- | --- | --- |
| **A. Secret do repositório (escolhida)** | simples; o Actions mascara o valor no log; PRs de fork não recebem o secret | qualquer pessoa com permissão de escrita pode criar um workflow que lê o secret |
| **B. Secret de environment com revisores obrigatórios** | o job só recebe a chave depois de aprovação | todo PR fica esperando alguém aprovar o job |
| **C. Gateway com chave própria e limite de gasto** (proxy, OIDC) | a chave real nunca chega ao runner; dá para limitar gasto por origem | mais infraestrutura do que um repositório de uma pessoa justifica |
| **D. `.env` versionado** | nenhum | expõe a chave; descartado |

Escolhi A porque o repositório tem um único mantenedor, então o risco da escrita interna não existe na prática. Com mais colaboradores, a evolução natural é B. Duas medidas complementam o secret:

- usar uma chave dedicada ao CI, em um projeto da OpenAI com limite de gasto mensal, para que um vazamento ou um laço tenha teto;
- usar `pull_request` e não `pull_request_target`: PRs de fork rodam sem o secret, e o job falha com uma mensagem explícita ("secret ausente"), em vez de um erro de autenticação no meio da avaliação.

### Decisão 6: quando rodar

| Opção | Ganha | Perde |
| --- | --- | --- |
| **A. Push em qualquer branch + PR** | literalmente "todo push" | cada commit de um PR roda duas vezes e paga duas vezes |
| **B. Só PR** | sem duplicidade | push direto na `main` e o resultado do merge ficam sem verificação |
| **C. PR + push na `main` + semanal + manual (escolhida)** | gate antes do merge, conferência depois do merge, varredura do fornecedor | push em branch sem PR não é avaliado até abrir o PR |

### Decisão 7: comparar com a versão anterior

| Opção | Ganha | Perde |
| --- | --- | --- |
| **A. Rodar base e head e comparar as notas** | mede a piora diretamente | dobra o custo; com 3 amostras por lado, a diferença entre as médias do juiz é menor que o ruído |
| **B. Limites absolutos que a versão atual cumpre (escolhida)** | uma rodada só; o limite tem significado ("tem a matriz", "não aceita perda") | uma melhoria não sobe o limite sozinha; é preciso endurecer o teste à mão |

A action oficial também avalia só o checkout atual; ela não faz a comparação base × head. Com B, "piorou em relação à versão anterior" vira "deixou de cumprir algo que a versão anterior cumpria", que é verificável numa execução só.

## 5. Evidências

### Execução local

- [`execucao-local-baseline.txt`](./execucao-local-baseline.txt): suíte completa dos 9 prompts. 8 passaram de primeira; o avaliador reprovou 1 de 6 na checagem de média ponderada, o que levou à folga de 0,3 descrita na seção 1.
- [`execucao-local-regressao.txt`](./execucao-local-regressao.txt): duas regressões provocadas no prompt de backpressure.
  - **Estrutural** ([`regressao-backpressure.patch`](./regressao-backpressure.patch)): um "enxugamento" que remove do template a etapa de trade-offs e a matriz comparativa. Reprovou em `formato` e `matriz_completa` nas 3 repetições, exit 100.
  - **Instrução para aceitar descarte de mensagens:** o modelo ignorou a instrução, porque o cenário proíbe perda, e as 3 saídas passaram. O gate mede o comportamento, não o texto do prompt; uma mudança que não piora a saída não é regressão.
- [`execucao-local-juiz.txt`](./execucao-local-juiz.txt): falha barrada só pelo juiz, e a correção que a resolve (ver seção 5.1).

### 5.1 Falha no julgamento do juiz e correção

A regressão estrutural acima é barrada pelos asserts determinísticos. Para mostrar o juiz barrando sozinho uma piora, a mudança precisava manter o formato e piorar o conteúdo. Ela foi feita no `diagnosticar-migracao-batch-tempo-real`, em duas versões do prompt.

**v1.1.0, a "melhoria" que regride.** Para dar concretude ao dimensionamento, a seção 1 do template passou a pedir eventos por segundo, volume por hora e número de partições, "sem termos como estimado ou não informado". A documentação do Forge não traz nenhum desses números. O modelo obedeceu e inventou valores (1.000 eventos/s, 3,6 milhões de eventos/hora, 1 partição por hora), apresentados como fatos.

| Camada | Resultado em 2 execuções (6 saídas) |
| --- | --- |
| Determinística (formato, caminhos, `<passo1_result>`, dependentes, latência, custo) | 6 de 6 em todos os asserts |
| Juiz, critério D3 ("não inventa números de volumetria") | 0 de 6; nota 0,75, reprovada porque D3 é essencial |

Sem o juiz, essa versão teria sido mesclada: o relatório está no formato pedido e traz tudo o que os asserts procuram. O passo 2 da cadeia receberia números falsos como base do plano de migração.

**v1.1.1, a correção.** Mantém o pedido de volumetria, mas exige separar dado de estimativa. A primeira versão da correção não bastou, e a evidência registra as três tentativas:

| Tentativa | Mudança | Juiz | O que ainda falhava |
| --- | --- | --- | --- |
| A | marcar como `[estimativa]` o que não estiver no snapshot | 2 de 3 | "1 partição por hora", deduzido de "particionadas por hora", sem marca |
| B | marcar também os números deduzidos do snapshot | 3 de 6 | o mesmo, agora "24 partições/dia" |
| **v1.1.1** | B, sem pedir o número de partições | **6 de 6, nota 1,0** | nada |

O número de partições foi retirado porque não é volumetria e é ambíguo (partição da tabela ou do tópico). Com ele no pedido, o modelo sempre tinha um valor "deduzível" para afirmar. A lição para o playbook: quando o juiz reprova, a correção mira a causa que ele aponta na justificativa (aqui, sempre o mesmo número), e não o texto do prompt em geral.

### Execução no GitHub Actions

> **PENDENTE, preencher após as execuções:** link da execução verde (PR com este checkpoint), link da execução vermelha (PR com `regressao-backpressure.patch`) e captura do comentário da action em cada PR.
>
> **PENDENTE, falha no juiz:** link da execução vermelha do PR `feat/checkpoint-10-juiz` (v1.1.0), com o trecho do log em que `diagnostico_fiel` reprova, e link da execução verde no mesmo PR depois do push da v1.1.1.

Passos para gerar:

1. Cadastrar `OPENAI_API_KEY` em *Settings → Secrets and variables → Actions → New repository secret*.
2. Abrir o PR deste branch para a `main`. Como `.github/` mudou, a suíte completa roda: são 9 jobs de avaliação, que devem passar.
3. Em *Settings → Branches*, exigir o check `Gate de regressão` na `main`.
4. Criar um branch a partir deste, aplicar `git apply Entregas/checkpoint-10/regressao-backpressure.patch`, fazer commit e abrir PR. Só `devops/decidir-solucao-backpressure` deve rodar, e o gate deve ficar vermelho com o merge bloqueado.
5. Falha no juiz: enviar `feat/checkpoint-10-juiz` (só a v1.1.0) e abrir PR para a `main`. Só o diagnóstico roda; os asserts determinísticos passam e `diagnostico_fiel` reprova.
6. Correção: trazer a v1.1.1 para o mesmo branch (`git merge --ff-only feat/checkpoint-10-juiz-correcao`) e enviar. O mesmo PR roda de novo e fica verde.

## 6. Limitações

- **Uma entrada por prompt na maioria das suítes.** O gate pega regressão nesse caso, não em qualquer entrada. Mais casos aumentam o custo de forma linear.
- **Rubricas dos prompts novos sem gabarito humano.** Elas foram ajustadas contra a versão atual (todas as saídas deveriam passar), mas não contra saídas ruins conhecidas, como foi feito no CP09. A regressão estrutural foi barrada pelos asserts determinísticos. Até agora, só uma saída ruim foi barrada apenas pelo juiz: a v1.1.0 do diagnóstico (seção 5.1).
- **Gerador e juiz são do mesmo fornecedor.** Uma degradação comum aos dois modelos passaria. Um juiz de outro fornecedor exige uma segunda chave.
- **O comentário da action é mínimo.** Ele traz só a contagem de sucessos e falhas, cria um comentário novo a cada execução e não diz qual assert reprovou. O detalhe fica no log do job.
- **Push sem PR em outros branches não é avaliado** (decisão 6).

## 7. O que isso prepara

O pipeline já transforma o catálogo num artefato com contrato: cada prompt tem entrada, saída esperada, custo e latência máximos, e um check que impede o merge de uma versão pior. É a base para as automações seguintes: um agente que propõe melhorias de prompt pode abrir PRs, e o mesmo gate decide se a mudança entra. A execução semanal também é o embrião de um monitor de drift do fornecedor.
