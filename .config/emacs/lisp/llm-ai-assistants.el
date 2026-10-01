;;; llm-ai-assistants.el --- AI assistant features config -*- lexical-binding: t; -*-

;;; Code

(use-package gptel
  :init
  (setq gptel-default-mode 'org-mode)
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
              MiniMax-M2.7-highspeed
              MiniMax-M3
              MiniMax-M3-highspeed))
  (setq gptel-model 'MiniMax-M3-highspeed)

  (gptel-make-ollama "Ollama"
    :host "localhost:11434"
    :stream t
    :models '(qwen3.5:9b
              ))

  (use-package gptel-openrouter
    :vc (:url "https://github.com/darcamo/gptel-openrouter")
    :after gptel
    :config
    (require 'seq)

    (defun gptel-openrouter-model-free-p (model)
      "Return non-nil if MODEL appears to be a free OpenRouter model.

MODEL is one model alist from the cached OpenRouter `/models` response."
      (let ((id (alist-get 'id model)))
        (and id
             (string-match-p "\\(:free\\|^openrouter/free$\\)" id))))

    (defun gptel-openrouter-get-all-models (&optional predicate)
      "Return all cached OpenRouter model IDs as symbols.

If PREDICATE is non-nil, it is called with each model alist from the
cached OpenRouter model data. Only models for which PREDICATE returns
non-nil are kept."
      ;; Downloads only if the cache is missing or older than one day,
      ;; according to gptel-openrouter's own logic.
      (gptel-openrouter-download-model-data)

      ;; Invalidate the in-memory parsed JSON cache so a freshly downloaded
      ;; models.json is visible during the same Emacs session.
      (setq gptel-openrouter--json-cache-content nil)

      (let* ((content (gptel-openrouter--get-json-content))
             (models (alist-get 'data content)))
        (unless models
          (user-error
           "No OpenRouter model data found; run M-x gptel-openrouter-download-model-data"))
        (mapcar
         (lambda (model)
           (intern (alist-get 'id model)))
         (seq-filter
          (lambda (model)
            (and (alist-get 'id model)
                 (or (null predicate)
                     (funcall predicate model))))
          models))))

    (defun gptel-openrouter-get-all-annotated-models (&optional predicate)
      "Return all cached OpenRouter models annotated for gptel.

If PREDICATE is non-nil, only annotate models for which PREDICATE
returns non-nil."
      (gptel-openrouter-get-annotated-models
       (gptel-openrouter-get-all-models predicate)))

    (gptel-make-openai "OpenRouter"
      :host "openrouter.ai"
      :endpoint "/api/v1/chat/completions"
      :stream t
      :key (gptel-api-key-from-auth-source "openrouter.ai")

      ;; All current cached OpenRouter models, excluding free models.
      :models
      (gptel-openrouter-get-all-annotated-models
       (lambda (model)
         (not (gptel-openrouter-model-free-p model))))

      :request-params
      '(:service_tier "flex"
        :provider (:sort "throughput"
                         :allow_fallbacks :json-false
                         :data_collection "deny"
                         :zdr t))))

  (gptel-make-openai "Groq"
    :host "api.groq.com"
    :endpoint "/openai/v1/chat/completions"
    :stream t
    :key (gptel-api-key-from-auth-source "api.groq.com")
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
  :load-path "~/code/emacs/gptel-titler/"
  :init
  (setopt gptel-titler-model 'openai/gpt-oss-safeguard-20b)
  :config
  ;; example add new model name to existing backend
  ;; (let ((backend (gptel-get-backend "OpenRouter")))
  ;;   (when backend
  ;;     (cl-pushnew 'openai/gpt-oss-safeguard-20b
  ;;                 (gptel-backend-models backend)
  ;;                 :key (lambda (x) (if (listp x) (car x) x)))))
  )

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
