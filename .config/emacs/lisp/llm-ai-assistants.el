;; -*- lexical-binding: t; -*-
(setup (:elpaca gptel)
  ;; (:require auth-source) ; seems necessary, for some reason setup.el
  (:option gptel-api-key (auth-source-pick-first-password :host "api.perplexity.ai")
           gptel-model 'sonar-pro
           gptel-backend (gptel-make-perplexity "Perplexity"
                           :key (auth-source-pick-first-password :host "api.perplexity.ai")
                           :stream t)
           gptel-default-mode 'org-mode)

  (gptel-make-ollama "Ollama"             ;Any name of your choosing
    :host "localhost:11434"               ;Where it's running
    :stream t                             ;Stream responses
    :models '(mistral:latest              ;List of models
              granite-code:8b
              granite-code:20b
              llama3.2
              qwen2.5-coder
              qwen2.5-coder:7b-instruct-q8_0
              yi-coder
              codellama:7b
              deepseek-coder-v2:16b)))
(setup (:elpaca aider :host github :repo "tninja/aider.el" :files ("aider.el"))
  (setq aider-program (expand-file-name "venv/bin/aider" (xdg-user-dir "DESKTOP"))
        aider-args '("--model" "ollama/qwen2.5-coder:7b-instruct-q8_0"))
  (setenv "OLLAMA_API_BASE" "http://127.0.0.1:11434")
  ;; (setenv "OPENAI_API_KEY" <your-openai-api-key>)
  ;; Optional: Set a key binding for the transient menu
  ;; (keymap-global-set "C-c a" #'aider-transient-menu)
  )

(provide 'llm-ai-assistants)
