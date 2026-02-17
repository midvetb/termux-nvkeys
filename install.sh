#!/usr/bin/env bash
#shellcheck disable=SC2059
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_NAME="termux-nvkeys"

PREFIX_BIN="${HOME}/.local/bin"
PREFIX_SHARE="${HOME}/.local/share/${APP_NAME}"

SRC_NV="${_DIR}/bin/nv-wrapper"
SRC_PROFILES="${_DIR}/profiles"

DST_NV="${PREFIX_BIN}/nv-wrapper"
DST_PROFILES="${PREFIX_SHARE}/profiles"

run() {
    echo "-> Running: $*"
    "$@"
}

die() {
    printf "install: %s\n" "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

ensure_deps() {
    if ! have termux-reload-settings; then
        printf "install: termux-reload-settings not found; installing termux-api...\n" >&2
        pkg install -y termux-api >/dev/null
    fi

    if ! have awk; then
        die "awk not found (should exist in Termux base)"
    fi
}

install_files() {
    [[ -f "$SRC_NV" ]] || die "missing ${SRC_NV}"
    [[ -d "$SRC_PROFILES" ]] || die "missing ${SRC_PROFILES}"

    run mkdir -p "$PREFIX_BIN" "$DST_PROFILES"

    run cp -Rf "$SRC_NV" "$DST_NV"
    run chmod +x "$DST_NV"

    run cp -Rf "${SRC_PROFILES}/nvim.extra-keys" "${DST_PROFILES}/nvim.extra-keys"
}

detect_shell() {
    local sh
    sh="${SHELL:-}"

    if [[ -n "$sh" ]]; then
        sh="$(basename "$sh")"
    fi

    case "$sh" in
        bash|zsh|fish)
            printf "%s" "$sh"
            ;;
        *)
            sh="$(ps -p "$$" -o comm= 2>/dev/null | tr -d ' ')"
            sh="$(basename "${sh:-}")"
            case "$sh" in
                bash|zsh|fish) printf "%s" "$sh" ;;
                *) printf "bash" ;; 
            esac
            ;;
    esac
}

upsert_block() {
    local file="$1"
    local begin="$2"
    local end="$3"
    local content="$4"

    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || : > "$file"

    if grep -Fq "$begin" "$file"; then
        awk -v b="$begin" -v e="$end" -v c="$content" '
            BEGIN { in_block = 0 }
            $0 == b { print b; print c; in_block = 1; next }
            $0 == e { in_block = 0; print e; next }
            in_block == 1 { next }
            { print }
        ' "$file" > "${file}.tmp"
        mv -f "${file}.tmp" "$file"
    else
        {
            echo
            echo "$begin"
            echo "$content"
            echo "$end"
        } >> "$file"
    fi
}

install_shell_wrapper() {
    local shell nv_wrapper_path begin end
    shell="$(detect_shell)"
    nv_wrapper_path="${HOME}/.local/bin/nv-wrapper"

    begin="# termux-nvkeys:begin"
    end="# termux-nvkeys:end"

    case "$shell" in
        bash)
            upsert_block \
                "${HOME}/.bashrc" \
                "$begin" \
                "$end" \
"nvim() {
    \"${nv_wrapper_path}\" \"\$@\"
}"
            ;;
        zsh)
            upsert_block \
                "${HOME}/.zshrc" \
                "$begin" \
                "$end" \
"nvim() {
    \"${nv_wrapper_path}\" \"\$@\"
}"
            ;;
        fish)
            upsert_block \
                "${HOME}/.config/fish/config.fish" \
                "$begin" \
                "$end" \
"function nvim
    \"${nv_wrapper_path}\" \$argv
end"
            ;;
        *)
            return 1
            ;;
    esac

    printf "install: wrapper installed for %s\n" "$shell" >&2
}

postinstall() {
    printf "\nInstalled:\n"
    printf "    %s\n" "$DST_NV"
    printf "    %s\n" "$DST_PROFILES"

    if [[ ":${PATH}:" != *":${PREFIX_BIN}:"* ]]; then
        printf "\nAdd ~/.local/bin to PATH (pick one shell):\n"
    fi

    printf "Profiles live here:\n"
    printf "    %s\n\n" "$DST_PROFILES"
}

main() {
    ensure_deps
    install_files
    install_shell_wrapper
    postinstall

    printf "\n(!): Restarting shell...\n"
    sleep 1
    exec "$SHELL"
}

main "$@"
