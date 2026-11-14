#!/usr/bin/env bash

dots_manifest() {
  local action="${1:-}" raw rel abs manifest
  shift || true
  require_command jq
  ensure_config_dir
  read_manifest

  case "$action" in
    list)
      (($# == 0)) || die "Uso: omarchy-C_dots manifest list"
      if [[ "$(jq 'length' "$MANIFEST_FILE")" == 0 ]]; then
        printf 'Manifesto vazio. Adicione arquivos ou pastas com: omarchy-C_dots manifest add CAMINHO\n'
        return
      fi
      while IFS= read -r rel; do
        abs="$HOME/$rel"
        if [[ -d "$abs" ]]; then printf '~/%s/ (recursivo)\n' "$rel";
        else printf '~/%s\n' "$rel"; fi
      done < <(jq -r '.[]' "$MANIFEST_FILE")
      ;;
    add|remove)
      (($# == 1)) || die "Uso: omarchy-C_dots manifest $action CAMINHO"
      raw="$1"
      resolve_home_path "$raw"
      rel="$RESOLVED_REL"; abs="$RESOLVED_ABS"; manifest="$MANIFEST_FILE"
      if [[ "$action" == add ]]; then
        if [[ -d "$abs" && "$rel" != .config/* ]]; then
          die "Para incluir uma pasta, escolha uma subpasta específica dentro de ~/.config."
        fi
        if jq -e --arg path "$rel" 'index($path) != null' "$manifest" >/dev/null; then
          printf 'Já está no manifesto: ~/%s\n' "$rel"
          return
        fi
        jq --arg path "$rel" '. + [$path] | unique' "$manifest" > "$manifest.tmp"
        mv -f -- "$manifest.tmp" "$manifest"
        chmod 600 -- "$manifest"
        if [[ -d "$abs" ]]; then printf 'Adicionado: ~/%s/ (recursivo)\n' "$rel";
        else printf 'Adicionado: ~/%s\n' "$rel"; fi
      else
        jq -e --arg path "$rel" 'index($path) != null' "$manifest" >/dev/null \
          || die "Não está no manifesto: ~/$rel"
        jq --arg path "$rel" 'map(select(. != $path))' "$manifest" > "$manifest.tmp"
        mv -f -- "$manifest.tmp" "$manifest"
        chmod 600 -- "$manifest"
        printf 'Removido: ~/%s\n' "$rel"
      fi
      ;;
    *) die "Ação inválida para manifest. Use list, add ou remove." ;;
  esac
}
