// Envia ao modelo o prompt.md sem o frontmatter, que só contém metadados do catálogo.
const fs = require('node:fs');
const path = require('node:path');

module.exports = ({ vars }) => {
  const prompt = fs
    .readFileSync(path.join(__dirname, 'prompt.md'), 'utf8')
    .replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n+/, '');

  return prompt.replace(/\{\{\s*(\w+)\s*\}\}/g, (original, nome) => vars[nome] ?? original);
};
