# omarchy-C_dots

CLI independente para fazer backup e restaurar dotfiles selecionados do Omarchy usando um GitHub Gist por usuário.

## Requisitos

- Python 3.10 ou mais recente
- GitHub CLI (`gh`) instalado e autenticado
- Permissão `gist` no token do GitHub CLI (`gh auth refresh --scopes gist`)

## Uso

Execute o script diretamente durante o desenvolvimento:

```bash
./bin/omarchy-C_dots status
./bin/omarchy-C_dots manifest add ~/.config/hypr/bindings.lua
./bin/omarchy-C_dots manifest list
./bin/omarchy-C_dots setup
./bin/omarchy-C_dots backup
./bin/omarchy-C_dots restore
```

`setup` cria um Gist secreto ou associa um existente com `--gist ID_OU_URL`. O Gist secreto não é privado: qualquer pessoa que obtenha o link pode ver os arquivos. A ferramenta pergunta antes de criar o Gist e antes de restaurar arquivos.

O backup é manual. `backup --dry-run` mostra a seleção sem enviar nada; `restore --dry-run` mostra o que seria restaurado sem alterar os arquivos. O manifesto é explícito e começa vazio. Arquivos sensíveis conhecidos, links simbólicos, arquivos binários e arquivos acima de 1 MB são recusados ou ignorados. Antes de sobrescrever, a restauração guarda uma cópia com data e hora junto do arquivo atual.

A configuração fica em `~/.config/omarchy-C_dots/`; as credenciais continuam sob controle do `gh`, sem serem copiadas para o manifesto ou enviadas pela ferramenta.

Veja [o diagrama de arquitetura](docs/architecture.md).
