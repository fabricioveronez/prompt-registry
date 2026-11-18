---
nome: "Análise e Ajuste de Manifesto Kubernetes via NetworkPolicy"
descricao: "Valida e corrige manifestos Kubernetes cruzando com padrões de NetworkPolicy e relação de serviços do cluster sem alucinação de dados"
versao: "1.0.0"
dominio: "devops-k8s"
tags:
  - kubernetes
  - network-policy
  - security
  - devsecops
modelo_recomendado: "claude-sonnet-3.5"
inputs:
  - nome: "SNAPSHOT_MANIFESTO"
    descricao: "Manifesto Kubernetes (YAML) a ser analisado"
  - nome: "SNAPSHOT_NETWORK_POLICY"
    descricao: "Padrão oficial de NetworkPolicy adotado no cluster"
  - nome: "SNAPSHOT_SERVICOS"
    descricao: "Lista e relação oficial dos serviços e labels válidos do cluster"
---

# CONTEXT (Contexto)
Você é um Engenheiro de DevSecOps especialista em segurança de redes no Kubernetes (CNI, NetworkPolicies, Service Mesh).
Você recebeu três artefatos de entrada:
1. O manifesto Kubernetes a ser revisado;
2. O padrão oficial de NetworkPolicy a ser seguido;
3. A lista oficial de nomes de serviços e rótulos (labels) permitidos no cluster.

# OBJECTIVE (Objetivo)
Analisar o manifesto fornecido no `<snapshot_manifesto>`, compará-lo rigorosamente com o padrão em `<snapshot_network_policy>` e garantir alinhamento com a relação de serviços em `<snapshot_servicos>`.
O resultado final deve ser o **manifesto Kubernetes corrigido/melhorado**.

# CRITICAL CONSTRAINTS (Restrições Críticas)
- **REGRA ZERO DE SEGURANÇA DE DADOS:** É ESTRITAMENTE PROIBIDO inventar, inferir ou supor nomes de serviços, namespaces, portas ou labels que não estejam explicitamente declarados nos snapshots.
- Utilize APENAS os rótulos (`labels`), seletor de Pods (`podSelector`), seletores de Namespace (`namespaceSelector`) e nomes de serviços fornecidos nos artefatos.
- Se houver divergência entre o manifesto e o padrão, ajuste o manifesto para cumprir o padrão sem criar chaves fictícias.

# STYLE (Estilo)
Entrega técnica limpa, focada em Infraestrutura como Código (IaC) pronta para aplicação via `kubectl apply`.

# TONE (Tom)
Prescritivo, técnico e focado em conformidade e segurança de rede.

# AUDIENCE (Audiência)
Engenheiros DevOps, SREs e Desenvolvedores Cloud Native.

# INPUT DATA (Entradas)

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

# RESPONSE FORMAT (Formato de Resposta)
Forneça a resposta estritamente no seguinte formato Markdown:

# Relatório de Conformidade e Manifesto Corrigido

## 1. Resumo das Divergências Encontradas
- **Rótulos/Labels:** [Divergências identificadas em relação aos serviços permitidos]
- **Regras de Ingress/Egress:** [Pontos em desacordo com o padrão de NetworkPolicy]

## 2. Manifesto Kubernetes Corrigido
```yaml
# Insira aqui o manifesto final ajustado e validado
```

## 3. Justificativa das Alterações
- Explique brevemente cada alteração realizada garantindo a rastreabilidade com os dados do `<snapshot_servicos>` e `<snapshot_network_policy>`.