# 📖 README — Guia de Uso do Prompt de Tomada de Decisão (Backpressure)

Este prompt foi desenvolvido no padrão **R-I-S-E (Role, Input, Steps, Expectation)** para ajudar equipes de SRE, DevOps e Arquitetura a tomarem decisões embasadas e comparativas sobre problemas de *backpressure*.

---

## 🚀 Como Executar

### 1. Preenchimento das Seções de SNAPSHOT
Antes de enviar o prompt para o modelo de linguagem (LLM), cole os dados reais do seu problema dentro das tags XML na seção `# Input`:

- **`<snapshot_cenario>`**: Cole o contexto técnico do incidente ou problema (ex: logs, métricas de consumo de memória/CPU, tamanho de filas, taxa de chegada vs. taxa de processamento, arquitetura das aplicações envolvidas).
- **`<snapshot_caminhos>`**: Liste as opções de solução que a equipe está considerando (ex: *Caminho 1: Implementar Reactive Streams com RxJava/Project Reactor*; *Caminho 2: Adicionar Dead Letter Queue (DLQ) com Rate Limiting no Kafka*; *Caminho 3: Auto-scaling agressivo de consumidores*).

### 2. Modelos Recomendados
Para garantir uma análise analítica profunda de *trade-offs*, utilize modelos com capacidade avançada de raciocínio lógico:
- `Claude 3.5 Sonnet` / `Claude 3 Opus`
- `GPT-4o` / `GPT-4-Turbo`

### 3. Exemplo Rápido de Preenchimento

```xml
<snapshots>
  <snapshot_cenario>
    Serviço de Checkout envia 5.000 req/s para a fila RabbitMQ.
    O Serviço de Pagamento consome no máximo 1.200 req/s devido ao tempo de resposta do gateway externo (800ms).
    A fila RabbitMQ está acumulando mensagens até esgotar a memória do broker (OOM).
  </snapshot_cenario>

  <snapshot_caminhos>
    Caminho 1: Implementar Token Bucket Rate Limiting no Serviço de Checkout.
    Caminho 2: Configurar Dead Letter Queue (DLQ) e aplicar Load Shedding descartando requisições antigas.
    Caminho 3: Migrar o processamento de pagamentos para execução assíncrona desacoplada via AWS SQS com auto-scaling via KEDA.
  </snapshot_caminhos>
</snapshots>
```

### 4. Vantagens do Versionamento YAML
O cabeçalho em metadados Frontmatter (YAML) no topo do prompt permite que o arquivo seja versionado e catalogado em repositórios Git (ex: `prompt-registry`), garantindo rastreabilidade, controle de versão e fácil integração em ferramentas de automação.
```

---

💡 **Sugestão de Próximo Passo**: Se você quiser, posso preencher os campos `<snapshot_cenario>` e `<snapshot_caminhos>` com um exemplo real do seu ambiente (ex: Kafka, RabbitMQ ou APIs REST) e rodar a simulação da análise para você ver o relatório gerado!