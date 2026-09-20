# Build a profile-shaped directory for the fixtures.
#
# The launcher selects a declared profile and loads its generated environment
# before running the implementation. A fixture profile has the same shape as the
# real one -- an interpreter under bin and a generated snippet under etc -- so
# the fixtures exercise the launcher's actual mechanism rather than bypassing
# it.

make_fixture_profile() {
    local profile=$1
    local interpreter
    interpreter=$(command -v python3) || return 1
    mkdir -p "$profile/bin" "$profile/etc" "$profile/lib"
    ln -sf "$interpreter" "$profile/bin/python3"
    cat >"$profile/etc/profile" <<EOF
export PATH="\${GUIX_PROFILE:-$profile}/bin\${PATH:+:}\$PATH"
export GUIX_PYTHONPATH="\${GUIX_PROFILE:-$profile}/lib/site-packages\${GUIX_PYTHONPATH:+:}\$GUIX_PYTHONPATH"
EOF
}
