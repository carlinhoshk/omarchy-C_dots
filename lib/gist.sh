#!/usr/bin/env bash

dots_setup() {
  local gist_arg="" answer user response body gist_id gist_url config
  while (($#)); do
    case "$1" in
      --gist) (($# >= 2)) || die "--gist precisa de um ID ou URL"; gist_arg="$2"; shift 2 ;;
      --yes) answer=yes; shift ;;
      *) die "Opção desconhecida para setup: $1" ;;
    esac
  done
  require_command jq
  ensure_config_dir
  config="$(load_config)"
  if [[ -n "$gist_arg" ]]; then
    gist_id="$(normalize_gist_id "$gist_arg")"
    config="$(jq --arg id "$gist_id" '.gist_id=$id' <<< "$config")"
    save_config "$config"
    printf 'Gist associado: %s\n' "$gist_id"
    return
  fi

  user="$(run_gh_api /user)"
  user="$(jq -r '.login // "usuário GitHub"' <<< "$user")"
  printf 'Autenticado como %s. Será criado um Gist secreto, acessível a quem tiver o link.\n' "$user"
  if [[ "${answer:-}" != yes ]]; then
    confirm_yn 'Criar o Gist agora?' || { printf 'Cancelado; nenhum Gist foi criado.\n'; return; }
  fi
  body="$(jq -n --arg filename "$GIST_FILENAME" \
    --arg content '{"schema":1,"files":{}}' \
    '{description:"Backup de dotfiles Omarchy criado por omarchy-C_dots",public:false,files:{($filename):{content:$content}}}')"
  response="$(printf '%s' "$body" | run_gh_api --method POST /gists --input -)"
  gist_id="$(jq -er '.id' <<< "$response")" || die "O GitHub não retornou o ID do Gist."
  gist_url="$(jq -r '.html_url // empty' <<< "$response")"
  config="$(jq --arg id "$gist_id" --arg url "$gist_url" --arg user "$user" \
    '.gist_id=$id | .gist_url=$url | .github_login=$user' <<< "$config")"
  save_config "$config"
  printf 'Gist criado e associado: %s\n' "${gist_url:-$gist_id}"
}

dots_status() {
  (($# == 0)) || die "Uso: omarchy-C_dots status"
  require_command jq
  ensure_config_dir
  read_manifest
  local config gist_id gist_url last count
  config="$(load_config)"
  gist_id="$(jq -r '.gist_id // empty' <<< "$config")"
  gist_url="$(jq -r '.gist_url // empty' <<< "$config")"
  last="$(jq -r '.last_backup // "nunca"' <<< "$config")"
  count="$(jq 'length' "$MANIFEST_FILE")"
  printf 'Manifesto: %s entrada(s)\n' "$count"
  if [[ -n "$gist_id" ]]; then printf 'Gist: %s\n' "${gist_url:-$gist_id}";
  else printf 'Gist: não configurado\n'; fi
  printf 'Último backup: %s\n' "$last"
  if gh auth status >/dev/null 2>&1; then printf 'GitHub CLI: autenticado\n';
  else printf 'GitHub CLI: não autenticado ou token inválido\n'; fi
}
