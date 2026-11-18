# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Propósito do repositório

Catálogo de prompts em Markdown organizados por categoria / área de domínio. Não há código executável, build ou pipeline — é um repositório documental cuja qualidade é medida pela clareza dos prompts, pela consistência da estrutura e, nos prompts que têm `promptfooconfig.yaml`, pelos testes de promptfoo.

Compõe o material dos projetos da pós-graduação em AIOps e Inteligência Artificial com Engenharia Cloud ([pos.veronez.io/pos-aiops](https://pos.veronez.io/pos-aiops/)) — decisões de escopo e convenções devem considerar esse uso didático.

## Estrutura obrigatória

```
<categoria>/
  <nome-do-prompt>/
    prompt.md    # o prompt em si (conteúdo que será copiado/usado)
    README.md    # metadados e documentação do prompt
    promptfooconfig.yaml    # testes do prompt com promptfoo (obrigatório em devops/ e desenvolvimento/)
    prompt-sem-frontmatter.cjs    # envia o prompt aos testes sem o frontmatter
    entrada/ ou incidente/    # entradas fixas usadas pelos testes
```

Regras:
- **Categoria** = pasta na raiz (ex.: `engenharia-software/`, `escrita/`, `analise-dados/`). Uma categoria por área de domínio; não aninhar categorias.
- **Prompt** = subpasta dentro de uma categoria, nomeada em `kebab-case` descrevendo o objetivo do prompt.
- **`prompt.md`** contém o frontmatter YAML de metadados (ver seção "Frontmatter padrão") seguido do texto do prompt, preservado integralmente. Nenhuma explicação sobre o prompt entra nesse arquivo — apenas metadados estruturados + o texto que será usado.
- **`README.md`** começa com o **mesmo frontmatter** do `prompt.md` e, abaixo, traz a documentação humana do prompt: objetivo, quando usar, exemplo de uso/saída, limitações conhecidas.

A separação `prompt.md` × `README.md` continua intencional — `prompt.md` carrega o texto + metadados consumíveis por ferramentas; `README.md` adiciona a camada humana (objetivo, quando usar, exemplo, limitações) acima do mesmo frontmatter.

## Ao adicionar um novo prompt

Use o slash command [`/catalogar`](./.claude/commands/catalogar.md) sempre que possível — ele cuida da análise, classificação de categoria, geração do frontmatter e atualização dos 4 arquivos de documentação sob aprovação humana, sem fazer commit. Caso opte por fazer manualmente, siga as regras abaixo:

1. Escolher a categoria existente que melhor se encaixa antes de criar uma nova.
2. Se criar categoria nova, adicionar um `README.md` na raiz da categoria explicando o escopo dela.
3. Nomear a pasta do prompt descrevendo o *resultado*, não a técnica (ex.: `revisar-pr` é melhor que `prompt-chain-of-thought`).
4. Manter o **texto do prompt** autocontido — não referenciar o `README.md` nem outros arquivos do repo, pois o prompt será extraído do contexto. Essa regra se aplica ao corpo do prompt; o frontmatter é parte da estrutura e não viola a autocontenção.

## Convenções de conteúdo

- Prompts e documentação em **português (pt-BR)** por padrão, salvo quando o prompt for especificamente voltado a tooling/modelos que exijam inglês — nesse caso, registrar o motivo no `README.md`.
- Placeholders no corpo do `prompt.md` usar o formato `{{nome_variavel}}` e aparecer listados no campo `inputs` do frontmatter (mesma lista em `prompt.md` e `README.md`).

## Frontmatter padrão

Todo prompt tem um bloco de frontmatter YAML no topo de `prompt.md` **e** de `README.md`, idêntico nos dois arquivos. Campos obrigatórios:

```yaml
---
nome: Nome humano do prompt
descricao: Uma linha descrevendo o objetivo do prompt
versao: 1.0.0
tags: [tag1, tag2]
inputs:
  - nome: variavel_um
    descricao: O que essa variável representa
  - nome: variavel_dois
    descricao: O que essa variável representa
---
```

Regras:

- **`nome`**: título humano curto, em pt-BR, capitalizado. Não é o slug da pasta.
- **`descricao`**: uma única linha descrevendo o objetivo; é o texto que aparece no índice das categorias e no índice raiz.
- **`versao`**: semver `MAJOR.MINOR.PATCH`. Versão inicial de todo prompt é `1.0.0`. Incrementar manualmente ao evoluir.
- **`tags`**: 2 a 5 termos livres em pt-BR. Formato inline `[a, b, c]` até 5 tags; lista expandida (uma por linha) quando tiver 6+.
- **`inputs`**: lista com um item por placeholder `{{...}}` presente no corpo do prompt. Cada item tem `nome` (sem `{{}}`) e `descricao` (o que a variável representa). Se o prompt não tiver placeholders, usar `inputs: []`.

**Duplicação consciente**: o frontmatter é idêntico em `prompt.md` e `README.md`. Edições manuais precisam ser replicadas nos dois arquivos — prefira usar `/catalogar` para evitar divergência.

## Testes com promptfoo

Todo prompt de `devops/` e `desenvolvimento/` tem um `promptfooconfig.yaml` na própria pasta. O pipeline barra prompt novo sem config (ver "Pipeline de avaliação"). Caminhos `file://` são relativos à pasta do config.

As entradas fixas dos testes ficam em `incidente/` (prompts de incidente) ou `entrada/` (demais prompts). Os três prompts da cadeia do Forge (`desenvolvimento/`) são testados com a saída gravada do passo anterior, e não com uma execução ao vivo, para que uma regressão de um passo não apareça como falha do seguinte.

O provider OpenAI do promptfoo limita a resposta a 1024 tokens por padrão. Prompts de relatório longo precisam de `config.max_tokens` no provider, senão a saída é cortada e os asserts de formato reprovam.

O promptfoo envia o `prompt.md` inteiro, incluindo o frontmatter. Para enviar só o texto do prompt, use um script como `devops/padronizar-comunicacao-alertas/prompt-sem-frontmatter.cjs`, referenciado em `prompts:` com `file://prompt-sem-frontmatter.cjs`.

Em `llm-rubric`, um `value: file://...` não recebe as variáveis do teste, e `.md` não é aceito nesse campo. Se a rubrica estiver em arquivo e usar variáveis, referencie-a em `options.rubricPrompt`. Esse arquivo precisa incluir `{{output}}` e pedir a resposta em JSON.

Os prompts de saída estruturada (`padronizar-comunicacao-alertas`, `diagnosticar-pods-kubernetes` e `corrigir-manifesto-network-policy`) têm testes determinísticos com limites de 5 s e US$ 0,01 por chamada. `avaliar-manifesto-network-policy-corrigido` também é só determinístico: ele já emite nota e status, e o teste confere se aprova uma correção conforme e reprova uma com labels inventados. Os limites de latência exigem chamadas reais, então todos os configs usam `cache: false`.

`decidir-solucao-backpressure` e os três prompts de `desenvolvimento/` combinam asserts determinísticos (formato, blocos de exportação, termos obrigatórios, latência, custo) com um `llm-rubric` de 4 critérios escrito no próprio config. Cada rubrica cobra só o que o prompt pede: um critério que a versão atual não cumpre vira limitação no `README.md`, não requisito do gate.

`devops/analisar-causa-raiz-elasticsearch/` tem um gate de qualidade com juiz LLM e arquivos além da estrutura padrão:

- `rubrica-juiz.txt`: rubrica aplicada pelo juiz.
- `incidente/`: snapshots usados como entrada dos testes.
- `calibracao/`: saídas fixas, gabarito humano, config e script para comparar o juiz com o gabarito.

Ao alterar `rubrica-juiz.txt`, recalibre o juiz conforme o `README.md` do prompt.

As chaves de API ficam em um `.env` na raiz, ignorado pelo Git. Para rodar a partir da raiz:

```bash
npx promptfoo@latest eval -c <categoria>/<nome-do-prompt>/promptfooconfig.yaml
npx promptfoo@latest view
```

## Pipeline de avaliação

[`.github/workflows/avaliar-prompts.yml`](./.github/workflows/avaliar-prompts.yml) roda as suítes no GitHub Actions com a action oficial `promptfoo/promptfoo-action`, fixada na versão 0.125.1 do promptfoo:

- **Gatilhos:** pull request e push na `main` que alterem `devops/`, `desenvolvimento/` ou `.github/`; suíte completa toda segunda-feira e por disparo manual.
- **Seleção:** [`.github/scripts/prompts-afetados.sh`](./.github/scripts/prompts-afetados.sh) roda só as suítes das pastas de prompt alteradas. Mudança em `.github/` roda todas.
- **Cobertura:** [`.github/scripts/verificar-cobertura.sh`](./.github/scripts/verificar-cobertura.sh) falha se algum `prompt.md` não tiver `promptfooconfig.yaml`.
- **Gate:** qualquer assert reprovado em qualquer repetição falha o job. O job `Gate de regressão` consolida o resultado e é o check obrigatório da `main`.
- **Chave:** `OPENAI_API_KEY` fica em um secret do repositório.

A estratégia de gate e a justificativa das escolhas estão em [`Entregas/checkpoint-10/README.md`](./Entregas/checkpoint-10/README.md). Ao criar uma categoria nova com prompts testados, inclua-a em `CATEGORIAS` nos dois scripts e em `paths` no workflow.

## Manutenção da documentação

Sempre que um prompt ou uma categoria for **incluído ou alterado**, revisar e atualizar:

1. **`CLAUDE.md`** — verificar se as regras, estrutura ou convenções aqui descritas continuam refletindo o estado real do repositório; ajustar seções desatualizadas.
2. **`README.md` da raiz** — índice geral do catálogo; atualizar a listagem de categorias e/ou prompts quando algo for adicionado, renomeado ou removido.
3. **`README.md` da categoria** — garantir que o escopo descrito ainda contempla os prompts existentes; atualizar quando um prompt novo ampliar ou redefinir o escopo.
4. **`README.md` do prompt** — manter objetivo, exemplo de uso e limitações alinhados ao conteúdo atual de `prompt.md`; garantir que o frontmatter esteja idêntico ao do `prompt.md`.

A revisão da documentação faz parte da mesma entrega que a mudança do prompt — não deve ficar para depois.

## Git

- Semantic commit, mensagem de uma linha.
- Escopo do commit costuma ser a categoria (ex.: `feat(escrita): adiciona prompt de revisão de email`).
