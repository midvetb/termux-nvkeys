#!/usr/bin/env bash
set -euo pipefail

APP_NAME="termux-nvkeys"

BEGIN_MARKER="# termux-nvkeys:begin"
END_MARKER="# termux-nvkeys:end"

run() {
    echo "-> Running: $*"
    "$@"
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

remove_block() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    if ! grep -Fq "$BEGIN_MARKER" "$file"; then
        return 0
    fi

    awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
        BEGIN { in_block = 0 }
        $0 == b { in_block = 1; next }
        $0 == e { in_block = 0; next }
        in_block == 1 { next }
        { print }
    ' "$file" > "${file}.tmp"
    mv -f "${file}.tmp" "$file"
}

main() {
    local shell rc_file

    shell="$(detect_shell)"
    case "$shell" in
        bash) rc_file="${HOME}/.bashrc" ;;
        zsh) rc_file="${HOME}/.zshrc" ;;
        fish) rc_file="${HOME}/.config/fish/config.fish" ;;
        *) rc_file="" ;;
    esac

    if [[ -n "$rc_file" ]]; then
        remove_block "$rc_file"
        printf "uninstall: wrapper removed from %s\n" "$rc_file"
    fi

    run rm -f "${HOME}/.local/bin/nv-wrapper"
    run rm -rf "${HOME}/.local/share/${APP_NAME}"

    printf "uninstall: removed ~/.local/bin/nv-wrapper and ~/.local/share/%s\n" "$APP_NAME"

    printf "\n(!): Restart your session or type \"exec \$SHELL\"\n"
}

main "$@"
