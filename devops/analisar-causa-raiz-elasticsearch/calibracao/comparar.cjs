// Compara as notas do juiz com o gabarito humano.
// Uso: node comparar.cjs <resultado-do-promptfoo.json>
const fs = require('node:fs');
const path = require('node:path');

const CRITERIOS = ['C1', 'C2', 'C3', 'C4'];
const gabarito = JSON.parse(fs.readFileSync(path.join(__dirname, 'gabarito.json'), 'utf8'));
const { results } = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')).results;

const aprova = (notas) => {
  const valores = CRITERIOS.map((c) => notas[c]);
  return valores.reduce((a, b) => a + b, 0) >= 6 && !valores.includes(0);
};

let foraDaTolerancia = 0;
let decisoesDivergentes = 0;
let incoerencias = 0;

for (const r of results) {
  const id = r.testCase.description;
  const juiz = r.gradingResult.componentResults.find((c) => c.assertion.type === 'llm-rubric');
  const notas = Object.fromEntries(
    CRITERIOS.map((c) => [c, Number(juiz?.reason.match(new RegExp(`${c}\\s*=\\s*(\\d)`))?.[1])]),
  );
  const esperado = gabarito[id];

  const celulas = CRITERIOS.map((c) => {
    const fora = !(Math.abs(notas[c] - esperado[c]) <= 1);
    if (fora) foraDaTolerancia += 1;
    return `${c} ${esperado[c]}/${notas[c]}${fora ? '!' : ''}`;
  });

  const total = CRITERIOS.reduce((soma, c) => soma + notas[c], 0);
  const coerente = juiz?.score === total / 8 && juiz?.pass === aprova(notas);
  if (!coerente) incoerencias += 1;

  const divergente = juiz?.pass !== aprova(esperado);
  if (divergente) decisoesDivergentes += 1;

  console.log(
    `${id.padEnd(17)} ${celulas.join('  ')}  total ${total}/8  ` +
      `juiz=${juiz?.pass ? 'APROVA' : 'REPROVA'} gabarito=${aprova(esperado) ? 'APROVA' : 'REPROVA'}` +
      `${divergente ? '  DECISÃO DIVERGENTE' : ''}${coerente ? '' : '  INCOERENTE'}`,
  );
}

console.log(
  `\nLegenda: gabarito/juiz; "!" = diferença acima de 1 ponto.\n` +
    `Execuções: ${results.length} | fora da tolerância: ${foraDaTolerancia} | ` +
    `decisões divergentes: ${decisoesDivergentes} | juiz incoerente: ${incoerencias}`,
);
process.exitCode = foraDaTolerancia || decisoesDivergentes || incoerencias ? 1 : 0;
