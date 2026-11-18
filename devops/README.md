# DevOps

Prompts voltados a **infraestrutura, automação e operação** de sistemas: pipelines de CI/CD, containers, orquestração, provisionamento, observabilidade, confiabilidade e segurança operacional.

## Escopo

Entram aqui prompts relacionados a:

- Pipelines de CI/CD (GitHub Actions, GitLab CI, Jenkins etc.).
- Containers e orquestração (Docker, Kubernetes, Helm).
- Infraestrutura como código (Terraform, Pulumi, Ansible).
- Provedores de nuvem (AWS, GCP, Azure) e seus recursos.
- Observabilidade (logs, métricas, tracing, alertas, dashboards).
- Confiabilidade, SRE, postmortems e análise de incidentes.
- Segurança operacional (hardening, secrets, políticas de acesso).

## Fora de escopo

- Escrita de código de aplicação → usar `desenvolvimento/`.
- Conteúdo educacional sobre DevOps (aulas, artigos, vídeos) → usar `criacao-conteudo/`.

## Prompts

- [diagnosticar-pods-kubernetes](./diagnosticar-pods-kubernetes/) — Analisa um snapshot de pods, eventos e logs do Kubernetes e entrega a causa raiz provável com ações para o plantão.
- [padronizar-comunicacao-alertas](./padronizar-comunicacao-alertas/) — Converte um snapshot de alertas brutos de monitoramento em comunicados de incidente padronizados com alerta, impacto, hipótese, ação imediata e escalonamento.
- [analisar-causa-raiz-elasticsearch](./analisar-causa-raiz-elasticsearch/) — Correlaciona configuração, métricas (2h) e logs de um cluster Elasticsearch via Cerebro e entrega um relatório RCA de incidente que afetou uma aplicação Java.
- [decidir-solucao-backpressure](./decidir-solucao-backpressure/) — Analisa um cenário de backpressure em sistemas distribuídos e compara caminhos de solução, entregando um relatório de trade-offs com recomendação e plano de implementação.
- [corrigir-manifesto-network-policy](./corrigir-manifesto-network-policy/) — Compara um manifesto Kubernetes com o padrão oficial de NetworkPolicy e a lista de serviços e labels permitidos, e entrega o manifesto corrigido com relatório de divergências e justificativas.
- [avaliar-manifesto-network-policy-corrigido](./avaliar-manifesto-network-policy-corrigido/) — Audita um manifesto Kubernetes corrigido por modelo de linguagem, verificando fidelidade aos dados, conformidade com NetworkPolicy, validade do YAML e resolução de divergências, e emite nota de 0.0 a 5.0 com parecer final.
