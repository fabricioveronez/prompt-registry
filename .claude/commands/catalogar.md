---
description: Organiza um prompt recebido como argumento no catálogo, inferindo metadados e atualizando índices sob aprovação humana.
---

# /catalogar

Recebe um prompt como argumento, analisa, infere metadados, classifica em uma categoria, propõe a organização e — após aprovação explícita do usuário — escreve os arquivos e atualiza todos os índices do catálogo, sem fazer commit.

## O que este comando faz

- Lê o texto do prompt a partir de `$ARGUMENTS`.
- Infere nome, descrição, tags e descrição dos placeholders `{{...}}` a partir do texto.
- Classifica em uma das categorias existentes ou sugere uma nova.
- Propõe o plano completo de organização e aguarda o "ok" do usuário antes de escrever qualquer arquivo.
- Na aplicação, cria `prompt.md` + `README.md` do prompt e atualiza o `README.md` da categoria e o `README.md` raiz.

## O que este comando NÃO faz

- **Não modifica o texto do prompt.** O corpo do `prompt.md` é gravado exatamente como recebido em `$ARGUMENTS`, byte a byte, preservando quebras de linha, indentação e espaços.
- **Não cria categoria nova sem aprovação.** Se nenhuma das 5 categorias existentes servir, propõe uma nova (slug + escopo) e aguarda confirmação.
- **Não faz commit.** Usuário revisa e commita manualmente.
- **Não inventa informação fora do texto.** Campos que não dão para inferir viram `_A preencher_` no README.

---

## Fase A — Análise

Execute na ordem abaixo quando o comando for invocado.

### A1. Validar entrada

- Se `$ARGUMENTS` estiver vazio ou conter apenas espaços/quebras de linha, responder ao usuário: "Preciso do texto do prompt como argumento. Uso: `/catalogar <texto do prompt>`." e encerrar.
- Caso contrário, tratar `$ARGUMENTS` como o **texto cru do prompt** (o corpo que irá para `prompt.md` após o frontmatter).

### A2. Ler contexto do repositório

Ler na ordem:

1. `CLAUDE.md` da raiz — conferir convenções vigentes, especialmente a seção "Frontmatter padrão".
2. `README.md` da raiz — mapear a ordem das categorias e o formato dos índices.
3. Os 5 READMEs de categoria:
   - `criacao-conteudo/README.md`
   - `desenvolvimento/README.md`
   - `devops/README.md`
   - `financas/README.md`
   - `produtividade/README.md`

   Extrair de cada um: nome da categoria, seção "Escopo" e seção "Fora de escopo".

### A3. Extrair placeholders

Aplicar regex estrita sobre o texto do prompt: `\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}`.

- Lista deduplicada dos nomes encontrados.
- Se o texto usa formatos alternativos (`<x>`, `{x}`, `[[x]]`), **não interpretar** — a lista de `inputs` fica vazia e esse fato é comunicado no plano apresentado.

### A4. Inferir metadados

A partir do texto do prompt, inferir:

- **`nome`**: título humano curto em pt-BR, capitalizado (ex.: "Revisar Pull Request"). Deriva do objetivo central do prompt, não da técnica usada.
- **`descricao`**: uma única linha descrevendo o objetivo — é o que aparecerá nos índices.
- **`tags`**: 2 a 5 termos livres em pt-BR que descrevem o domínio e a ação do prompt.
- **`descricao` de cada input**: o que a variável representa, inferido pelo contexto em que aparece no prompt.
- Conteúdo das seções do README:
  - **Objetivo** (parágrafo curto baseado no texto do prompt).
  - **Quando usar** (2 a 4 bullets inferidos do contexto).
  - **Exemplo de uso** — tentar inferir a partir do texto; se não houver base concreta, gravar `_A preencher_`.
  - **Limitações conhecidas** — idem; se não houver base concreta, `_A preencher_`.

Regra de honestidade: **nunca inventar informação que não esteja no próprio texto do prompt**. Na dúvida, `_A preencher_`.

