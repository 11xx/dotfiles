#!/usr/bin/env bash
set -euo pipefail

gitolite_bin=$1
policy=$2
original_home=$HOME
scratch=$(mktemp -d "${HOME}/.cache/gak-git-hub-policy.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
export HOME="$scratch/home"
gitolite_dir=$(dirname "$gitolite_bin")
PATH="$gitolite_dir:/run/current-system/profile/bin:$original_home/.guix-profile/bin:/usr/bin:/bin"
export PATH
mkdir -m 0700 "$HOME"
ssh-keygen -q -t ed25519 -N '' -f "$scratch/operator" >/dev/null
ssh-keygen -q -t ed25519 -N '' -f "$scratch/aiagent" >/dev/null
"$gitolite_bin" setup -pk "$scratch/operator.pub" >"$scratch/setup.log" 2>&1
cp "$policy" "$HOME/.gitolite/conf/gitolite.conf"
cp "$scratch/aiagent.pub" "$HOME/.gitolite/keydir/aiagent.pub"
"$gitolite_bin" setup >>"$scratch/setup.log" 2>&1

"$gitolite_bin" access -q arc operator + refs/heads/main
"$gitolite_bin" access -q arc aiagent R refs/heads/main
"$gitolite_bin" access -q arc aiagent W refs/heads/agent/fix
"$gitolite_bin" access -q arc aiagent + refs/heads/agent/fix
if "$gitolite_bin" access -q arc aiagent W refs/heads/main; then exit 1; fi
if "$gitolite_bin" access -q arc aiagent W refs/tags/test; then exit 1; fi
if "$gitolite_bin" access -q arc aiagent D refs/heads/main; then exit 1; fi
if "$gitolite_bin" access -q gitolite-admin aiagent R any; then exit 1; fi
if "$gitolite_bin" access -q testing aiagent R any; then exit 1; fi
if "$gitolite_bin" access -q another aiagent R any; then exit 1; fi
printf '%s\n' 'Gitolite allows agent branches and refuses main, tags, non-agent deletion, admin and other repositories'

git init --bare --quiet "$scratch/limit.git"
git -C "$scratch/limit.git" config receive.maxInputSize 65536
git init --quiet "$scratch/source"
head -c 131072 /dev/urandom >"$scratch/source/large.bin"
git -C "$scratch/source" add large.bin
git -C "$scratch/source" -c user.name=Test -c user.email=test@example.invalid commit -qm large
if git -C "$scratch/source" push "$scratch/limit.git" HEAD:refs/heads/agent/large >"$scratch/push.log" 2>&1; then
    exit 1
fi
if git -C "$scratch/limit.git" show-ref --quiet refs/heads/agent/large; then
    exit 1
fi
if ! rg -q 'pack exceeds maximum allowed size' "$scratch/push.log"; then
    cat "$scratch/push.log"
    exit 1
fi
printf '%s\n' 'receive.maxInputSize rejects an oversized incoming pack before updating a ref'
