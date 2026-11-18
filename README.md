# Catálogo de prompts

Coleção de prompts em Markdown organizados por categoria/área de domínio. Cada prompt vive em sua própria pasta, contendo o arquivo `prompt.md` (texto puro, pronto para copiar e colar) e um `README.md` com metadados, variáveis e exemplos de uso.

Este repositório faz parte do material dos projetos da pós-graduação em AIOps e Inteligência Artificial com Engenharia Cloud: [pos.veronez.io/pos-aiops](https://pos.veronez.io/pos-aiops/).

Convenções de estrutura, nomenclatura e manutenção estão em [`CLAUDE.md`](./CLAUDE.md).

## Como usar

1. Navegar até a categoria de interesse.
2. Abrir o `README.md` do prompt para entender objetivo, variáveis esperadas e limitações.
3. Copiar o conteúdo do `prompt.md` e substituir os placeholders `{{nome_variavel}}` pelos valores desejados.

## Adicionando um prompt

Use o slash command [`/catalogar`](./.claude/commands/catalogar.md) passando o texto do prompt como argumento. Ele analisa, propõe organização (categoria, slug, frontmatter) e, após sua aprovação, escreve os arquivos e atualiza os índices — sem commitar. Convenções completas em [`CLAUDE.md`](./CLAUDE.md).

## Testes e pipeline

Cada prompt de `devops/` e `desenvolvimento/` tem uma suíte [promptfoo](https://www.promptfoo.dev) no `promptfooconfig.yaml` da própria pasta. O workflow [`avaliar-prompts.yml`](./.github/workflows/avaliar-prompts.yml) roda as suítes dos prompts alterados em todo pull request e push na `main`, comenta o resultado no PR e falha o build quando um prompt regride. A estratégia do gate está em [`Entregas/checkpoint-10/README.md`](./Entregas/checkpoint-10/README.md).

Para rodar uma suíte localmente, com `OPENAI_API_KEY` em um `.env` na raiz:

```bash
npx promptfoo@latest eval -c <categoria>/<nome-do-prompt>/promptfooconfig.yaml
```

## Categorias

### [Desenvolvimento](./desenvolvimento/)

Escrita, revisão e refatoração de código, design de APIs e arquitetura, debugging, testes e documentação técnica.

- [diagnosticar-migracao-batch-tempo-real](./desenvolvimento/diagnosticar-migracao-batch-tempo-real/) — Analisa a documentação de um sistema em processamento em lote (Forge), mapeia gargalos e acoplamentos e compara caminhos arquiteturais para tempo real, com recomendação e bloco de exportação para o próximo passo.
- [planejar-migracao-incremental-batch-tempo-real](./desenvolvimento/planejar-migracao-incremental-batch-tempo-real/) — Define a estratégia de rollout e o roadmap passo a passo da migração incremental do Forge, com coexistência entre lote e tempo real, matriz de riscos, plano de rollback e bloco de exportação para o próximo passo.
- [especificar-execucao-tatica-migracao-tempo-real](./desenvolvimento/especificar-execucao-tatica-migracao-tempo-real/) — Transforma o plano de migração do Forge em especificação executável, com padrões de resiliência e garantia de entrega, contratos de eventos, DLQ e retry, plano de observabilidade e checklist de validação do cutover.

### [DevOps](./devops/)

Pipelines de CI/CD, containers, orquestração, infraestrutura como código, observabilidade, SRE e segurança operacional.

- [diagnosticar-pods-kubernetes](./devops/diagnosticar-pods-kubernetes/) — Analisa um snapshot de pods, eventos e logs do Kubernetes e entrega a causa raiz provável com ações para o plantão.
- [padronizar-comunicacao-alertas](./devops/padronizar-comunicacao-alertas/) — Converte um snapshot de alertas brutos de monitoramento em comunicados de incidente padronizados com alerta, impacto, hipótese, ação imediata e escalonamento.
- [analisar-causa-raiz-elasticsearch](./devops/analisar-causa-raiz-elasticsearch/) — Correlaciona configuração, métricas (2h) e logs de um cluster Elasticsearch via Cerebro e entrega um relatório RCA de incidente que afetou uma aplicação Java.
- [decidir-solucao-backpressure](./devops/decidir-solucao-backpressure/) — Analisa um cenário de backpressure em sistemas distribuídos e compara caminhos de solução, entregando um relatório de trade-offs com recomendação e plano de implementação.
- [corrigir-manifesto-network-policy](./devops/corrigir-manifesto-network-policy/) — Compara um manifesto Kubernetes com o padrão oficial de NetworkPolicy e a lista de serviços e labels permitidos, e entrega o manifesto corrigido com relatório de divergências e justificativas.
- [avaliar-manifesto-network-policy-corrigido](./devops/avaliar-manifesto-network-policy-corrigido/) — Audita um manifesto Kubernetes corrigido por modelo de linguagem, verificando fidelidade aos dados, conformidade com NetworkPolicy, validade do YAML e resolução de divergências, e emite nota de 0.0 a 5.0 com parecer final.

### [Produtividade](./produtividade/)

Organização pessoal, gestão de tempo e tarefas, rotina, hábitos, foco e decisões sobre fluxo de trabalho individual.

_Nenhum prompt cadastrado ainda._

### [Finanças](./financas/)

Orçamento, investimentos, planejamento financeiro, impostos e apoio a decisões financeiras.

_Nenhum prompt cadastrado ainda._

### [Criação de Conteúdo](./criacao-conteudo/)

Roteiros, artigos, posts para redes sociais, material didático e copy de divulgação.

_Nenhum prompt cadastrado ainda._

<!--
Ao adicionar um prompt, substituir "Nenhum prompt cadastrado ainda" pela lista:

- [nome-do-prompt](./<slug-da-categoria>/<slug-do-prompt>/) — o que o prompt faz, em uma linha.
-->

## Contribuindo

Antes de adicionar ou alterar um prompt, revisar [`CLAUDE.md`](./CLAUDE.md) — a seção **Manutenção da documentação** lista todos os arquivos que precisam ser atualizados junto com a mudança (este índice incluso).
