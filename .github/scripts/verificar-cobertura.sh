#!/usr/bin/env bash
# Falha se algum prompt das categorias cobertas não tiver promptfooconfig.yaml.
# Roda antes de qualquer chamada a modelo: é grátis e impede que um prompt novo
# entre no catálogo sem testes (e, portanto, sem gate).
set -euo pipefail

CATEGORIAS=(devops desenvolvimento)
faltando=0

while read -r prompt; do
  pasta=$(dirname "$prompt")
  if [[ ! -f "$pasta/promptfooconfig.yaml" ]]; then
    echo "::error file=$prompt::$pasta não tem promptfooconfig.yaml"
    faltando=$((faltando + 1))
  fi
done < <(find "${CATEGORIAS[@]}" -mindepth 2 -maxdepth 2 -name prompt.md | sort)

total=$(find "${CATEGORIAS[@]}" -mindepth 2 -maxdepth 2 -name prompt.md | wc -l)
echo "Prompts: $total; sem suíte promptfoo: $faltando"
[[ $faltando -eq 0 ]]
