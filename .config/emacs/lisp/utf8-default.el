(prefer-coding-system 'utf-8)
(setq-default x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING)
              buffer-file-coding-system 'utf-8-unix) ; specifically for prefering LF over CRLF
(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)
(set-keyboard-coding-system 'utf-8-unix)
(set-terminal-coding-system 'utf-8-unix)

(provide 'utf8-default)
