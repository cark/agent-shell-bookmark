;;; integration-tests.el --- Upstream process integration -*- lexical-binding: t; -*-
(require 'agent-shell-bookmark)
(require 'ert)
(defconst asb-integration-library (or load-file-name buffer-file-name))
(defconst asb-integration-agent
  (expand-file-name "acp-agent.py" (file-name-directory (or load-file-name buffer-file-name))))

(defun asb-integration-config (log)
  "Return a real ACP client config recording requests in LOG."
  (agent-shell-make-agent-config
   :identifier 'offline-bookmark :buffer-name "Bookmark fixture"
   :mode-line-name "Fixture" :shell-prompt "Fixture> "
   :shell-prompt-regexp "Fixture> "
   :client-maker (lambda (buffer)
                   (acp-make-client :command (executable-find "python3")
                                    :command-params (list asb-integration-agent log)
                                    :context-buffer buffer))))

(defun asb-integration-wait (buffer)
  "Wait for BUFFER's real ACP restoration to finish, with a bounded timeout."
  (let ((deadline (+ (float-time) 8)))
    (while (and (< (float-time) deadline)
                (with-current-buffer buffer
                  (eq agent-shell-bookmark-session--status 'starting)))
      (accept-process-output nil 0.02)))
  (should-not (with-current-buffer buffer
                (eq agent-shell-bookmark-session--status 'starting))))

(defmacro asb-integration-with-profile (&rest body)
  "Run BODY with a disposable ROOT and real offline CONFIG."
  (declare (indent 0))
  `(let* ((root (make-temp-file "asb-integration-" t))
          (default-directory (file-name-as-directory root))
          (user-emacs-directory (file-name-as-directory root))
          (log (expand-file-name "requests.jsonl" root))
          (config (asb-integration-config log))
          (agent-shell-agent-configs (list config))
          (agent-shell-show-welcome-message nil)
          (agent-shell-highlight-blocks nil)
          (agent-shell-session-restore-verbosity 'full)
          (agent-shell-file-completion-enabled nil))
     (unwind-protect
         (save-window-excursion ,@body)
       (dolist (buffer (buffer-list))
         (when (with-current-buffer buffer
                 (and (derived-mode-p 'agent-shell-mode)
                      (eq (map-elt (agent-shell-get-config buffer) :identifier) 'offline-bookmark)))
           (with-current-buffer buffer (setq-local kill-buffer-query-functions nil))
           (kill-buffer buffer)))
       (delete-directory root t))))

(ert-deftest asb-upstream-process-restores-and-refuses-without-fallback ()
  (asb-integration-with-profile
    (let ((view (agent-shell-bookmark-session-start :config config :directory root :session "reading")))
      (asb-integration-wait view)
      (should (equal (agent-shell-session-id :shell-buffer view) "reading")))
    (let ((view (agent-shell-bookmark-session-start :config config :directory root :session "missing")))
      (asb-integration-wait view)
      (should (eq (buffer-local-value 'agent-shell-bookmark-session--status view) 'failed))
      (should-not (agent-shell-session-id :shell-buffer view))
      (with-current-buffer view
        (should-not (map-nested-elt (agent-shell--state) '(:heartbeat :heartbeat-timer)))))
    (with-temp-buffer
      (insert-file-contents log)
      (should-not (string-match-p "session/new\\|session/list\\|session/prompt" (buffer-string))))))

(ert-deftest asb-fresh-emacs-restores-persisted-record ()
  (asb-integration-with-profile
    (let* ((bookmark-default-file (expand-file-name "bookmarks" root))
           (bookmark-alist nil) (bookmark-save-flag nil)
           (view (agent-shell-bookmark-session-start :config config :directory root :session "planning")))
      (asb-integration-wait view)
      (with-current-buffer view
        (setq-local bookmark-make-record-function #'agent-shell-bookmark-make-record)
        (bookmark-set "Persisted"))
      (bookmark-save)
      (with-current-buffer view (setq-local kill-buffer-query-functions nil))
      (kill-buffer view)
      (with-temp-buffer
        (let ((status
               (call-process
                (expand-file-name invocation-name invocation-directory) nil t nil
                "-Q" "--batch" "--eval"
                (prin1-to-string
                 `(progn
                    (setq load-path ',load-path user-emacs-directory ,user-emacs-directory
                          default-directory ,default-directory)
                    (require 'agent-shell-bookmark)
                    (load ,asb-integration-library nil t)
                    (setq agent-shell-agent-configs (list (asb-integration-config ,log))
                          agent-shell-show-welcome-message nil
                          bookmark-default-file ,bookmark-default-file)
                    (bookmark-load bookmark-default-file t t)
                    (bookmark-jump "Persisted")
                    (asb-integration-wait (current-buffer))
                    (unless (equal (agent-shell-session-id) "planning")
                      (error "Restored a different session")))))))
          (unless (zerop status) (ert-fail (buffer-string))))))))