### A5. Classificar a categoria

Para cada uma das 5 categorias existentes, comparar o tema do prompt com os trechos "Escopo" e "Fora de escopo" dos respectivos READMEs. Escolher a categoria cujo "Escopo" dá o melhor match.

Apresentar a escolha com **justificativa citando o trecho do escopo** que deu match (ex.: *"Casa com `desenvolvimento/` — seu escopo lista 'Escrita e revisão de código', que é exatamente o que este prompt faz."*).

Se **nenhuma** categoria existente casar bem, propor categoria nova:

- Slug kebab-case para a nova categoria (ex.: `saude-bem-estar`, `educacao`).
- Escopo proposto em 1 parágrafo + lista de "Entram aqui" + lista de "Fora de escopo" citando referências para categorias existentes adjacentes.

### A6. Gerar slug do prompt

Gerar slug kebab-case descrevendo **o resultado** do prompt, não a técnica.

- ✅ `revisar-pull-request`, `gerar-email-follow-up`, `planejar-sprint`.
- ❌ `prompt-chain-of-thought`, `few-shot-exemplo`, `template-revisao`.

### A7. Verificar duplicidade

- Se `<categoria>/<slug>/` já existir, alertar o usuário, sugerir slug alternativo (ex.: acrescentar um qualificador: `revisar-pull-request-seguranca`) e aguardar decisão antes de continuar.

### A8. Apresentar o plano

Montar resposta ao usuário contendo, exatamente, nesta ordem:

1. **Categoria**: nome + justificativa (ou proposta de categoria nova + escopo).
2. **Slug**: `<slug>` e caminho final `<categoria>/<slug>/`.
3. **Frontmatter inferido** (YAML pronto, idêntico para os dois arquivos):
   ```yaml
   nome: ...
   descricao: ...
   versao: 1.0.0
   tags: [...]
   inputs:
     - nome: ...
       descricao: ...
   ```
   Usar tags inline `[a, b, c]` quando houver até 5; expandir em uma por linha quando houver 6+.
4. **Preview do `prompt.md`**: mostrar o frontmatter + as primeiras 3 a 5 linhas do texto do prompt exatamente como recebido (para o usuário confirmar que a integridade está preservada).
5. **Preview do `README.md`**: frontmatter + corpo completo (`# <nome>`, `## Objetivo`, `## Quando usar`, `## Exemplo de uso`, `## Limitações conhecidas`).
6. **Arquivos de índice que serão atualizados**, listados explicitamente:
   - `<categoria>/README.md`
   - `README.md` (raiz)
   - Se categoria nova: também `<nova-categoria>/README.md` (a ser criado) e nova seção no `README.md` raiz.
7. **Avisos** (se aplicável): inputs vazio porque o prompt usa placeholders em formato diferente; campos marcados como `_A preencher_`; duplicidade de slug resolvida; etc.

Encerrar a Fase A com a frase:

> Aprove com "ok" / "pode criar" / "aprovado" para aplicar, ou me diga o que ajustar.

Qualquer resposta diferente de uma aprovação explícita = **iterar na análise** (ajustar categoria/slug/campos conforme o feedback) e reapresentar o plano. **Não escrever arquivos sem aprovação.**

---

## Fase B — Aplicação (só após aprovação explícita)

### B1. Criar a pasta do prompt

Criar o diretório `<categoria>/<slug>/`.

### B2. Criar `prompt.md`

Conteúdo, nesta ordem:

1. Bloco de frontmatter YAML entre `---` delimitadores, com os campos `nome`, `descricao`, `versao`, `tags`, `inputs` (idêntico ao apresentado no plano).
2. Linha em branco.
3. **Texto do prompt exatamente como recebido em `$ARGUMENTS`** — sem remover espaços, sem reformatar, sem adicionar cabeçalho, sem remover quebras de linha.

### B3. Criar `README.md` do prompt

Conteúdo, nesta ordem:

