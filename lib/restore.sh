#!/usr/bin/env bash

dots_restore() {
  local gist_arg="" dry_run=no auto_yes=no config gist_id workdir response payload
  local rel dest marker backup tmp stamp
  while (($#)); do
    case "$1" in
      --gist) (($# >= 2)) || die "--gist precisa de um ID ou URL"; gist_arg="$2"; shift 2 ;;
      --dry-run) dry_run=yes; shift ;;
      --yes) auto_yes=yes; shift ;;
      *) die "Opção desconhecida para restore: $1" ;;
    esac
  done
  require_command jq
  ensure_config_dir
  config="$(load_config)"
  gist_id="$(jq -r '.gist_id // empty' <<< "$config")"
  [[ -z "$gist_arg" ]] || gist_id="$(normalize_gist_id "$gist_arg")"
  [[ -n "$gist_id" ]] || die "Gist não configurado. Execute setup ou informe --gist ID."
  response="$(run_gh_api "/gists/$gist_id")"
  workdir="$(mktemp -d)"
  register_temp_dir "$workdir"
  payload="$workdir/payload.json"
  jq -j --arg filename "$GIST_FILENAME" '.files[$filename].content // empty' <<< "$response" > "$payload"
  [[ -s "$payload" ]] || die "O Gist não contém $GIST_FILENAME."
  jq -e '.schema == 1 and (.files | type == "object") and all(.files[]; type == "string")' "$payload" >/dev/null \
    || die "O conteúdo do Gist não corresponde a um backup válido."
  [[ "$(jq '.files | length' "$payload")" -gt 0 ]] || die "O backup no Gist não contém arquivos."

  printf 'Arquivos no backup (%s):\n' "$(jq '.files | length' "$payload")"
  while IFS= read -r -d '' rel; do
    resolve_home_path "$rel"
    dest="$RESOLVED_ABS"
    if [[ -e "$dest" ]]; then marker=' (será sobrescrito)'; else marker=' (novo arquivo)'; fi
    printf '  ~/%s%s\n' "$rel" "$marker"
  done < <(jq -j '.files | keys[] | . + "\u0000"' "$payload")
  if [[ "$dry_run" == yes ]]; then
    printf 'Prévia concluída: nenhum arquivo foi alterado.\n'
    return
  fi
  if [[ "$auto_yes" != yes ]]; then
    confirm_yn 'Restaurar esses arquivos?' || { printf 'Cancelado; nenhum arquivo foi alterado.\n'; return; }
  fi

  while IFS= read -r -d '' rel; do
    resolve_home_path "$rel"
    dest="$RESOLVED_ABS"
    mkdir -p -- "$(dirname -- "$dest")"
    # Recheck after creating parents to avoid writing through a symlink.
    resolve_home_path "$rel"
    dest="$RESOLVED_ABS"
    if [[ -e "$dest" ]]; then
      stamp="$(date '+%Y%m%d-%H%M%S-%N')"
      backup="$dest.omarchy-C_dots.bak.$stamp"
      cp -p -- "$dest" "$backup" || die "Não foi possível guardar a cópia atual de ~/$rel"
      printf 'Cópia anterior: %s\n' "$backup"
    fi
    tmp="$workdir/restore-file"
    jq -j --arg path "$rel" '.files[$path]' "$payload" > "$tmp"
    cat -- "$tmp" > "$dest" || die "Não foi possível restaurar ~/$rel"
    printf 'Restaurado: ~/%s\n' "$rel"
  done < <(jq -j '.files | keys[] | . + "\u0000"' "$payload")
}
