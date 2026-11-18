## 🚨 Relatório de Diagnóstico de Incidentes - Kubernetes

### 1. Resumo Executivo
- **Pods Analisados**: 6 (distintos, considerando as 3 capturas do namespace `sentinel-prod`)
- **Pods Com Problema**: 3
- **Severidade Geral**: Crítica

> **Observação**: a Entrada 3 mostra uma captura posterior do namespace com todos os pods `Running` — indício de que os incidentes abaixo podem já ter sido mitigados (ex: rollback ou reagendamento). Ainda assim, a causa raiz de cada evento é detalhada para evitar recorrência.

---

### 2. Análise Detalhada por Pod

#### Pod: `sentinel-api-7d9c8b6f4-h4m2t`
- **Status Atual**: `CrashLoopBackOff` (Restarts: `14`)
- **Evidências Cruzadas**:
  - **Evento Chave**: `Terminated / Reason: OOMKilled, Exit Code: 137` + `Warning BackOff (x18 over 40m)`
  - **Log Relevante**: heap subiu de `410Mi/512Mi` (carga do cache de alertas) para `498Mi/512Mi` sob "high GC pressure", seguido de `[FATAL] out of memory, shutting down process`
- **Causa Raiz Provável**: O processo estoura o `limit` de memória (512Mi) durante o carregamento do cache de alertas de 6h logo no startup. O `request` (256Mi) está subdimensionado em relação ao uso real observado, o que sugere que o limite atual é insuficiente para o payload de cache mesmo em operação normal, e não apenas um pico isolado.
- **🛠️ Ação Recomendada para o Plantão**:
  1. Aumentar temporariamente o `limit` de memória (ex.: 512Mi → 768Mi–1Gi) via `kubectl set resources deployment/sentinel-api -n sentinel-prod --limits=memory=1Gi`.
  2. Validar tendência real de uso com `kubectl top pod` / dashboards de métricas antes de fixar o novo valor definitivo.
  3. Abrir item de acompanhamento para revisar o dimensionamento do cache de alertas de 6h (possível redução de TTL/tamanho ou paginação) para evitar depender só de aumentar limite.

---

#### Pod: `sentinel-api-7d9c8b6f4-zzp10`
- **Status Atual**: `ImagePullBackOff` (Restarts: `0`)
- **Evidências Cruzadas**:
  - **Evento Chave**: `Failed to pull image "registry.aegis.io/sentinel-api:2.9.2": manifest unknown` → `ErrImagePull` → `BackOff pulling image`
  - **Log Relevante**: não aplicável — o container nunca chegou a iniciar (falha ocorre no pull, antes da execução).
- **Causa Raiz Provável**: A tag `2.9.2` referenciada no manifesto do Deployment não existe no registry (`manifest unknown`, não é erro de autenticação/credencial). Indica que o rollout foi disparado apontando para uma tag que não foi publicada (build/push da pipeline de CI/CD falhou, ou a tag foi removida/nunca existiu).
- **🛠️ Ação Recomendada para o Plantão**:
  1. Confirmar existência da tag no registry: `crane manifest registry.aegis.io/sentinel-api:2.9.2` (ou verificar no console do registry).
  2. Se a tag não existir, fazer rollback imediato para a última versão válida: `kubectl rollout undo deployment/sentinel-api -n sentinel-prod`.
  3. Investigar o pipeline de CI/CD que deveria ter publicado a `2.9.2` (build falhou silenciosamente ou etapa de push foi pulada).

---

#### Pod: `sentinel-ingest-8f7a9c5b-4dkqm`
- **Status Atual**: `Pending` (Restarts: `0`)
- **Evidências Cruzadas**:
  - **Evento Chave**: `FailedScheduling — 0/6 nodes are available: 6 Insufficient cpu`
  - **Log Relevante**: não aplicável — pod nunca foi agendado/iniciado.
- **Causa Raiz Provável**: Nenhum dos 6 nós do cluster possui CPU alocável suficiente para atender ao `request` de `cpu: 2` deste pod. É falha de capacidade de cluster (ou requisição superdimensionada), não erro de aplicação.
- **🛠️ Ação Recomendada para o Plantão**:
  1. Checar capacidade livre por nó: `kubectl describe nodes | grep -A5 "Allocated resources"`.
  2. Se o cluster estiver realmente saturado, escalar o node pool ou acionar o cluster autoscaler.
  3. Se a capacidade existir mas estiver fragmentada, revisar se `requests.cpu=2` é realmente necessário para o workload de ingest — considerar reduzir o request ou usar HPA/VPA para ajuste dinâmico.