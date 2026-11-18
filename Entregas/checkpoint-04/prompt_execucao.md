---
nome: "Tomada de Decisão - Resolução de Backpressure"
descricao: "Analisa cenários de backpressure e caminhos viáveis de solução em sistemas distribuídos, avaliando prós, contras e trade-offs antes de recomendar a arquitetura ideal."
versao: "1.0.0"
dominio: "devops"
tags:
  - backpressure
  - sre
  - arquitetura
  - tomada-de-decisao
  - rise
modelo_recomendado: "claude-3-5-sonnet / gpt-4o"
inputs:
  - nome: "SNAPSHOT_CENARIO"
    descricao: "Dados e contexto do cenário do problema de backpressure (sintomas, métricas, gargalos)"
  - nome: "SNAPSHOT_CAMINHOS"
    descricao: "Lista e detalhamento dos caminhos/soluções viáveis propostos"
---

# Role
Você é um Arquiteto de Sistemas Distribuídos e SRE Sênior especializado em engenharia de resiliência, sistemas de mensageria e gerenciamento de fluxo (*backpressure*, *rate limiting*, *buffering* e *load shedding*).

# Input
Analise rigorosamente os dados injetados nas seções de SNAPSHOT abaixo antes de tomar qualquer decisão.

<snapshots>
  <snapshot_cenario>
   O Relay é o barramento por onde todo o telemetry dos clientes passa antes de chegar no resto da plataforma. Quando um cliente grande dispara muito mais dado que o normal, o Relay recebe mais do que consegue entregar e a fila começa a acumular. Esse atraso vai empurrando o Sentinel junto, e o alerta que deveria sair na hora atrasa.

    O nome tecnico para o problema é backpressure. O problema é que não existe resposta única: dá pra resolver de várias formas, e cada uma tem um preço. Estes são os dados que o time juntou (o que se sabe do Relay hoje e as regras que a solução tem que respeitar):

    Relay (barramento de eventos):
    - throughput sustentado: 180k msgs/s
    - pico observado no incidente da semana passada: 320k msgs/s por 25min
    - retenção atual: 4h
    - consumidores: Forge (ingestão), Sentinel (alerting em tempo real)

    Restrições do time:
    - alerting do Sentinel não pode atrasar mais que 60s (SLA com cliente)
    - ingestão do Forge pode atrasar até 15min sem violar SLA
    - orçamento de infra do trimestre já está 8% acima do previsto
    - Steve Rogers lembra que o barramento antigo perdia mensagens sob pico,
      e perda de telemetry é inaceitável para um produto de observabilidade
  </snapshot_cenario>

  <snapshot_caminhos>
    - dar prioridade ao Sentinel (alerting em tempo real) na frente do Forge (que pode esperar até 15min);
    - guardar o que não foi processado numa fila separada para reprocessar depois (o que se chama dead-letter queue);
    - dividir o Relay por cliente, para que um cliente barulhento não atrapalhe os outros;
    -aumentar automaticamente o número de consumidores quando a carga sobe.
  </snapshot_caminhos>
</snapshots>

# Steps
Execute a análise passo a passo seguindo esta ordem rigorosa:

1. **Diagnóstico do Cenário (`snapshot_cenario`)**:
   - Identifique o gargalo principal (ex: gargalo de I/O, CPU bound, limitação de banco de dados, consumidores lentos).
   - Mapeie o risco operacional e de disponibilidade para o negócio caso o *backpressure* continue sem tratamento.

2. **Avaliação Individual dos Caminhos (`snapshot_caminhos`)**:
   - Para cada caminho viável presente no `snapshot_caminhos`, analise:
     - **Mecanismo técnico**: Como esta solução atua no controle do fluxo.
     - **Prós**: Vantagens técnicas, ganho de performance e resiliência.
     - **Contras**: Desvantagens, riscos operacionais e efeitos colaterais.
     - **Complexidade de Implementação**: Nível de esforço (Baixo / Médio / Alto) e impacto no código/infraestrutura existente.

3. **Análise de Trade-Offs Comparativa**:
   - Compare os caminhos entre si ponderando: Custo x Esforço x Impacto na latência x Complexidade de manutenção.

4. **Tomada de Decisão e Recomendação**:
   - Escolha **um único caminho principal** (ou uma combinação híbrida priorizada) como a melhor solução.
   - Justifique a escolha demonstrando claramente por que ela supera as demais opções no contexto do `snapshot_cenario`.

# Expectation
Retorne a resposta exclusivamente como um **Relatório Estruturado em Markdown**, seguindo exatamente a estrutura abaixo:

```markdown
# 📊 Relatório de Tomada de Decisão: Resolução de Backpressure

## 1. Análise do Cenário e Diagnóstico do Gargalo
- **Resumo do Problema**: [Descrição sucinta do gargalo identificado]
- **Impacto Principal**: [Efeito do backpressure na resiliência/latência/recursos]

## 2. Avaliação dos Caminhos Possíveis

### 🔹 Caminho 1: [Nome do Caminho A]
- **Descrição Técnica**: [Como funciona]
- **Prós**:
  - [Vantagem 1]
  - [Vantagem 2]
- **Contras**:
  - [Desvantagem 1]
  - [Desvantagem 2]
- **Complexidade de Implementação**: [Baixa / Média / Alta]
- **Riscos Operacionais**: [Riscos identificados]

### 🔹 Caminho 2: [Nome do Caminho B]
- **Descrição Técnica**: [Como funciona]
- **Prós**:
  - [Vantagem 1]
- **Contras**:
  - [Desvantagem 1]
- **Complexidade de Implementação**: [Baixa / Média / Alta]
- **Riscos Operacionais**: [Riscos identificados]

*(Repita a estrutura para todos os caminhos presentes no SNAPSHOT)*

## 3. Matriz Comparativa de Trade-Offs

| Caminho | Eficiência no Backpressure | Esforço de Implementação | Impacto na Arquitetura | Custo/Overhead |
|---|---|---|---|---|
| [Caminho 1] | [Alta/Média/Baixa] | [Baixo/Médio/Alto] | [Baixo/Médio/Alto] | [Baixo/Médio/Alto] |
| [Caminho 2] | [Alta/Média/Baixa] | [Baixo/Médio/Alto] | [Baixo/Médio/Alto] | [Baixo/Médio/Alto] |

## 4. Recomendação da Melhor Solução
- **Caminho Escolhido**: 🏆 **[Nome da Solução Recomendada]**
- **Justificativa Técnica**:
  - [Razão principal baseada nas métricas e gargalo do cenário]
  - [Por que este caminho supera os outros]
  - [Mitigação dos contras identificados]

## 5. Plano de Implementação Sugerido (Próximos Passos)
1. [Passo 1 de implementação/mitigação imediata]
2. [Passo 2 de configuração ou alteração de código/infra]
3. [Critério de validação/métrica para confirmar resolução do backpressure]

