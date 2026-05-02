;;; llm-ai-assistants.el --- AI assistant features config -*- lexical-binding: t; -*-

;;; Code

(use-package gptel
  :init
  (setq gptel-model 'MiniMax-M2.7
        gptel-default-mode 'org-mode)
  :config
  (gptel-make-gemini "Gemini"
    :stream t
    :key (gptel-api-key-from-auth-source "generativelanguage.googleapis.com"))
  (gptel-make-anthropic "Claude"
    :stream t
    :key (gptel-api-key-from-auth-source "api.anthropic.com"))

  (gptel-make-openai "MiniMax"
    :host "api.minimax.io"
    :endpoint "/v1/chat/completions"
    :stream t
    :key (gptel-api-key-from-auth-source "api.minimax.io")
    :models '(MiniMax-M2.5
              MiniMax-M2.5-highspeed
              MiniMax-M2.1
              MiniMax-M2.1-highspeed
              MiniMax-M2
              MiniMax-M2.7
              MiniMax-M2.7-highspeed))

  (gptel-make-ollama "Ollama"
    :host "localhost:11434"
    :stream t
    :models '(qwen3.5:9b
              ))

  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (gptel-api-key-from-auth-source "openrouter.ai")
    :models '(
              ;; 1. CODING & LOGIC
              deepseek/deepseek-v4-pro
              deepseek/deepseek-v4-flash
              moonshotai/kimi-k2.6:nitro
              xiaomi/mimo-v2.5-pro
              mistralai/devstral-2-2512:free ; Free Fallback
              inclusionai/ling-2.6-1t:free ;; until April 30
              
              ;; 2. GENERAL PURPOSE (MINI EQUIVALENT)
              gpt-oss-120b:floor
              gpt-oss-120b:nitro
              stepfun/step-3.5-flash:nitro

              qwen/qwen3.6-plus:free
              tencent/hy3-preview:free
              
              ;; 3. DATA EXTRACTION / TOOL USE
              meta-llama/llama-3.3-70b-instruct:nitro
              
              ;; THE LAZY FREE OPTION
              openrouter/free
              )
    ;; :request-params '(:provider (:allow_fallbacks t
    ;;                              :sort "price"))
    )

  (gptel-make-openai "Groq"
    :host "api.groq.com"
    :endpoint "/openai/v1/chat/completions"
    :stream t
    :key (gptel-api-key-from-auth-source "api.groq.co")
    :models '(openai/gpt-oss-120b
              llama-3.3-70b-versatile
              qwen/qwen3-32b
              llama-3.1-8b-instant
              openai/gpt-oss-safeguard-20b
              whisper-large-v3-turbo
              canopylabs/orpheus-v1-english
              canopylabs/orpheus-arabic-saudi))

  (gptel-make-deepseek "DeepSeek"
    :stream t
    :key (gptel-api-key-from-auth-source "api.deepseek.com"))

  (with-eval-after-load 'org
    (add-to-list 'org-use-property-inheritance "GPTEL_MODEL")
    (add-to-list 'org-use-property-inheritance "GPTEL_BACKEND")
    (add-to-list 'org-use-property-inheritance "GPTEL_SYSTEM")
    (add-to-list 'org-use-property-inheritance "GPTEL_TEMPERATURE")))

(use-package ob-gptel
  :after gptel
  :load-path "~/clones/11xx-ob-gptel/"
  :hook (org-mode . ob-gptel-setup-completions)
  :config
  (add-to-list 'org-babel-load-languages '(gptel . t))
  (defun ob-gptel-setup-completions ()
    (add-hook 'completion-at-point-functions
              'ob-gptel-capf nil t))

  (add-to-list 'org-structure-template-alist '("gp" . "src gptel")))

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
  :after gptel
  :load-path "~/code/emacs/gptel-titler/")

(use-package mcp
  :init
  (setq mcp-hub-servers
        `(("searxng-isokoliuk" . (:command "podman"
                                           :args ("run" "--rm" "-i"
                                                  "--network" "host"
                                                  "--env-file" ,(expand-file-name "~/ai/searxng/.env")
                                                  "isokoliuk/mcp-searxng:latest"))) ; ts
          ("searxng-icewreck" . (:command "podman"
                                          :args ("run" "--rm" "-i"
                                                 "--network" "host"
                                                 "--env-file" ,(expand-file-name "~/ai/searxng/.env")
                                                 "docker.io/icewreck/searxng-mcp-server:latest"))))) ; python
  )

(use-package gptel-integrations
  :ensure nil
  :after mcp)

(defun new-ai-chat-file (&optional new-file)
  (interactive)
  (let* ((defoutfile (expand-file-name (concat (time-stamp-string "%Y%m%dT%H%M%S") ".org") "~/ai/chats/"))
         (outfile (file-truename (or new-file defoutfile))))
    (find-file outfile)))

(provide 'llm-ai-assistants)
;;; llm-ai-assistants.el ends here
