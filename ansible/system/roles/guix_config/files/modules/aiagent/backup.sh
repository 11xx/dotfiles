#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export PATH=/run/current-system/profile/bin:/run/privileged/bin:/usr/bin:/bin
export RESTIC_REPOSITORY=/marak/backups/aiagent/restic
export RESTIC_PASSWORD_FILE=/etc/aiagent/restic-password

[[ $EUID -eq 0 ]] || { printf '%s\n' 'agent backup requires root' >&2; exit 1; }
[[ -f $RESTIC_PASSWORD_FILE && $(stat -c '%u:%a' "$RESTIC_PASSWORD_FILE") == 0:600 ]] || {
    printf '%s\n' 'agent backup password file must be root-owned mode 0600' >&2
    exit 1
}
exec 9>/var/lib/aiagent/backup.lock
flock -n 9 || exit 75

snapshot() {
    findmnt -n --mountpoint /home/aiagent >/dev/null || return 1
    install -d -m 0700 /marak/backups/aiagent "$RESTIC_REPOSITORY" || return 1
    [[ -f $RESTIC_REPOSITORY/config ]] || restic init >/dev/null || return 1
    restic backup --quiet --host gak --tag aiagent \
        /home/aiagent/workspaces /home/aiagent/container-home || return 1
    restic forget --quiet --host gak --tag aiagent \
        --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --prune || return 1
    restic check --quiet || return 1
}

case ${1:-} in
    request)
        request=/run/aiagent/backup-request
        [[ -f $request ]] || exit 0
        [[ $(stat -c '%u:%a' "$request") == 1001:600 ]] || exit 1
        nonce=$(<"$request")
        [[ $nonce =~ ^[0-9]+-[0-9]+$ ]] || exit 1
        outcome=failed
        if snapshot; then outcome=ok; fi
        result=$(mktemp /run/aiagent/backup-result.XXXXXXXX)
        printf '%s %s\n' "$outcome" "$nonce" >"$result"
        chown aiagent:aiagent "$result"
        mv -fT -- "$result" /run/aiagent/backup-result
        rm -f -- "$request"
        [[ $outcome == ok ]]
        ;;
    daily)
        exec 8</run/aiagent/aiagent.lock
        flock -n 8 || exit 75
        timeout 180 herd stop aiagent-compose
        trap 'timeout 180 herd start aiagent-compose' EXIT
        snapshot
        ;;
    restore-check)
        exec 8</run/aiagent/aiagent.lock
        flock -n 8 || exit 75
        timeout 180 herd stop aiagent-compose
        scratch=
        trap '[[ -z $scratch ]] || rm -rf -- "$scratch"; timeout 180 herd start aiagent-compose' EXIT
        findmnt -n --mountpoint /home/aiagent >/dev/null
        snapshot
        scratch=$(mktemp -d /home/aiagent/restore-check.XXXXXXXX)
        restic check --quiet
        restic restore latest --host gak --tag aiagent --target "$scratch" --quiet
        restored="$scratch/home/aiagent"
        for name in workspaces container-home; do
            [[ -d $restored/$name ]] || exit 1
        done
        (cd /home/aiagent && find workspaces container-home -type f -print0 |
            LC_ALL=C sort -z | xargs -0 -r sha256sum) >"$scratch/source.sha256"
        (cd "$restored" && find workspaces container-home -type f -print0 |
            LC_ALL=C sort -z | xargs -0 -r sha256sum) >"$scratch/restored.sha256"
        cmp "$scratch/source.sha256" "$scratch/restored.sha256"
        (cd /home/aiagent && find workspaces container-home -printf '%P %y %l\n' | LC_ALL=C sort) \
            >"$scratch/source.paths"
        (cd "$restored" && find workspaces container-home -printf '%P %y %l\n' | LC_ALL=C sort) \
            >"$scratch/restored.paths"
        cmp "$scratch/source.paths" "$scratch/restored.paths"
        printf '%s\n' 'agent restore checksums match'
        ;;
    *) printf '%s\n' 'usage: backup.sh {request|daily|restore-check}' >&2; exit 2 ;;
esac
