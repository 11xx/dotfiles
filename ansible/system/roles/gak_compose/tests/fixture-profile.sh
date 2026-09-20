# Interpreter fixture for source-tree and service-readiness tests.

make_fixture_profile() {
    local profile=$1
    local interpreter
    interpreter=$(command -v python3) || return 1
    mkdir -p "$profile/bin"
    ln -sf "$interpreter" "$profile/bin/python3"
}