1. O **mesmo frontmatter** do `prompt.md` (byte a byte igual).
2. Linha em branco.
3. `# <nome>` (o mesmo `nome` do frontmatter).
4. `## Objetivo` + parágrafo inferido.
5. `## Quando usar` + bullets inferidos.
6. `## Exemplo de uso` + conteúdo inferido ou `_A preencher_`.
7. `## Limitações conhecidas` + conteúdo inferido ou `_A preencher_`.

### B4. Atualizar `<categoria>/README.md`

Na seção `## Prompts`:

- Se a seção contém exatamente `_Nenhum prompt cadastrado ainda._`, substituir essa linha por:
  ```
  - [<slug>](./<slug>/) — <descricao>.
  ```
- Caso contrário (já existem prompts listados), **anexar** a linha acima ao final da lista existente, preservando a ordem atual.

### B5. Atualizar `README.md` raiz

Localizar a seção da categoria (a ordem fixa é **Desenvolvimento → DevOps → Produtividade → Finanças → Criação de Conteúdo**; se for categoria nova, vai ao final).

Aplicar a mesma mecânica da B4: substituir `_Nenhum prompt cadastrado ainda._` pela linha do prompt na primeira vez; anexar à lista existente nas próximas.

Formato da linha no índice raiz (caminho relativo inclui a categoria):
```
- [<slug>](./<categoria>/<slug>/) — <descricao>.
```

### B6. Se for categoria nova

Antes das etapas B4/B5:

1. Criar `<nova-categoria>/README.md` com a estrutura padrão das categorias existentes:
   ```markdown
   # <Nome da Categoria>

   <Parágrafo descritivo do escopo.>

   ## Escopo

   - <bullet>
   - <bullet>

   ## Fora de escopo

   - <bullet com redirecionamento para categoria adjacente, se aplicável>

   ## Prompts

   - [<slug>](./<slug>/) — <descricao>.
   ```
2. Adicionar nova seção no `README.md` raiz **ao final da lista de categorias**, seguindo o formato visual das seções existentes:
   ```markdown
   ### [<Nome da Categoria>](./<nova-categoria>/)

   <Parágrafo curto sobre o escopo.>

   - [<slug>](./<categoria>/<slug>/) — <descricao>.
   ```

### B7. Reportar e encerrar

Listar ao usuário, em ordem, todos os arquivos criados e atualizados com caminhos absolutos relativos à raiz do repositório. Mencionar explicitamente:

- Quais campos ficaram como `_A preencher_` (se houver).
- Se a lista de `inputs` ficou vazia por o prompt usar placeholders fora do padrão `{{...}}`.
- Se a categoria for `devops/` ou `desenvolvimento/`: o prompt ainda precisa de um `promptfooconfig.yaml` na própria pasta (ver "Testes com promptfoo" no `CLAUDE.md`). Sem ele, o job "Cobertura de testes" do pipeline reprova o pull request.
- Que **nenhum commit foi feito** — revisar com `git status` / `git diff` e commitar manualmente quando estiver satisfeito.

---

## Regras gerais (válidas para toda execução do comando)

1. **Integridade do texto do prompt é inviolável.** O corpo do `prompt.md` é byte a byte igual ao `$ARGUMENTS` recebido. Qualquer alteração (incluindo "correções" ortográficas, reformatação, etc.) é proibida.
2. **Frontmatter idêntico nos dois arquivos.** `prompt.md` e `README.md` carregam exatamente o mesmo bloco YAML.
3. **Nunca inferir além do que o texto oferece.** Se não há base concreta, usar `_A preencher_` e informar isso ao usuário no reporte final.
4. **Nunca escrever antes da aprovação.** Fase A apresenta o plano; Fase B só roda após um "ok" / "pode criar" / "aprovado" explícito.
5. **Nunca fazer commit.** Commit é responsabilidade humana após revisão.
6. **Respeitar a ordem fixa de categorias no README raiz**: Desenvolvimento → DevOps → Produtividade → Finanças → Criação de Conteúdo → (novas, ao final).
