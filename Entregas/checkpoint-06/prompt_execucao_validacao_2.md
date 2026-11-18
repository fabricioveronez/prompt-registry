---
nome: "Avaliação Crítica de Manifesto Kubernetes Corrigido"
descricao: "Avalia criticamente o resultado do Prompt 1 atribuindo uma nota de 0 a 5 com base em segurança, conformidade e fidelidade aos dados"
versao: "1.0.0"
dominio: "devops-quality-assurance"
tags:
  - kubernetes
  - code-review
  - network-policy
  - audit
modelo_recomendado: "claude-sonnet-3.5"
inputs:
  - nome: "SNAPSHOT_INPUTS_ORIGINAIS"
    descricao: "Contém os 3 snapshots originais (manifesto, padrão e lista de serviços)"
  - nome: "SNAPSHOT_RESULTADO_PROMPT_1"
    descricao: "Resultado completo e manifesto gerado pelo Prompt 1"
---

# CONTEXT (Contexto)
Você é um Auditor Sênior de Segurança Cloud Native e Revisor Principal de Código Kubernetes.
Sua tarefa é avaliar criticamente o manifesto corrigido gerado no passo anterior, verificando se o modelo seguiu as regras de segurança, conformidade de rede e restrições de não-alucinação de dados.

# OBJECTIVE (Objetivo)
Analisar o manifesto corrigido gerado pelo Prompt 1 em relação aos dados originais e emitir uma **avaliação crítica fundamentada com uma nota final de 0.0 a 5.0**.

# EVALUATION CRITERIA (Critérios de Avaliação)
1. **Fidelidade aos Dados (Peso: 40%):** O manifesto usou apenas labels e nomes de serviços fornecidos? Houve alguma alucinação de dados?
2. **Conformidade com NetworkPolicy (Peso: 30%):** O manifesto segue integralmente as regras de Ingress/Egress do padrão fornecido?
3. **Sintaxe e Validade do YAML (Peso: 15%):** O manifesto gerado é sintaticamente válido para o Kubernetes?
4. **Resolução de Divergências (Peso: 15%):** Todos os problemas do manifesto original foram devidamente corrigidos?

# INPUT DATA (Entradas)

<snapshot_inputs_originais>
<snapshot_inputs_originais>
<snapshot_manifesto>
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: sentinel-prod
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# Libera apenas os fluxos legítimos dos pods do Sentinel (app=sentinel).
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sentinel-allow
  namespace: sentinel-prod
spec:
  podSelector:
    matchLabels:
      app: sentinel
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Fluxo: Relay (relay-prod, app=relay) -> Sentinel (consumo de eventos)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: relay-prod
          podSelector:
            matchLabels:
              app: relay
    # Fluxo: API gateway da plataforma (edge, app=api-gateway) -> Sentinel
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: edge
          podSelector:
            matchLabels:
              app: api-gateway
  egress:
    # Fluxo: Sentinel -> Forge (warehouse Postgres) na porta 5432
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: forge-prod
          podSelector:
            matchLabels:
              app: forge
      ports:
        - protocol: TCP
          port: 5432
    # Fluxo: Sentinel -> Cerebro (busca Elasticsearch) na porta 9200
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cerebro-prod
          podSelector:
            matchLabels:
              app: cerebro
      ports:
        - protocol: TCP
          port: 9200
    # Fluxo: Sentinel -> DNS interno (kube-system, k8s-app=kube-dns) na porta 53
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
</snapshot_manifesto>

<snapshot_network_policy>
NetworkPolicy para o namespace "sentinel-prod":
- pods do Sentinel só aceitam tráfego de entrada do Relay (consumo de
  eventos) e do gateway de API da plataforma
- pods do Sentinel só fazem saída para: Forge (warehouse, porta 5432),
  Cerebro (busca, porta 9200) e DNS interno
- nada de "allow all" em ingress ou egress
- política default-deny explícita no namespace
- toda regra precisa de comentário dizendo qual fluxo legítimo ela libera
</snapshot_network_policy>

<snapshot_servicos>
Sentinel     → namespace sentinel-prod, pods com label app=sentinel
Relay        → namespace relay-prod,    pods com label app=relay
API gateway  → namespace edge,          pods com label app=api-gateway
Forge        → namespace forge-prod,    pods com label app=forge,   porta 5432 (Postgres do warehouse)
Cerebro      → namespace cerebro-prod,  pods com label app=cerebro, porta 9200 (Elasticsearch)
DNS interno  → namespace kube-system,   pods com label k8s-app=kube-dns, porta 53
</snapshot_servicos>

