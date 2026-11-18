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
<snapshot_manifesto>
# manifesto barrado pela revisão de segurança — permissivo demais
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sentinel-allow
  namespace: sentinel-prod
spec:
  podSelector: {}          # aplica a todos os pods do namespace
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - {}                   # libera QUALQUER origem
  egress:
    - {}                   # libera QUALQUER destino
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