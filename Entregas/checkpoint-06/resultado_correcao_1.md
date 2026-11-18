# Relatório de Conformidade e Manifesto Corrigido

## 1. Resumo das Divergências Encontradas

- **Rótulos/Labels:** o manifesto original não usa nenhum label ou namespace.
  - `podSelector: {}` seleciona todos os pods do namespace, e não apenas os pods `app=sentinel`.
  - Nenhuma origem ou destino é identificado por `namespaceSelector` + `podSelector`, como exige a relação de serviços (Relay, API gateway, Forge, Cerebro e DNS interno).
- **Regras de Ingress/Egress:**
  - `ingress: [{}]` e `egress: [{}]` são "allow all", o que o padrão proíbe expressamente.
  - Não existe política default-deny explícita no namespace.
  - Nenhuma regra restringe portas (5432, 9200 e 53) ou destinos.
  - Nenhuma regra tem comentário sobre o fluxo legítimo que libera.
  - O objeto único `sentinel-allow` mistura o default-deny com as liberações. Foi separado em duas políticas.

## 2. Manifesto Kubernetes Corrigido

```yaml
# Default-deny explícito: bloqueia todo ingress e egress de todos os pods
# do namespace sentinel-prod. As liberações legítimas vêm da política seguinte.
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

- **Nova política `default-deny-all`:** atende ao requisito "política default-deny explícita no namespace". O `podSelector: {}` aqui é intencional e seguro, porque a política não tem regras de liberação.
- **`podSelector` de `sentinel-allow` alterado para `app: sentinel`:** o `snapshot_servicos` define os pods do Sentinel por esse label, e o padrão fala em "pods do Sentinel".
- **Remoção de `ingress: [{}]` e `egress: [{}]`:** o padrão diz "nada de allow all".
- **Ingress:** foram mantidos somente Relay (`relay-prod`, `app=relay`) e API gateway (`edge`, `app=api-gateway`), exatamente como no `snapshot_servicos`. O `namespaceSelector` e o `podSelector` ficam no mesmo item `from`, o que significa AND. Isso evita liberar todos os pods do namespace ou todos os namespaces com aquele label.
- **Egress:**
  - Forge: `forge-prod`, `app=forge`, porta 5432.
  - Cerebro: `cerebro-prod`, `app=cerebro`, porta 9200.
  - DNS: `kube-system`, `k8s-app=kube-dns`, porta 53.
- **Comentários:** cada regra indica o fluxo legítimo que libera, como exige o padrão.

**Pontos de atenção (premissas que os snapshots não declaram):**
1. Os snapshots informam apenas os nomes dos namespaces, não os labels deles. Usei `kubernetes.io/metadata.name`, que o Kubernetes aplica automaticamente a todo namespace (v1.21+). Se o cluster usar outro label de namespace, o seletor deve ser ajustado.
2. O padrão não define portas para o ingress de Relay e API gateway, então não criei nenhuma. Essas regras liberam todas as portas dos pods Sentinel para essas origens. Recomendo informar as portas para restringi-las.
3. O snapshot indica porta 53 para o DNS sem dizer o protocolo. Liberei UDP e TCP, que o DNS usa na prática. Se o padrão for só UDP, remova a entrada TCP.
4. O protocolo TCP em 5432 e 9200 vem de Postgres e Elasticsearch, que usam TCP, e não de declaração explícita nos snapshots.