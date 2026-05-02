#!/usr/bin/echo 'This is a source only file.'
sqlite_all_tables() {
    sqlite3 "$1" "SELECT name FROM sqlite_master WHERE type='table'" |
        xargs -I{} sqlite3 -table "$1" "SELECT * FROM {}"
}

sqlite_all_tables_json () {
    sqlite3 "$1" "SELECT name FROM sqlite_master WHERE type='table'" |
        xargs -I{} sqlite3 -json "$1" "SELECT * FROM {}"
}
