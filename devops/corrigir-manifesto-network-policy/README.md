---
nome: Corrigir Manifesto de NetworkPolicy
descricao: Compara um manifesto Kubernetes com o padrão oficial de NetworkPolicy e a lista de serviços e labels permitidos, e entrega o manifesto corrigido com relatório de divergências e justificativas.
versao: 1.1.0
tags: [kubernetes, network-policy, seguranca, conformidade, iac]
inputs:
  - nome: snapshot_manifesto
    descricao: Manifesto Kubernetes (YAML) a ser revisado e corrigido
  - nome: snapshot_network_policy
    descricao: Padrão oficial de NetworkPolicy (YAML) que o manifesto deve seguir
  - nome: snapshot_servicos
    descricao: Lista oficial de nomes de serviços e labels permitidos no cluster
---

# Corrigir Manifesto de NetworkPolicy

## Objetivo

Revisar um manifesto Kubernetes comparando-o com o padrão oficial de NetworkPolicy e com a lista oficial de serviços e labels do cluster. O resultado é o manifesto corrigido, pronto para `kubectl apply`, acompanhado de um relatório de conformidade. O prompt proíbe inventar serviços, namespaces, portas ou labels que não estejam nos artefatos de entrada.

## Quando usar

- Ao revisar manifestos de NetworkPolicy antes de aplicá-los no cluster.
- Ao alinhar manifestos existentes ao padrão oficial de NetworkPolicy da organização.
- Ao validar se seletores (`podSelector`, `namespaceSelector`) e labels usam apenas serviços permitidos.

## Exemplo de uso

Cada fluxo liberado sai como um item próprio, com comentário, namespace e label. Por exemplo:

```yaml
# Fluxo: Sentinel -> Forge (warehouse) na porta 5432
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
```

## Testes

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) roda o manifesto permissivo, as regras e o mapa de serviços com `gpt-5.4-mini`, com 3 repetições e sem cache. Os asserts verificam se:

- O YAML tem `kind: NetworkPolicy` e `policyTypes` com `Ingress` e `Egress`.
- A saída não contém `- {}`.
- O egress libera Forge na porta 5432 e Cerebro na porta 9200, e o ingress libera o Relay.
- Toda regra tem comentário.
- Cada chamada responde em até 5 s e custa até US$ 0,01.

```bash
npx promptfoo@latest eval -c devops/corrigir-manifesto-network-policy/promptfooconfig.yaml
```

## Limitações conhecidas

- O manifesto completo é longo: `gpt-4o-mini`, `gpt-4.1-mini` e outros modelos testados excedem 5 s.
- Os asserts usam regex sobre o YAML e dependem do formato do texto. Eles não verificam o gateway de API, o DNS nem o default-deny, e não aplicam o manifesto em um cluster.
- `kubernetes.io/metadata.name` exige Kubernetes 1.21 ou superior e não precisa constar nos snapshots.
- O ingress não restringe portas, porque as entradas não as declaram.
- O teste com um segundo fornecedor ainda não foi executado.
