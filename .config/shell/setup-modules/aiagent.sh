#!/usr/bin/echo 'This is a source only file.'
AIAGENT_WORK_ROOT="${AIAGENT_WORK_ROOT:-/work}"
AIAGENT_T3_PUBLIC_URL="${AIAGENT_T3_PUBLIC_URL:-http://127.0.0.1:45223/}"

# aiagent: base primitive
_aiagent() {
    sudo machinectl shell --uid=aiagent .host /usr/bin/podman "$@"
}

_aiagent_ctl() {
    sudo machinectl shell aiagent@ /usr/bin/systemctl --user "$@"
}

_aiagent_log() {
    sudo machinectl shell aiagent@ /usr/bin/journalctl --user "$@"
}

# interactive shell inside the harness container
aiagent-shell() {
    _aiagent exec -it aiagent /bin/bash
}

# terminal harnesses
aiagent-opencode() {
    _aiagent exec -it aiagent opencode "${@:-/work}"
}

aiagent-opencode-shell() {
    aiagent-shell
}

aiagent-codex() {
    _aiagent exec -it aiagent codex-auto "$@"
}

aiagent-codex-login() {
    _aiagent exec -it aiagent env BROWSER=none codex login --device-auth "$@"
}

aiagent-codex-raw() {
    _aiagent exec -it aiagent codex "$@"
}

_aiagent_provider_env_args() {
    local name value
    for name in \
        ANTHROPIC_API_KEY \
        GEMINI_API_KEY \
        GOOGLE_API_KEY \
        GROQ_API_KEY \
        MISTRAL_API_KEY \
        OPENAI_API_KEY \
        OPENROUTER_API_KEY \
        XAI_API_KEY
    do
        eval "value=\${$name-}"
        if [[ -n "$value" ]]; then
            printf '%s\n' "-e"
            printf '%s\n' "${name}=${value}"
        fi
    done
}

aiagent-pi() {
    local env_args=()
    while IFS= read -r arg; do
        env_args+=("$arg")
    done < <(_aiagent_provider_env_args)
    _aiagent exec -it "${env_args[@]}" aiagent \
        env -u DISPLAY -u WAYLAND_DISPLAY -u XDG_SESSION_TYPE pi "$@"
}

aiagent-pi-prompt() {
    local env_args=()
    while IFS= read -r arg; do
        env_args+=("$arg")
    done < <(_aiagent_provider_env_args)
    _aiagent exec -it "${env_args[@]}" aiagent \
        env -u DISPLAY -u WAYLAND_DISPLAY -u XDG_SESSION_TYPE \
        pi --provider google -p --no-session --tools read,grep,find,ls "$@"
}

aiagent-pi-readonly() {
    local env_args=()
    while IFS= read -r arg; do
        env_args+=("$arg")
    done < <(_aiagent_provider_env_args)
    _aiagent exec -it "${env_args[@]}" aiagent \
        env -u DISPLAY -u WAYLAND_DISPLAY -u XDG_SESSION_TYPE pi-readonly "$@"
}

aiagent-t3-web() {
    _aiagent exec -it aiagent t3-web "$@"
}

aiagent-t3-web-start() {
    _aiagent_ctl start t3-web.service
}

aiagent-t3-web-stop() {
    _aiagent_ctl stop t3-web.service
}

aiagent-t3-web-restart() {
    _aiagent_ctl restart t3-web.service
}

aiagent-t3-web-status() {
    _aiagent_ctl status t3-web.service
}

aiagent-t3-web-enable() {
    _aiagent_ctl enable t3-web.service
}

aiagent-t3-web-disable() {
    _aiagent_ctl disable t3-web.service
}

aiagent-t3-web-log() {
    _aiagent_log -u t3-web.service -f
}

aiagent-t3-open() {
    xdg-open "$AIAGENT_T3_PUBLIC_URL"
}

# container lifecycle
aiagent-start()   { _aiagent_ctl start   "$@"; }
aiagent-stop()    { _aiagent_ctl stop    "$@"; }
aiagent-restart() { _aiagent_ctl restart "$@"; }
aiagent-status()  { _aiagent_ctl status  "$@"; }
aiagent-reload()  { _aiagent_ctl daemon-reload; }

# logs
aiagent-log()         { _aiagent_log -u "${1:?service name required}" -f; }
aiagent-log-build()   { _aiagent_log -u aiagent-build    -f; }
aiagent-log-searxng() { _aiagent_log -u searxng-mcp      -f; }
aiagent-log-t3()      { _aiagent_log -u t3-web.service   -f; }

# podman inspection
aiagent-ps()     { _aiagent ps; }
aiagent-images() { _aiagent images; }
aiagent-prune()  { _aiagent system prune -f; }

aiagent-backup() {
    local include_work=0 dest stamp out dest_display
    dest="$AIAGENT_WORK_ROOT/ai/backups"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --include-work)
                include_work=1
                shift
                ;;
            -h|--help)
                cat <<'EOF'
Usage:
  aiagent-backup [--include-work] [DEST_DIR]

Archives aiagent persistent state to DEST_DIR. By default this includes the
agent config/state bind mounts and named toolchain/cache volumes, but excludes
/work because project workspaces can be large.
EOF
                return 0
                ;;
            -*)
                printf 'aiagent-backup: unknown option: %s\n' "$1" >&2
                return 2
                ;;
            *)
                dest="$1"
                shift
                ;;
        esac
    done

    mkdir -p "$dest" || return
    dest="$(cd "$dest" && pwd -P)" || return
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="aiagent-backup-${stamp}.tar.gz"

    local podman_args=(
        run
        --rm
        --pull=never
        --security-opt label=disable
        -v /home/aiagent/aiagent_container:/backup/aiagent_container:ro
        -v android-sdk.volume:/backup/volumes/android-sdk:ro
        -v gradle-cache.volume:/backup/volumes/gradle-cache:ro
        -v cabal-cache.volume:/backup/volumes/cabal-cache:ro
        -v ghcup-cache.volume:/backup/volumes/ghcup-cache:ro
        -v "$dest:/out:Z"
    )
    local tar_paths=(aiagent_container volumes)

    if [[ "$include_work" -eq 1 ]]; then
        podman_args+=(-v "$AIAGENT_WORK_ROOT:/backup/work:ro")
        tar_paths+=(work)
    fi

    _aiagent "${podman_args[@]}" localhost/aiagent:latest \
        tar -C /backup -czf "/out/$out" "${tar_paths[@]}"

    dest_display="$dest/$out"
    printf 'aiagent backup written: %s\n' "$dest_display"
}

# build
aiagent-build() {
    _aiagent_ctl start aiagent-build.service
    _aiagent_log -u aiagent-build -f
}

# full restart after redeploy
aiagent-redeploy() {
    _aiagent_ctl daemon-reload
    _aiagent_ctl restart aiagent.service searxng-mcp.service
    _aiagent_ctl try-restart t3-web.service
}
