# Manual de Execução: Validação e Auditoria de Manifestos Kubernetes

Este fluxo é composto por dois prompts encadeados para garantir que manifestos Kubernetes sigam padrões rígidos de NetworkPolicy e nomenclatura de serviços sem invenção de dados.

---

## 🛠️ Como Executar

### Passo 1: Correção do Manifesto (Prompt 1)
1. Abra o **Prompt 1**.
2. Preencha a seção de entradas inserindo os dados reais dentro das tags correspondentes:
   - `<snapshot_manifesto>`: O YAML do manifesto que deseja validar/corrigir.
   - `<snapshot_network_policy>`: O YAML do padrão de NetworkPolicy do seu cluster.
   - `<snapshot_servicos>`: A lista/mapeamento oficial de serviços e labels válidos.
3. Execute no modelo recomendado (`claude-sonnet-3.5` ou equivalente).
4. Guarde o resultado gerado.

### Passo 2: Avaliação Crítica e Audit (Prompt 2)
1. Abra o **Prompt 2**.
2. Preencha as tags do Prompt 2:
   - `<snapshot_inputs_originais>`: Cole o conjunto de snapshots que você usou no Prompt 1.
   - `<snapshot_resultado_prompt_1>`: Cole a resposta completa que o Prompt 1 gerou.
3. Execute o Prompt 2 para obter a **Nota de 0 a 5** e o parecer de aprovação/reprovação.

---

## ⚠️ Regra de Ouro
O Prompt 1 é instruído a ser estritamente aderente aos dados informados. Se o Prompt 2 identificar qualquer label ou nome de serviço que não conste nos snapshots originais, a nota no critério "Fidelidade aos Dados" será penalizada severamente.