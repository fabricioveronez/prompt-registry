# 📊 Relatório de Tomada de Decisão: Resolução de Backpressure

## 1. Análise do Cenário e Diagnóstico do Gargalo
- **Resumo do Problema**: O gargalo está no lado do consumo, não na ingestão. O Relay sustenta 180k msgs/s, mas no incidente recebeu 320k msgs/s por 25 min. O excedente de ~140k msgs/s acumulou cerca de **210 milhões de mensagens** (140k × 1.500 s). Sentinel e Forge disputam a mesma capacidade de consumo e a mesma fila, então o backlog de baixa urgência (Forge) atrasa o alerting de alta urgência (Sentinel).
- **Impacto Principal**: O SLA de 60s do Sentinel é violado, que é o risco de negócio mais grave. O Forge tolera 15 min de atraso, então parte da carga trata como urgente algo que não é. Como o orçamento já está 8% acima do previsto, superdimensionar permanentemente não é viável. Perder mensagens também é inaceitável, e a retenção de 4h dá margem para drenar o backlog, mas não para ignorá-lo.
- **Premissas e dados ausentes**: Não há a capacidade máxima real dos consumidores, a distribuição do pico por cliente nem o tempo de warm-up de novos consumidores. Isso deve ser validado antes da implementação.

## 2. Avaliação dos Caminhos Possíveis

### 🔹 Caminho 1: Priorizar o Sentinel sobre o Forge
- **Descrição Técnica**: Separa o fluxo de alerting do de ingestão, com consumer groups ou partições dedicadas e prioridade de leitura para o Sentinel. O Forge consome com a capacidade restante e uma cota mínima, para não estourar seus 15 min.
- **Prós**:
  - Ataca diretamente o SLA mais crítico (60s), explorando a diferença de tolerância entre os consumidores.
  - Não exige capacidade adicional, então o custo é praticamente nulo.
  - Não descarta dados, apenas reordena a espera.
- **Contras**:
  - Não reduz o backlog total, só o redistribui. O atraso do Forge aumenta durante o pico.
  - Sem controle, o Forge pode passar dos 15 min (starvation).
- **Complexidade de Implementação**: Baixa a Média
- **Riscos Operacionais**: Configuração incorreta de prioridade pode deixar o Forge sem processar. Precisa de alerta de lag do Forge próximo ao limite.

### 🔹 Caminho 2: Dead-Letter Queue para reprocessamento posterior
- **Descrição Técnica**: Mensagens não processadas (falha, timeout ou excesso) vão para uma fila separada e são reprocessadas depois.
- **Prós**:
  - Reforça a garantia de zero perda de telemetry.
  - Isola mensagens problemáticas sem travar o fluxo principal.
- **Contras**:
  - Não resolve backpressure. Desvia o excesso, mas a carga continua existindo e será reprocessada.
  - Mensagens de alerting reprocessadas depois perdem o valor em tempo real, o que não atende ao SLA de 60s.
  - Adiciona armazenamento e operação de uma nova fila, num orçamento já estourado.
- **Complexidade de Implementação**: Média
- **Riscos Operacionais**: A DLQ pode virar um segundo backlog silencioso. Exige monitoramento, política de retry e cuidado com ordenação e duplicidade.

### 🔹 Caminho 3: Dividir o Relay por cliente (isolamento)
- **Descrição Técnica**: Particiona o barramento por cliente (ou por grupo de clientes) para que um cliente barulhento não afete os demais.
- **Prós**:
  - Elimina o problema de *noisy neighbor* e permite limites por cliente.
  - Melhora a previsibilidade e a atribuição de custo.
- **Contras**:
  - Não aumenta a capacidade total. Se o pico é global, continua havendo backpressure.
  - Muda a topologia do barramento, com impacto em produtores, consumidores e observabilidade.
  - Mais partições e filas elevam o custo operacional.
- **Complexidade de Implementação**: Alta
- **Riscos Operacionais**: Migração de uma peça central e risco de regressão. Clientes pequenos ficam com capacidade ociosa e o cliente grande, com capacidade insuficiente.

