;; -*- lexical-binding: t; -*-
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
    (gptel-make-openai "ChatGPT"
      :stream t
      :models gptel--openai-models))

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

(provide 'llm-ai-assistants)
