---
nome: Padronizar Comunicação de Alertas
descricao: Converte um snapshot de alertas brutos de monitoramento em comunicados de incidente padronizados com alerta, impacto, hipótese, ação imediata e escalonamento
versao: 1.0.0
tags: [sre, incidentes, alertas, comunicacao, observabilidade]
inputs:
  - nome: snapshot_alertas
    descricao: Snapshot de alertas brutos enviado pelo sistema de monitoramento, a ser convertido para o padrão de 5 campos
---

# Padronizar Comunicação de Alertas

## Objetivo

Transformar um snapshot de alertas brutos do sistema de monitoramento em comunicados de incidente padronizados. Cada alerta sai com cinco campos fixos (ALERTA, IMPACTO, HIPÓTESE INICIAL, AÇÃO IMEDIATA e ESCALAR PARA), em linguagem direta e usando apenas dados presentes no snapshot.

## Quando usar

- Ao receber alertas brutos e precisar comunicar o incidente em formato uniforme.
- Para padronizar a comunicação do plantão entre diferentes serviços e times.
- Para gerar comunicados curtos e objetivos, sem preâmbulo, prontos para colar em um canal de incidentes.

## Exemplo de uso

Os 3 exemplos few-shot do próprio prompt (Relay, Forge, Cerebro) mostram o formato de saída esperado:

```
ALERTA: Relay - taxa de rejeição de ingestão acima de 2% por 5min
IMPACTO: ingestão de telemetry degradada para ~12% dos tenants
HIPÓTESE INICIAL: deploy do Relay às 09:14 reduziu o buffer de ingestão
AÇÃO IMEDIATA: rollback iniciado via Argo CD
ESCALAR PARA: @relay-core se a rejeição não cair em 10min
```

## Testes

O [`promptfooconfig.yaml`](./promptfooconfig.yaml) roda os 3 alertas crus com `gpt-4o-mini`, com 3 repetições e sem cache. Cada saída precisa ter os cinco rótulos, um handle `@palavra` em `ESCALAR PARA:` e no máximo 8 linhas, com até 5 s e US$ 0,01 por chamada.

```bash
npx promptfoo@latest eval -c devops/padronizar-comunicacao-alertas/promptfooconfig.yaml
```

## Limitações conhecidas

- Os testes verificam a estrutura, não a fidelidade ao alerta. O modelo pode repetir ações dos exemplos, como "rollback iniciado via Argo CD", ou criar prazos de escalonamento que o alerta não informa.
- O handle de escalonamento é escolhido pelo modelo, porque o alerta não informa o time responsável.
- Alertas em inglês podem gerar notas que misturam inglês e português.
- O teste com um segundo fornecedor ainda não foi executado.