### 🔹 Caminho 4: Autoscaling de consumidores conforme a carga
- **Descrição Técnica**: Escala consumidores horizontalmente com base em lag da fila ou throughput, aumentando a capacidade de drenagem durante o pico e reduzindo depois.
- **Prós**:
  - Ataca a causa raiz (capacidade de consumo < carga no pico).
  - Custo elástico: paga capacidade extra só nos ~25 min de pico, sem superdimensionar o ano todo.
  - Drena o backlog do Forge dentro dos 15 min e evita perda.
- **Contras**:
  - Tempo de warm-up pode ser lento demais para o SLA de 60s do Sentinel isoladamente.
  - O limite passa a ser o número de partições e o próprio broker.
  - Ajuste de gatilhos pode causar oscilação (flapping).
- **Complexidade de Implementação**: Média
- **Riscos Operacionais**: Custo descontrolado sem teto máximo de réplicas. Se o gargalo for o broker ou downstream, escalar consumidores só o desloca.

## 3. Matriz Comparativa de Trade-Offs

| Caminho | Eficiência no Backpressure | Esforço de Implementação | Impacto na Arquitetura | Custo/Overhead |
|---|---|---|---|---|
| 1. Priorizar Sentinel | Média (protege o SLA crítico, não reduz o backlog) | Baixo/Médio | Baixo | Baixo |
| 2. Dead-letter queue | Baixa (não resolve a causa) | Médio | Médio | Médio |
| 3. Dividir por cliente | Média (só resolve o cenário de um cliente dominante) | Alto | Alto | Alto |
| 4. Autoscaling | Alta (aumenta a capacidade de drenagem) | Médio | Médio | Médio (elástico) |

## 4. Recomendação da Melhor Solução
- **Caminho Escolhido**: 🏆 **Híbrido priorizado: Caminho 1 (priorização do Sentinel) + Caminho 4 (autoscaling com teto de custo)**
- **Justificativa Técnica**:
  - A priorização resolve rapidamente o problema de maior consequência (SLA de 60s do Sentinel) sem custo adicional, aproveitando que o Forge tolera 15 min. O autoscaling resolve a causa raiz: 210M de mensagens excedentes precisam de capacidade para serem drenadas dentro da janela do Forge.
  - Supera as demais opções: a DLQ não trata backpressure e o reprocessamento tardio não serve ao alerting. A divisão por cliente é a mais cara e arriscada e não aumenta a capacidade total.
  - Mitigação dos contras: o Forge recebe cota mínima e alerta de lag (por exemplo, a 10 min) para não ultrapassar 15 min. O autoscaling tem teto de réplicas e cooldown, o que protege o orçamento e evita flapping. A prioridade garante que o Sentinel seja atendido enquanto os novos consumidores sobem.
  - Zero perda: nenhuma medida descarta mensagens (sem *load shedding*), e a retenção de 4h cobre a drenagem. Uma DLQ pode entrar depois apenas como rede de segurança para mensagens com falha, não como mecanismo de controle de fluxo.

## 5. Plano de Implementação Sugerido (Próximos Passos)
1. **Imediato**: Separar o consumo do Sentinel do Forge (consumer groups ou partições dedicadas) com prioridade ao Sentinel e cota mínima ao Forge. Criar alertas de lag: Sentinel > 30s e Forge > 10 min.
2. **Curto prazo**: Medir a capacidade real por consumidor e o número de partições (que limita o paralelismo). Configurar autoscaling por lag com teto de réplicas, cooldown e limite de custo alinhado ao orçamento.
3. **Validação**: Reproduzir em teste de carga o pico de 320k msgs/s por 25 min. Critérios de sucesso: lag do Sentinel ≤ 60s durante todo o pico, Forge drenado em ≤ 15 min, zero mensagens perdidas e custo extra do pico dentro do teto definido.
4. **Depois**: Reavaliar o isolamento por cliente (Caminho 3) apenas se os dados mostrarem que um cliente específico causa a maior parte dos picos.