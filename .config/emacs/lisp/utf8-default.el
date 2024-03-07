(prefer-coding-system 'utf-8-unix)
(setopt x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING)
        default-process-coding-system '(utf-8-unix . utf-8-unix))
(set-buffer-file-coding-system 'utf-8-unix)
(set-clipboard-coding-system 'utf-8-unix)
(set-default-coding-systems 'utf-8-unix) ; other than setting this the other may be redundant.
(set-file-name-coding-system 'utf-8-unix)
(set-keyboard-coding-system 'utf-8-unix)
(set-selection-coding-system 'utf-8-unix)
(set-terminal-coding-system 'utf-8-unix)
(set-locale-environment "en.UTF-8")

(provide 'utf8-default)
