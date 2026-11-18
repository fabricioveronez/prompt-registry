#### 1. Visão Geral
Este prompt foi desenvolvido para automatizar a triagem e correlação de incidentes envolvendo aplicações Java e Elasticsearch. Ele utiliza o modelo de raciocínio em etapas (**Chain of Thought**) para cruzar dados de configuração, métricas temporais e logs de erros.

#### 2. Pré-requisitos e Injeção de Dados (SNAPSHOTS)
Antes de enviar o prompt ao LLM recomendados (`claude-3-5-sonnet` ou `gpt-4o`), substitua o conteúdo dentro das tags XML na seção **Seção de Snapshots**:

- **`<snapshot_config>`**: Cole as configurações em JSON/YAML ou texto extraídas da aba de configurações/Overview do Cerebro.
- **`<snapshot_metricas>`**: Cole as métricas das últimas duas horas (ex: export de dados do Cerebro/Prometheus contendo CPU, Heap, GC, Shards e Latência).
- **`<snapshot_logs>`**: Cole o trecho do arquivo de log (`elasticsearch.log` ou logs do nó) correspondente à janela de tempo do incidente.

#### 3. Passo a Passo de Execução
1. Copie o bloco de código do prompt na íntegra.
2. Cole os 3 artefatos coletados nos respectivos blocos XML.
3. Envie para o modelo de IA recomendado.
4. O modelo retornará o **Relatório de Análise de Causa Raiz (RCA)** pronto em formato Markdown estruturado para ser anexado ao ticket do incidente ou ferramenta de documentação (Wiki/Confluence).
