# omarchy-C_dots

Ferramenta independente para fazer backup e restaurar dotfiles do Omarchy usando um GitHub Gist por usuário.

## Fluxo inicial

- `setup`: autentica via GitHub CLI e cria ou associa um Gist.
- `backup`: atualiza o Gist com os arquivos selecionados no manifesto.
- `restore`: restaura os arquivos para seus caminhos originais, com confirmação antes de sobrescrever.
- `status`: mostra o Gist associado e a data do último backup.

O backup periódico será opcional. O comportamento padrão é manual, com aviso quando o último backup estiver antigo. Antes do primeiro envio, a ferramenta informa que um Gist secreto não é privado: qualquer pessoa com o link pode acessá-lo. Arquivos e caminhos sensíveis ficam fora do manifesto padrão.

Veja [o diagrama de arquitetura](docs/architecture.md).
