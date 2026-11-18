# Curadoria: testes determinísticos com promptfoo

Os três prompts de saída estruturada passam em todos os asserts na rodada final, dentro de 5 s e US$ 0,01 por chamada. Dois prompts precisaram de ajuste, dois configs trocaram de modelo e os asserts de NetworkPolicy foram corrigidos duas vezes. **Fica pendente o segundo provider de outro fornecedor**, porque o ambiente só tem chave da OpenAI.

Os configs, os ajustes e as execuções foram feitos com apoio do Claude Opus 5.5.

## Correspondência com o enunciado

Os prompts já estavam catalogados com outros nomes. As pastas não foram renomeadas, e cada config fica ao lado do seu `prompt.md`.

| Nome no enunciado | Pasta no repositório | Entradas |
| --- | --- | --- |
| `nota-de-triagem` | `devops/padronizar-comunicacao-alertas/` | 3 alertas crus do CP02 |
| `triagem-de-pods` | `devops/diagnosticar-pods-kubernetes/` | 3 snapshots do CP01 |
| `networkpolicy-sentinel` | `devops/corrigir-manifesto-network-policy/` | Manifesto permissivo, regras e mapa de serviços do CP06 |

A variável se chama `snapshot_alertas`, e não `alerta_cru`, porque esse é o parâmetro declarado no `prompt.md`.

## Resultado final

Cada config roda com 3 repetições e sem cache, porque a saída varia e o assert de latência exige chamadas reais.

| Prompt | Modelo | Rodada | Passou | Latência | Maior custo (US$) |
| --- | --- | --- | --- | --- | --- |
| Nota de triagem | `gpt-4o-mini` | `v2` | 9/9 | 1,3 a 1,9 s | 0,00017 |
| Triagem de pods | `gpt-4.1-mini` | `v2` | 9/9 | 1,0 a 3,6 s | 0,00080 |
| NetworkPolicy | `gpt-5.4-mini` | `v5` | 3/3 | 2,8 a 3,0 s | 0,00413 |

Amostras maiores, com a mesma configuração final (`estabilidade.txt`):

- **Triagem de pods:** 30/30, de 0,9 a 3,9 s.
- **NetworkPolicy:** 20/20, de 2,5 a 2,8 s.

## O que falhou e o que foi ajustado

| Rodada | Prompt | Modelo | Passou | O que aconteceu | Resposta |
| --- | --- | --- | --- | --- | --- |
| `v1` | Nota de triagem | `gpt-4o-mini` | 9/9 | Nenhum assert falhou | Prompt mantido |
| `v1` | Triagem de pods | `gpt-4o-mini` | 6/9 | Entrada 2 em 5,5 a 6,4 s | Prompt mais conciso e troca de modelo |
| `v1` | NetworkPolicy | `gpt-4o-mini` | 0/3 | Latência de 8,7 a 9,5 s e comentários fora do início das regras | Prompt e asserts ajustados |
| `v2` | Triagem de pods | `gpt-4.1-mini` | 9/9 | Nenhum assert falhou | Modelo mantido |
| `v2` | NetworkPolicy | `gpt-4.1-mini` | 0/3 | Só latência, de 5,9 a 6,3 s | Troca para `gpt-5.4-mini` |
| `v3` | NetworkPolicy | `gpt-5.4-mini` | 2/3 | Falso negativo do assert de ingress | Assert corrigido |
| `v4` | NetworkPolicy | `gpt-5.4-mini` | 3/3 | Na amostra, 19/20: DNS dividido em duas regras, uma sem comentário | Prompt ajustado |
| `v5` | NetworkPolicy | `gpt-5.4-mini` | 3/3 | Nenhum assert falhou, e a amostra deu 20/20 | Versão final |

### Ajustes nos prompts

Os dois prompts alterados passaram para a versão `1.1.0`. O prompt da nota de triagem não mudou.

- **Triagem de pods:** cada campo passa a ter uma frase curta, e campos sem evidência são omitidos. Isso reduziu a Entrada 2 de cerca de 470 para cerca de 375 tokens, mas não bastou com `gpt-4o-mini`, que continuou em 5,4 a 5,8 s.
- **NetworkPolicy:** a primeira saída tinha `ports` dentro do seletor, o label `app: relay` no lugar do namespace e nenhum default-deny. O prompt ganhou um molde de regra e instruções sobre o namespace, o comentário antes de cada regra, o default-deny com `podSelector: {}` e o DNS em UDP e TCP no mesmo item. Também limita o relatório e proíbe transcrever o manifesto original.

### Ajustes nos asserts

**Falso positivo.** O manifesto quebrado da `v1` passava nos primeiros asserts de Forge, Cerebro e Relay, porque eles só procuravam os textos no YAML. Agora a regra precisa ter namespace, label e porta juntos, com `ports` no nível correto, e comentários não contam. A saída real da `v1` entrou nos controles e é reprovada.

**Falsos negativos.** Duas saídas corretas foram reprovadas por limitações das regex: um `ingress: []` no default-deny e o formato `- # comentário` seguido de `to:`. Os dois casos foram corrigidos e também entraram nos controles.

