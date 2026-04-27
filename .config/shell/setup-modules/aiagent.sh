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

# opencode
opencode() {
    _aiagent exec -it opencode opencode "${@:-/workspace}"
}

opencode-shell() {
    _aiagent exec -it opencode /bin/bash
}

# container lifecycle
aiagent-start()   { _aiagent_ctl start   "$@"; }
aiagent-stop()    { _aiagent_ctl stop    "$@"; }
aiagent-restart() { _aiagent_ctl restart "$@"; }
aiagent-status()  { _aiagent_ctl status  "$@"; }
aiagent-reload()  { _aiagent_ctl daemon-reload; }

# logs
aiagent-log()         { _aiagent_log -u "${1:?service name required}" -f; }
aiagent-log-build()   { _aiagent_log -u opencode-build   -f; }
aiagent-log-opencode(){ _aiagent_log -u opencode         -f; }
aiagent-log-searxng() { _aiagent_log -u searxng-mcp      -f; }

# podman inspection
aiagent-ps()     { _aiagent ps; }
aiagent-images() { _aiagent images; }
aiagent-prune()  { _aiagent system prune -f; }

# build
aiagent-build() {
    _aiagent_ctl start opencode-build.service
    _aiagent_log -u opencode-build -f
}

# full restart after redeploy
aiagent-redeploy() {
    _aiagent_ctl daemon-reload
    _aiagent_ctl restart opencode.service searxng-mcp.service
}
