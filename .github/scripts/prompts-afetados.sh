#!/usr/bin/env bash
# Decide quais suítes promptfoo o pipeline roda e grava a matriz em $GITHUB_OUTPUT.
#
# Entradas (variáveis de ambiente):
#   SUITE_COMPLETA  "true" força todas as suítes (agendamento, disparo manual)
#   BASE_SHA        commit de comparação (base do PR ou "before" do push)
#   HEAD_SHA        commit avaliado
#
# Regras:
#   - Uma suíte é uma pasta <categoria>/<prompt>/ com promptfooconfig.yaml.
#   - Qualquer arquivo alterado dentro da pasta do prompt marca a suíte dele
#     (prompt.md, config, rubrica, entradas, script de frontmatter).
#   - Mudança no próprio pipeline (.github/) roda a suíte inteira: um gate novo
#     precisa provar que funciona em todos os prompts.
#   - Sem base confiável (primeiro push de um branch), roda tudo.
set -euo pipefail

CATEGORIAS=(devops desenvolvimento)

todas() {
  find "${CATEGORIAS[@]}" -mindepth 2 -maxdepth 2 -name promptfooconfig.yaml -printf '%h\n' | sort
}

selecionadas=""
motivo=""

if [[ "${SUITE_COMPLETA:-false}" == "true" ]]; then
  motivo="suíte completa solicitada"
  selecionadas=$(todas)
elif [[ -z "${BASE_SHA:-}" || "${BASE_SHA}" =~ ^0+$ ]] || ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
  motivo="sem commit base para comparar"
  selecionadas=$(todas)
else
  alterados=$(git diff --name-only "${BASE_SHA}...${HEAD_SHA:-HEAD}")
  if grep -q '^\.github/' <<<"$alterados"; then
    motivo="o pipeline mudou"
    selecionadas=$(todas)
  else
    motivo="prompts alterados"
    selecionadas=$(
      while read -r arquivo; do
        IFS=/ read -r categoria prompt _ <<<"$arquivo"
        [[ -n "${prompt:-}" && -f "$categoria/$prompt/promptfooconfig.yaml" ]] && echo "$categoria/$prompt"
      done <<<"$alterados" | sort -u
    )
  fi
fi

matriz=$(printf '%s\n' "$selecionadas" | sed '/^$/d' | jq -R . | jq -sc .)
total=$(jq 'length' <<<"$matriz")

echo "Motivo: $motivo"
echo "Suítes selecionadas ($total):"
printf '  %s\n' $selecionadas

{
  echo "prompts=$matriz"
  echo "total=$total"
} >>"${GITHUB_OUTPUT:-/dev/stdout}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Suítes selecionadas: $total"
    echo "Motivo: $motivo"
    printf -- '- `%s`\n' $selecionadas
  } >>"$GITHUB_STEP_SUMMARY"
fi
