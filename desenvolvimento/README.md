# Desenvolvimento

Prompts voltados a **desenvolvimento de software**: escrita, revisão e refatoração de código, design de APIs e arquitetura, debugging, análise de trade-offs técnicos, geração de testes, documentação técnica e suporte a decisões de implementação.

## Escopo

Entram aqui prompts relacionados a:

- Escrita e revisão de código em qualquer linguagem ou framework.
- Refatoração, simplificação e redução de complexidade.
- Design de APIs, modelagem de dados e arquitetura de aplicações.
- Debugging, análise de erros e investigação de comportamento inesperado.
- Geração e revisão de testes (unitários, integração, E2E).
- Documentação técnica de código (READMEs, docstrings, ADRs, RFCs).

## Fora de escopo

- Infraestrutura, pipelines de CI/CD, Kubernetes, observabilidade → usar `devops/`.
- Criação de conteúdo educacional sobre desenvolvimento (vídeos, artigos, cursos) → usar `criacao-conteudo/`.

## Prompts

- [diagnosticar-migracao-batch-tempo-real](./diagnosticar-migracao-batch-tempo-real/) — Analisa a documentação de um sistema em processamento em lote (Forge), mapeia gargalos e acoplamentos e compara caminhos arquiteturais para tempo real, com recomendação e bloco de exportação para o próximo passo.
- [planejar-migracao-incremental-batch-tempo-real](./planejar-migracao-incremental-batch-tempo-real/) — Define a estratégia de rollout e o roadmap passo a passo da migração incremental do Forge, com coexistência entre lote e tempo real, matriz de riscos, plano de rollback e bloco de exportação para o próximo passo.
- [especificar-execucao-tatica-migracao-tempo-real](./especificar-execucao-tatica-migracao-tempo-real/) — Transforma o plano de migração do Forge em especificação executável, com padrões de resiliência e garantia de entrega, contratos de eventos, DLQ e retry, plano de observabilidade e checklist de validação do cutover.
