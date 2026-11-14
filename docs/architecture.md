# Arquitetura do fluxo de dotfiles

O diagrama mostra o MVP planejado. A ferramenta roda localmente, usa a autenticação GitHub do usuário via `gh`, e mantém os arquivos nos caminhos originais. O Gist funciona como cópia remota versionada, não como pasta de trabalho.

```mermaid
flowchart TD
    U[Usuário] -->|setup / autenticar| CLI[omarchy-C_dots CLI]
    CLI -->|usa credencial local| GH[GitHub CLI: gh auth]
    CLI -->|lê caminhos permitidos| M[Manifesto de dotfiles]
    M -->|seleciona arquivos| FS[(Arquivos locais<br/>~/.config e HOME)]

    U -->|backup manual| CLI
    CLI -->|valida manifesto e exclui caminhos sensíveis| SAFE[Coleta segura]
    FS --> SAFE
    SAFE -->|cria ou atualiza| GIST[(Gist do usuário)]
    GH -->|token autorizado| API[GitHub Gist API]
    SAFE --> API
    API --> GIST

    U -->|restore| CLI
    GIST -->|arquivos + manifesto de destinos| API
    API --> CLI
    CLI -->|mostra plano e pede confirmação| REVIEW[Revisão de restauração]
    REVIEW -->|aplica nos caminhos originais| FS

    TIMER[Timer opcional semanal] -. verifica mudanças / política configurada .-> CLI
    CLI -->|status e idade do último backup| U
```

## Regras do MVP

- Backup manual por padrão; timer semanal é opt-in.
- Um Gist por usuário, associado localmente após autenticação.
- O manifesto lista caminhos relativos ao `HOME`; não varrer `~/.config` inteiro.
- Excluir segredos, tokens, caches, arquivos de sessão, binários e configurações específicas de hardware por padrão.
- Avisar que Gist secreto é acessível a qualquer pessoa que obtenha o link.
- Mostrar os arquivos que serão sobrescritos e pedir confirmação antes de restaurar.
- Registrar localmente a data do último backup para `status` e alertas de backup antigo.
