#!/usr/bin/env bash

add_file_to_payload() {
  local file="$1" payload="$2" next="$3" rel size
  [[ -f "$file" && ! -L "$file" ]] || return 0
  rel="${file#"$HOME"/}"
  if is_blocked_relpath "$rel"; then
    warn "ignorando caminho sensível: ~/$rel"
    return 0
  fi
  size="$(stat -c '%s' -- "$file")"
  if ((size > MAX_FILE_SIZE)); then
    warn "ignorando arquivo maior que 1 MB: ~/$rel"
    return 0
  fi
  if ! iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1; then
    warn "ignorando arquivo binário ou fora de UTF-8: ~/$rel"
    return 0
  fi
  jq --arg path "$rel" --rawfile content "$file" '.files[$path]=$content' "$payload" > "$next" \
    || die "Não foi possível adicionar ~/$rel ao pacote."
  mv -f -- "$next" "$payload"
}

add_manifest_entry() {
  local rel="$1" abs="$2" payload="$3" next="$4" file
  if [[ -d "$abs" ]]; then
    [[ "$rel" == .config/* ]] || die "Para incluir uma pasta, escolha uma subpasta específica dentro de ~/.config."
    while IFS= read -r -d '' file; do
      add_file_to_payload "$file" "$payload" "$next"
    done < <(find "$abs" -mindepth 1 \
      \( -type d \( -name .git -o -name .cache -o -name cache -o -name caches \
        -o -name node_modules -o -name __pycache__ -o -name .venv -o -name venv -o -name sessions \
        -o -name .ssh -o -name .gnupg -o -name .aws -o -name .azure -o -name .kube -o -name .docker \
        -o -name credentials -o -name credential -o -name secrets -o -name secret -o -name tokens -o -name token -o -name auth \) -prune \) \
      -o \( -type f -print0 \) | sort -z)
  else
    [[ -f "$abs" && ! -L "$abs" ]] || die "Não é arquivo regular nem pasta: ~/$rel"
    add_file_to_payload "$abs" "$payload" "$next"
  fi
}

dots_backup() {
  local dry_run="no" config manifest payload next rel abs name gist_id body response now size workdir
  while (($#)); do
    case "$1" in
      --dry-run) dry_run=yes; shift ;;
      *) die "Opção desconhecida para backup: $1" ;;
    esac
  done
  require_command jq
  require_command realpath
  require_command iconv
  ensure_config_dir
  read_manifest
  config="$(load_config)"
  manifest="$MANIFEST_FILE"
  workdir="$(mktemp -d)"; register_temp_dir "$workdir"
  payload="$workdir/payload.json"; next="$workdir/payload.next"
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  jq -n --arg time "$now" '{schema:1,updated_at:$time,files:{}}' > "$payload"
  while IFS= read -r rel; do
    resolve_home_path "$rel"
    abs="$RESOLVED_ABS"
    if [[ ! -e "$abs" ]]; then warn "ignorando caminho ausente: ~/$rel"; continue; fi
    add_manifest_entry "$rel" "$abs" "$payload" "$next"
  done < <(jq -r '.[]' "$manifest")
  [[ "$(jq '.files | length' "$payload")" -gt 0 ]] || die "Nenhum arquivo do manifesto existe para backup."
  printf 'Arquivos selecionados (%s):\n' "$(jq '.files | length' "$payload")"
  while IFS= read -r name; do printf '  ~/%s\n' "$name"; done < <(jq -r '.files | keys[]' "$payload")
  size="$(wc -c < "$payload" | tr -d ' ')"
  if [[ "$dry_run" == yes ]]; then
    printf 'Prévia concluída: nada foi enviado ao GitHub.\nTamanho aproximado do pacote: %s bytes\n' "$size"
    return
  fi
  ((size <= MAX_GIST_PAYLOAD)) || die "O pacote passou de 900 KB. Remova arquivos do manifesto para caber em um único Gist."
  gist_id="$(jq -r '.gist_id // empty' <<< "$config")"
  [[ -n "$gist_id" ]] || die "Gist não configurado. Execute primeiro: omarchy-C_dots setup"
  body="$(jq -n --arg filename "$GIST_FILENAME" --rawfile content "$payload" \
    '{files:{($filename):{content:$content}}}')"
  response="$(printf '%s' "$body" | run_gh_api --method PATCH "/gists/$gist_id" --input -)"
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  config="$(jq --arg time "$now" --arg url "$(jq -r '.html_url // empty' <<< "$response")" \
    '.last_backup=$time | if $url != "" then .gist_url=$url else . end' <<< "$config")"
  save_config "$config"
  printf 'Backup atualizado: %s\n' "$(jq -r '.gist_url // .gist_id' <<< "$config")"
}
