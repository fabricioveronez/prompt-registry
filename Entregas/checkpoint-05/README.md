# Guia de Execução do Encadeamento de Prompts (Forge Migration Chain)

Este conjunto de prompts foi projetado de forma sequencial (chaining). O resultado de cada etapa alimenta a próxima via injeção XML na tag `<snapshot>`.

---

## 🚀 Fluxo de Execução passo a passo

1. **Execução do Prompt 1 (Diagnóstico):**
   - Abra o arquivo do **Prompt 1**.
   - Substitua a tag `{{DADOS_DO_SISTEMA_E_AMBIENTE}}` dentro de `<snapshot>` pela documentação atual do sistema Forge (diagramas em texto, specs do banco de dados, volumetria do batch, etc.).
   - Execute o prompt no LLM recomendado.

2. **Execução do Prompt 2 (Passo a Passo):**
   - Abra o arquivo do **Prompt 2**.
   - Copie o resultado gerado pelo Prompt 1 (ou o bloco dentro de `<passo1_result>`).
   - Substitua a tag `{{RESULTADO_PROMPT_1}}` dentro de `<snapshot>` por esse conteúdo.
   - Execute o prompt no LLM.

3. **Execução do Prompt 3 (Detalhes da Execução):**
   - Abra o arquivo do **Prompt 3**.
   - Copie o resultado gerado pelo Prompt 2 (ou o bloco dentro de `<passo2_result>`).
   - Substitua a tag `{{RESULTADO_PROMPT_2}}` dentro de `<snapshot>` por esse conteúdo.
   - Execute o prompt no LLM para obter o plano tático final de engenharia.

---

## 📌 Boas Práticas de Versionamento
- Sempre mantenha os cabeçalhos YAML intactos no topo de cada prompt para rastreabilidade de versão em repositórios Git.
- Caso precise alterar os parâmetros de um prompt para outro projeto, incremente a versão (ex: `1.1.0`) no cabeçalho YAML.