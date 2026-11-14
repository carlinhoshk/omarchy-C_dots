#!/usr/bin/env bash

APP_NAME="omarchy-C_dots"
GIST_FILENAME="omarchy-C_dots-backup.json"
MAX_FILE_SIZE=1000000
MAX_GIST_PAYLOAD=900000
CONFIG_DIR="${OMARCHY_C_DOTS_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/$APP_NAME}"
CONFIG_FILE="$CONFIG_DIR/config.json"
MANIFEST_FILE="$CONFIG_DIR/manifest.json"
APP_TEMP_DIRS=()

die() { printf 'Erro: %s\n' "$*" >&2; exit 1; }
warn() { printf 'Aviso: %s\n' "$*" >&2; }

confirm_yn() {
  local prompt="$1" answer
  while true; do
    read -r -p "$prompt [y/n] " answer || return 1
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) printf 'Digite y para sim ou n para não.\n' >&2 ;;
    esac
  done
}

register_temp_dir() { APP_TEMP_DIRS+=("$1"); }

cleanup_temp_dirs() {
  local temp_dir
  for temp_dir in "${APP_TEMP_DIRS[@]}"; do rm -rf -- "$temp_dir"; done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Comando necessário não encontrado: $1"
}

ensure_config_dir() {
  mkdir -p -- "$CONFIG_DIR"
  chmod 700 -- "$CONFIG_DIR"
  [[ -f "$MANIFEST_FILE" ]] || printf '[]\n' > "$MANIFEST_FILE"
  chmod 600 -- "$MANIFEST_FILE"
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    jq -e 'type == "object"' "$CONFIG_FILE" >/dev/null || die "Configuração inválida: $CONFIG_FILE"
    cat -- "$CONFIG_FILE"
  else
    printf '{}\n'
  fi
}

save_config() {
  local json="$1" temp="$CONFIG_FILE.tmp"
  mkdir -p -- "$CONFIG_DIR"
  printf '%s\n' "$json" > "$temp"
  chmod 600 -- "$temp"
  mv -f -- "$temp" "$CONFIG_FILE"
}

normalize_gist_id() {
  local value="$1"
  value="${value%/}"
  value="${value##*/}"
  [[ "$value" =~ ^[[:alnum:]]+$ ]] || die "ID ou URL de Gist inválido."
  printf '%s' "$value"
}

is_blocked_relpath() {
  local rel="$1" part lower suffix
  IFS='/' read -r -a parts <<< "$rel"
  for part in "${parts[@]}"; do
    lower="${part,,}"
    case "$lower" in
      .ssh|.gnupg|.aws|.azure|.kube|.docker|credentials|credential|secrets|secret|tokens|token|auth)
        return 0 ;;
      .env|.env.*|id_rsa|id_ed25519|id_ecdsa)
        return 0 ;;
    esac
  done
  suffix="${rel##*.}"
  case "${suffix,,}" in pem|key|p12|pfx) return 0 ;; esac
  return 1
}

# Set RESOLVED_REL and RESOLVED_ABS. Reject traversal, symlink components,
# paths outside HOME, and sensitive path names.
resolve_home_path() {
  local raw="$1" lexical current part
  if [[ "$raw" == "~" ]]; then raw="$HOME";
  elif [[ "$raw" == "~/"* ]]; then raw="$HOME/${raw#~/}";
  elif [[ "$raw" != /* ]]; then raw="$HOME/$raw"; fi
  lexical="$(realpath -m -s -- "$raw")" || die "Caminho inválido: $raw"
  case "$lexical" in "$HOME"/*) ;; *) die "O caminho precisa ficar dentro de HOME." ;; esac
  local lexical_rel="${lexical#"$HOME"/}"
  current="$HOME"
  IFS='/' read -r -a parts <<< "$lexical_rel"
  for part in "${parts[@]}"; do
    [[ -n "$part" ]] || continue
    current="$current/$part"
    [[ ! -L "$current" ]] || die "Links simbólicos não são aceitos: $current"
  done
  RESOLVED_ABS="$(realpath -m -- "$raw")" || die "Caminho inválido: $raw"
  case "$RESOLVED_ABS" in "$HOME"/*) ;; *) die "O caminho precisa ficar dentro de HOME." ;; esac
  RESOLVED_REL="${RESOLVED_ABS#"$HOME"/}"
  [[ "$RESOLVED_REL" != "$HOME" && -n "$RESOLVED_REL" ]] || die "Não é permitido selecionar HOME inteiro."
  if is_blocked_relpath "$RESOLVED_REL"; then
    die "Este caminho parece conter credenciais ou dados sensíveis e foi bloqueado."
  fi
}

read_manifest() {
  ensure_config_dir
  jq -e 'type == "array" and all(.[]; type == "string")' "$MANIFEST_FILE" >/dev/null \
    || die "Manifesto inválido: $MANIFEST_FILE"
}

run_gh_api() {
  if ! command -v gh >/dev/null 2>&1; then die "Instale o GitHub CLI (gh)."; fi
  gh api "$@" || die "Falha na API do GitHub. Confira sua autenticação com: gh auth status"
}
