#!/usr/bin/echo 'This is a source only file.'
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
    xdg-open http://127.0.0.1:3773/
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

# build
aiagent-build() {
    _aiagent_ctl start aiagent-build.service
    _aiagent_log -u aiagent-build -f
}

# full restart after redeploy
aiagent-redeploy() {
    _aiagent_ctl daemon-reload
    _aiagent_ctl restart aiagent.service searxng-mcp.service
}
