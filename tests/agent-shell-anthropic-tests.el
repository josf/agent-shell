;;; agent-shell-anthropic-tests.el --- Tests for agent-shell-anthropic -*- lexical-binding: t; -*-

(require 'ert)
(require 'agent-shell)
(require 'agent-shell-anthropic)

(ert-deftest agent-shell-anthropic-make-claude-client-test ()
  "Test agent-shell-anthropic-make-claude-client function."
  ;; Mock executable-find to always return the command path
  (cl-letf (((symbol-function 'executable-find)
             (lambda (_) "/usr/bin/claude-agent-acp")))
    ;; Test with API key authentication
    (let* ((agent-shell-anthropic-authentication '(:api-key "test-api-key"))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp" "--json"))
           (agent-shell-anthropic-claude-environment '("DEBUG=1"))
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer)))
      (unwind-protect
          (progn
            (should (listp client))
            (should (equal (map-elt client :command) "claude-agent-acp"))
            (should (equal (map-elt client :command-params) '("--json")))
            (should (member "ANTHROPIC_API_KEY=test-api-key" (map-elt client :environment-variables)))
            (should (member "DEBUG=1" (map-elt client :environment-variables))))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test with login authentication
    (let* ((agent-shell-anthropic-authentication '(:login t))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp" "--interactive"))
           (agent-shell-anthropic-claude-environment '("VERBOSE=true"))
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer)))
      (unwind-protect
          (progn
            ;; Verify environment variables include empty API key for login
            (should (member "ANTHROPIC_API_KEY=" (map-elt client :environment-variables)))
            (should (member "VERBOSE=true" (map-elt client :environment-variables))))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test with function-based API key
    (let* ((agent-shell-anthropic-authentication `(:api-key ,(lambda () "dynamic-key")))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (agent-shell-anthropic-claude-environment '())
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer))
           (env-vars (map-elt client :environment-variables)))
      (unwind-protect
          (should (member "ANTHROPIC_API_KEY=dynamic-key" env-vars))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test error on invalid authentication
    (let* ((agent-shell-anthropic-authentication '())
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (test-buffer (get-buffer-create "*test-buffer*")))
      (unwind-protect
          (should-error (agent-shell-anthropic-make-claude-client :buffer test-buffer)
                        :type 'error)
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test with agent-shell-make-environment-variables and :inherit-env t
    (let* ((agent-shell-anthropic-authentication '(:api-key "test-key"))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (process-environment '("EXISTING_VAR=existing_value"))
           (agent-shell-anthropic-claude-environment (agent-shell-make-environment-variables
                                                      "NEW_VAR" "new_value"
                                                      :inherit-env t))
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer))
           (env-vars (map-elt client :environment-variables)))
      (unwind-protect
          (progn
            (should (member "ANTHROPIC_API_KEY=test-key" env-vars))
            (should (member "NEW_VAR=new_value" env-vars))
            (should (member "EXISTING_VAR=existing_value" env-vars)))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test with OAuth token string
    (let* ((agent-shell-anthropic-authentication '(:oauth "test-oauth-token"))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (agent-shell-anthropic-claude-environment '())
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer))
           (env-vars (map-elt client :environment-variables)))
      (unwind-protect
          (should (member "CLAUDE_CODE_OAUTH_TOKEN=test-oauth-token" env-vars))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test with function-based OAuth token
    (let* ((agent-shell-anthropic-authentication `(:oauth ,(lambda () "dynamic-oauth-token")))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (agent-shell-anthropic-claude-environment '())
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer))
           (env-vars (map-elt client :environment-variables)))
      (unwind-protect
          (should (member "CLAUDE_CODE_OAUTH_TOKEN=dynamic-oauth-token" env-vars))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))))

(ert-deftest agent-shell-anthropic-make-claude-client-bedrock-test ()
  "Test agent-shell-anthropic-make-claude-client with Bedrock authentication."
  (cl-letf (((symbol-function 'executable-find)
             (lambda (_) "/usr/bin/claude-agent-acp")))
    ;; Test with Bedrock authentication (region and profile)
    (let* ((agent-shell-anthropic-authentication
            '(:bedrock ((:region . "us-east-1")
                        (:profile . "my-profile"))))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (agent-shell-anthropic-claude-environment '())
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer))
           (env-vars (map-elt client :environment-variables)))
      (unwind-protect
          (progn
            (should (member "CLAUDE_CODE_USE_BEDROCK=1" env-vars))
            (should (member "AWS_REGION=us-east-1" env-vars))
            (should (member "AWS_PROFILE=my-profile" env-vars)))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test with Bedrock authentication (region only, no profile)
    (let* ((agent-shell-anthropic-authentication
            '(:bedrock ((:region . "us-east-1"))))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (agent-shell-anthropic-claude-environment '())
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer))
           (env-vars (map-elt client :environment-variables)))
      (unwind-protect
          (progn
            (should (member "CLAUDE_CODE_USE_BEDROCK=1" env-vars))
            (should (member "AWS_REGION=us-east-1" env-vars))
            (should (not (seq-find (lambda (v) (string-prefix-p "AWS_PROFILE=" v)) env-vars))))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))

    ;; Test Bedrock with additional environment variables
    (let* ((agent-shell-anthropic-authentication
            '(:bedrock ((:region . "us-east-1")
                        (:profile . "my-profile"))))
           (agent-shell-anthropic-claude-acp-command '("claude-agent-acp"))
           (agent-shell-anthropic-claude-environment '("ANTHROPIC_MODEL=eu.anthropic.claude-opus-4-6-v1"))
           (test-buffer (get-buffer-create "*test-buffer*"))
           (client (agent-shell-anthropic-make-claude-client :buffer test-buffer))
           (env-vars (map-elt client :environment-variables)))
      (unwind-protect
          (progn
            (should (member "CLAUDE_CODE_USE_BEDROCK=1" env-vars))
            (should (member "AWS_REGION=us-east-1" env-vars))
            (should (member "ANTHROPIC_MODEL=eu.anthropic.claude-opus-4-6-v1" env-vars)))
        (when (buffer-live-p test-buffer)
          (kill-buffer test-buffer))))))

(ert-deftest agent-shell-anthropic-make-authentication-bedrock-validation-test ()
  "Test validation in agent-shell-anthropic-make-authentication for Bedrock."
  ;; Bedrock requires :region
  (should-error (agent-shell-anthropic-make-authentication
                 :bedrock '((:profile . "some-profile")))
                :type 'error)

  ;; Cannot combine bedrock with api-key
  (should-error (agent-shell-anthropic-make-authentication
                 :bedrock '((:region . "us-east-1"))
                 :api-key "test-key")
                :type 'error)

  ;; Cannot combine bedrock with login
  (should-error (agent-shell-anthropic-make-authentication
                 :bedrock '((:region . "us-east-1"))
                 :login t)
                :type 'error)

  ;; Cannot combine bedrock with oauth
  (should-error (agent-shell-anthropic-make-authentication
                 :bedrock '((:region . "us-east-1"))
                 :oauth "test-token")
                :type 'error)

  ;; Valid bedrock config
  (should (equal (agent-shell-anthropic-make-authentication
                  :bedrock '((:region . "us-east-1")
                             (:profile . "my-profile")))
                 '((:bedrock . ((:region . "us-east-1")
                                (:profile . "my-profile")))))))

(ert-deftest agent-shell-anthropic-default-model-id-function-test ()
  "Test that agent-shell-anthropic-default-model-id accepts a function."
  (let* ((config (agent-shell-anthropic-make-claude-code-config))
         (default-model-id-fn (map-elt config :default-model-id)))

    ;; Test with nil value
    (let ((agent-shell-anthropic-default-model-id nil))
      (should (null (funcall default-model-id-fn))))

    ;; Test with string value
    (let ((agent-shell-anthropic-default-model-id "claude-opus-4-6"))
      (should (string= (funcall default-model-id-fn) "claude-opus-4-6")))

    ;; Test with function value
    (let ((agent-shell-anthropic-default-model-id (lambda () "dynamic-model-id")))
      (should (string= (funcall default-model-id-fn) "dynamic-model-id")))

    ;; Test with function that returns nil
    (let ((agent-shell-anthropic-default-model-id (lambda () nil)))
      (should (null (funcall default-model-id-fn))))))

(provide 'agent-shell-anthropic-tests)
;;; agent-shell-anthropic-tests.el ends here
