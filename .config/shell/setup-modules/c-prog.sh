#!/usr/bin/echo 'This is a source only file.'
gcc-run-a.out () {
    gcc -std=c23 -Wall -Werror -fsanitize=address "$1" && ./a.out
}

gcc-no-sanitize-run-a.out () {
    gcc -std=c23 -Wall -Werror "$1" && ./a.out
}
