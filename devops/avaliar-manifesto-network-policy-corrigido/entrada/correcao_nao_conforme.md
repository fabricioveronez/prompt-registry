# Relatório de Conformidade e Manifesto Corrigido

## 1. Resumo das Divergências Encontradas

- O `podSelector: {}` foi restringido aos pods do Sentinel.
- O ingress passou a aceitar o Relay e o Prometheus de monitoramento.
- O egress foi mantido aberto para não quebrar integrações existentes.

## 2. Manifesto Kubernetes Corrigido

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sentinel-allow
  namespace: sentinel-prod
spec:
  podSelector:
    matchLabels:
      app: sentinel-api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: relay-prod
          podSelector:
            matchLabels:
              app: relay-worker
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
          podSelector:
            matchLabels:
              app: prometheus
  egress:
    - {}
```

## 3. Justificativa das Alterações

- `app: sentinel-api` identifica os pods da API do Sentinel.
- O Prometheus precisa coletar métricas do Sentinel, por isso foi liberado.
- O egress aberto evita incidentes enquanto os destinos não são mapeados.
