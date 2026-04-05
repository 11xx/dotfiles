;;; llm-ai-assistants.el --- AI assistant features config -*- lexical-binding: t; -*-

;;; Code

(setup gptel
  (:elpaca gptel)
  (setopt gptel-model 'gpt-5.4-nano
          gptel-default-mode 'org-mode)

  (with-eval-after-load 'gptel-openai
    (dolist (model
             ;; info from 20260327 https://developers.openai.com/api/docs/models
             '((gpt-5.4-mini
                :description "Strong mini model for coding, computer use, and subagents"
                :capabilities (media tool-use json url)
                :mime-types ("image/jpeg" "image/png" "image/gif" "image/webp")
                :context-window 400
                :input-cost 0.75
                :output-cost 4.5
                :cutoff-date "2025-08")
               (gpt-5.4-nano
                :description "Cheapest GPT-5.4-class model for simple high-volume tasks"
                :capabilities (media tool-use json url)
                :mime-types ("image/jpeg" "image/png" "image/gif" "image/webp")
                :context-window 400
                :input-cost 0.2
                :output-cost 1.25
                :cutoff-date "2025-08")))
      (setq gptel--openai-models
            (assq-delete-all (car model) gptel--openai-models))
      (setq gptel--openai-models
            (append gptel--openai-models (list model))))
    (setopt gptel-backend (gptel-make-openai "ChatGPT"
                            :stream t
                            :models gptel--openai-models)))

  (gptel-make-gemini "Gemini"
    :stream t
    :key (gptel-api-key-from-auth-source "generativelanguage.googleapis.com"))
  (gptel-make-anthropic "Claude"
    :stream t
    :key (gptel-api-key-from-auth-source "api.anthropic.com"))

  (gptel-make-ollama "Ollama"
    :host "localhost:11434"
    :stream t
    :models '(qwen3.5:9b
              qwen2.5-coder:14b
              ))

  (with-eval-after-load 'org
    (add-to-list 'org-use-property-inheritance "GPTEL_MODEL")
    (add-to-list 'org-use-property-inheritance "GPTEL_BACKEND")
    (add-to-list 'org-use-property-inheritance "GPTEL_SYSTEM")
    (add-to-list 'org-use-property-inheritance "GPTEL_TEMPERATURE"))
  )

(use-package ob-gptel
  :load-path "~/clones/11xx-ob-gptel/"
  :config
  (add-to-list 'org-babel-load-languages '(gptel . t))
  (defun ob-gptel-setup-completions ()
    (add-hook 'completion-at-point-functions
              'ob-gptel-capf nil t))

  (add-to-list 'org-structure-template-alist '("gp" . "src gptel"))

  :hook (org-mode . ob-gptel-setup-completions))

(with-eval-after-load 'gptel
  (defun gptel--append-response-footer (beg end)
    "Append a footer after a completed gptel response."
    (when (> end beg)
      (save-excursion
        (goto-char end)
        (insert
         (pcase major-mode
           ('markdown-mode
            (concat "\n\n[comment]: <> (Responded: "
                    (format-time-string "%Y-%m-%d %a %H:%M:%S %:::z")
                    ")"))
           ('org-mode
            (concat "\n\n# Responded: "
                    (format-time-string "%Y-%m-%d %a %H:%M:%S %:::z")))
           (_ ""))))))

  (add-hook 'gptel-post-response-functions #'gptel--append-response-footer))

(use-package gptel-titler
  :load-path "~/code/emacs/gptel-titler/")

(elpaca mcp
  (use-package mcp
    :init
    (setopt mcp-hub-servers
            '(("searxng-isokoliuk" . (:command "podman"
                                               :args ("run" "--rm" "-i"
                                                      "--network" "host"
                                                      "-e" "SEARXNG_URL=http://127.0.0.1:32768"
                                                      "isokoliuk/mcp-searxng:latest")))
              ("searxng-icewreck" . (:command "podman"
                                              :args ("run" "--rm" "-i"
                                                     "--network" "host"
                                                     "-e" "SEARXNG_URL=http://127.0.0.1:32768"
                                                     "docker.io/icewreck/searxng-mcp-server:latest")))))
    ))

(use-package gptel-integrations
  :after mcp)

(defun new-ai-chat-file (&optional new-file)
  (interactive)
  (let* ((defoutfile (expand-file-name (concat (time-stamp-string "%Y%m%dT%H%M%S") ".org") "~/ai/chats/"))
         (outfile (file-truename (or new-file defoutfile))))
    (find-file outfile)))

(provide 'llm-ai-assistants)
;;; llm-ai-assistants.el ends here