**Citação no relatório.** O relatório às vezes citava o `- {}` do manifesto original ao descrever a divergência, e isso reprovava `sem_allow_all`. O assert continuou olhando a saída inteira, como pede o enunciado, e o ajuste foi feito no prompt.

Depois desses ajustes, os 26 controles com saídas fixas e sem chamada a modelo deram o resultado esperado (`controles-asserts.txt`). Eles incluem saídas boas e saídas com um defeito por vez.

## Escolha de modelo

A latência decidiu a escolha, porque todos os modelos da escolha final ficaram bem abaixo do limite de custo. Os números completos estão em `comparacao-modelos.txt`. Foram medidos com o prompt ainda em ajuste, com 3 ou 5 repetições, então servem para comparar modelos, não como resultado final.

| Modelo | Manifesto | Maior custo (US$) | Decisão |
| --- | --- | --- | --- |
| `gpt-4o-mini` | 0/3, 8,5 a 8,7 s | 0,00057 | Mais barato, mas lento para saídas longas. Mantido na nota, que é curta |
| `gpt-4.1-mini` | 2/3 na comparação e 0/3 na `v2`, com picos de até 9,2 s | 0,00166 | Escolhido para pods (30/30), mas instável no manifesto |
| `gpt-5.4-mini` | 4/5, 2,6 a 3,2 s | 0,00431 | **Escolhido para o manifesto:** o mais rápido, com folga no custo |
| `gpt-4.1` | 5/5, 3,2 a 3,9 s | 0,00837 | Passa, mas custa cerca do dobro e fica perto do limite |
| `gpt-5.4-nano` | 0/3, 6,0 a 7,8 s | 0,00149 | Reprovado: também marca a Entrada 3 de pods como problema |
| `gpt-5-nano` | 0/3, 44,6 a 54,9 s | 0,00404 | Reprovado: consome milhares de tokens por chamada e estoura a latência |
| `gpt-4o` | 0/5, 5,7 a 6,2 s | 0,00981 | Reprovado na latência e perto do limite de custo |
| `gpt-5.1` | 0/5, 5,1 a 5,9 s | 0,01016 | Reprovado na latência e no custo |
| `gpt-5.6-terra` | 0/5, 5,7 a 12,1 s | 0,01456 | Reprovado na latência e no custo |
| `gpt-5.6-luna` | 0/3, 11,1 a 11,6 s | 0,00170 | Reprovado na latência, embora seja usado no gate do CP09, que tem outros limites |

As aprovações de 4 s do `gpt-4.1-mini` na comparação não se repetiram nas 13 chamadas seguintes, todas acima de 5 s. Por isso, a decisão não se baseou em uma rodada só.

## Validação fora do promptfoo

Os asserts usam regex, então os 23 manifestos da rodada `v5` e da amostra também foram lidos com PyYAML:

- **YAML válido:** 23/23.
- **Cinco fluxos exatos:** 23/23, com namespace, label, protocolo e porta corretos.
- **Default-deny com `podSelector: {}`:** 23/23.

Nenhum manifesto foi aplicado em um cluster real.

## Limitações

- **Um só fornecedor:** o esqueleto do enunciado pede um segundo provider de outro fornecedor, e isso não foi executado. Os configs têm o provider `anthropic:messages:claude-haiku-5-5` comentado, que também não foi testado.
- **Conteúdo além do formato:** os asserts da nota verificam estrutura, não fidelidade. Na `v2`, "rollback iniciado via Argo CD" aparece em 2 das 9 notas, embora o alerta não diga isso. As 9 notas trazem um prazo de escalonamento que o alerta não informa. A nota do Forge conferida mistura inglês e português. Isso pede a avaliação por julgamento do CP09.
- **Causa por pod:** na Entrada 2, os asserts verificam se pods e causas aparecem na saída, não se cada causa está associada ao pod certo.
- **Regex sobre YAML:** os asserts dependem do formato do texto, como mostraram os falsos negativos. Um parser de YAML seria mais robusto, mas exigiria adicionar uma dependência ao repositório, que hoje não tem nenhuma.
- **Chave de namespace:** o prompt agora pede `kubernetes.io/metadata.name`, que não consta nos snapshots. É o label automático do Kubernetes 1.21 ou superior, então a versão do cluster precisa ser confirmada.
- **Latência:** os valores valem para esta rede e este horário, e o `gpt-4.1-mini` mostrou picos. A nota e os pods têm mais folga no custo que na latência, então uma variação do provedor pode reprovar uma execução.

## Arquivos

| Arquivo | Conteúdo |
| --- | --- |
| `<prompt>-vN.txt` | Saída real do `promptfoo eval` em cada rodada |
| `<prompt>-vN.json` | Resultado completo da mesma rodada, com as respostas do modelo |
| `comparacao-modelos.txt` | Medições por modelo |
| `estabilidade.txt` | Amostras maiores e validação com PyYAML |
| `controles-asserts.txt` | Resultado dos 26 controles dos asserts |

Nos arquivos `-v1.txt`, a linha final de exit code foi removida porque um erro no script de execução a gravava sempre como 0. Os resultados de aprovação e reprovação nesses arquivos não foram alterados.
