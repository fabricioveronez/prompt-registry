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