</snapshot_inputs_originais>

<snapshot_resultado_prompt_1>
# Relatório de Conformidade e Manifesto Corrigido

## 1. Resumo das Divergências Encontradas

- **Rótulos/Labels:** Nenhuma divergência. Todos os valores batem com `<snapshot_servicos>`:
  - `app=sentinel`, `app=relay`, `app=api-gateway`, `app=forge` e `app=cerebro`
  - `k8s-app=kube-dns`
  - namespaces `sentinel-prod`, `relay-prod`, `edge`, `forge-prod`, `cerebro-prod` e `kube-system`
- **Regras de Ingress/Egress:** O manifesto já cumpre o padrão (não há "allow all", e o ingress só aceita Relay e API gateway). A única lacuna formal é a política `default-deny-all`, que não tem comentário, e o padrão exige comentário em toda regra. Há também dois pontos de atenção, sem alteração:
  - As portas de ingress não estão definidas em nenhum snapshot, então o ingress fica sem restrição de porta. Não inventei portas.
  - O seletor `kubernetes.io/metadata.name` não aparece nos snapshots. É o label automático de namespace (Kubernetes ≥ 1.21) e a única forma de selecionar por nome, então foi mantido.

## 2. Manifesto Kubernetes Corrigido

```yaml
# Política default-deny explícita do namespace sentinel-prod:
# bloqueia todo ingress e egress de todos os pods; qualquer fluxo
# legítimo é liberado apenas pela política sentinel-allow abaixo.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: sentinel-prod
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# Libera apenas os fluxos legítimos dos pods do Sentinel (app=sentinel).
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sentinel-allow
  namespace: sentinel-prod
spec:
  podSelector:
    matchLabels:
      app: sentinel
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Fluxo: Relay (relay-prod, app=relay) -> Sentinel (consumo de eventos)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: relay-prod
          podSelector:
            matchLabels:
              app: relay
    # Fluxo: API gateway da plataforma (edge, app=api-gateway) -> Sentinel
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: edge
          podSelector:
            matchLabels:
              app: api-gateway
  egress:
    # Fluxo: Sentinel -> Forge (warehouse Postgres) na porta 5432
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: forge-prod
          podSelector:
            matchLabels:
              app: forge
      ports:
        - protocol: TCP
          port: 5432
    # Fluxo: Sentinel -> Cerebro (busca Elasticsearch) na porta 9200
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cerebro-prod
          podSelector:
            matchLabels:
              app: cerebro
      ports:
        - protocol: TCP
          port: 9200
    # Fluxo: Sentinel -> DNS interno (kube-system, k8s-app=kube-dns) na porta 53
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

## 3. Justificativa das Alterações

- **Comentário em `default-deny-all`:** o padrão exige que toda regra tenha comentário. Esta política não libera fluxo, então o comentário explica que ela implementa o "default-deny explícito no namespace" e que as liberações vêm de `sentinel-allow`. Foi a única alteração.
- **Mantido sem alteração (ingress):** só Relay (`relay-prod`, `app=relay`) e API gateway (`edge`, `app=api-gateway`) entram. Isso corresponde ao padrão e ao `<snapshot_servicos>`. `namespaceSelector` e `podSelector` estão no mesmo item de `from`, o que aplica E lógico (pod `app=relay` no namespace `relay-prod`), e não OU, que seria mais permissivo.
- **Mantido sem alteração (egress):** Forge/5432, Cerebro/9200 e DNS/53 (UDP e TCP) correspondem exatamente às portas e labels declarados. Não há outras saídas.
- **Não alterado (portas de ingress):** nenhum snapshot declara a porta em que o Sentinel recebe tráfego. Se o padrão do cluster exigir restrição de porta no ingress, informe as portas para que sejam adicionadas sem suposições.
- **Não alterado (`kubernetes.io/metadata.name`):** confirme que o cluster está na versão 1.21 ou superior, onde esse label é aplicado automaticamente aos namespaces. Em versões anteriores, os namespaces precisariam de um label próprio, que também teria de constar nos snapshots.
</snapshot_resultado_prompt_1>

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