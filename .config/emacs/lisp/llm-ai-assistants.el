;; -*- lexical-binding: t; -*-
(setup (:elpaca gptel)
  (setopt gptel-model 'gpt-5-nano)

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
              )))

(provide 'llm-ai-assistants)
