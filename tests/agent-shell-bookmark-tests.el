;;; agent-shell-bookmark-tests.el --- Bookmark contracts -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(require 'agent-shell-bookmark)

(defconst asb-test-config '((:identifier . test-agent)))
(defun asb-test-shell (session directory)
  "Create a process-free shell fixture for SESSION in DIRECTORY."
  (let ((buffer (generate-new-buffer " *bookmark fixture*")))
    (with-current-buffer buffer
      (setq major-mode 'agent-shell-mode default-directory directory)
      (setq-local agent-shell--state
                  (copy-tree `((:buffer . ,buffer) (:agent-config . ,asb-test-config)
                    (:session . ((:id . ,session)))
                    (:supports-session-load . nil) (:supports-session-resume . nil)))))
    buffer))

(defmacro asb-test-with-shell (&rest body)
  "Run BODY in a disposable shell, directory and bookmark collection."
  (declare (indent 0))
  `(let* ((directory (make-temp-file "asb-test-" t))
          (agent-shell-agent-configs (list asb-test-config))
          (bookmark-alist nil) (bookmark-save-flag nil)
          (bookmark-default-file (expand-file-name "bookmarks" directory))
          (buffer (asb-test-shell "session-42" directory)))
     (unwind-protect
         (save-window-excursion
           (switch-to-buffer buffer)
           ;; Process-free fixtures test control flow, not upstream rendering.
           (cl-letf (((symbol-function 'agent-shell--update-bootstrapping-fragment) #'ignore))
             ,@body))
       (agent-shell-bookmark-mode -1)
       (when (buffer-live-p buffer) (kill-buffer buffer))
       (delete-directory directory t))))

(ert-deftest asb-record-roundtrip-reuses-exact-shell ()
  (asb-test-with-shell
    (agent-shell-bookmark-mode 1)
    (bookmark-set "Reading")
    (bookmark-save)
    (setq bookmark-alist nil)
    (bookmark-load bookmark-default-file t t)
    (switch-to-buffer (get-buffer-create "*scratch*"))
    (bookmark-jump "Reading")
    (should (eq buffer (current-buffer)))
    (should (equal (bookmark-prop-get "Reading" 'agent-shell-bookmark-session) "session-42"))
    (should-not (bookmark-prop-get "Reading" 'filename))))

(ert-deftest asb-config-makers-save-and-restore-bookmarks ()
  (asb-test-with-shell
    (agent-shell-bookmark-mode 1)
    (dolist (entries (list
                      (append (agent-shell-default-agent-config-makers)
                              (list (lambda () asb-test-config)))
                      (lambda () (list (lambda () asb-test-config)))))
      (let ((agent-shell-agent-configs entries))
        (set-buffer buffer)
        (bookmark-set "Maker")
        (switch-to-buffer (get-buffer-create "*scratch*"))
        (bookmark-jump "Maker")
        (should (eq buffer (current-buffer)))
        (should (equal (bookmark-prop-get "Maker" 'agent-shell-bookmark-session)
                       "session-42"))))
    (let ((agent-shell-agent-configs
           (list asb-test-config (lambda () asb-test-config))))
      (should-error (agent-shell-bookmark-make-record) :type 'user-error))))

(ert-deftest asb-restore-establishes-buffer-without-selecting-window ()
  (asb-test-with-shell
    (let ((record (agent-shell-bookmark-make-record))
          (origin-window (selected-window)) result)
      (kill-buffer buffer)
      (cl-letf (((symbol-function 'agent-shell-bookmark-session-start)
                 (lambda (&rest args)
                   (should (equal (plist-get args :session) "session-42"))
                   (setq result (asb-test-shell "session-42" directory)))))
        (agent-shell-bookmark-jump record)
        (should (eq result (current-buffer)))
        (should (eq origin-window (selected-window)))
        (should-not (eq result (window-buffer)))
        (setq buffer result)))))

(ert-deftest asb-matching-requires-agent-directory-and-session ()
  (asb-test-with-shell
    (let ((location (agent-shell-bookmark--read (agent-shell-bookmark-make-record))))
      (should (eq buffer (agent-shell-bookmark--buffer location)))
      (map-put! location :session "different")
      (should-not (agent-shell-bookmark--buffer location))
      (setq-local agent-shell-bookmark-session--target "different"
                  agent-shell-bookmark-session--status 'starting)
      (should (eq buffer (agent-shell-bookmark--buffer location)))
      (map-put! location :agent 'another)
      (should-not (agent-shell-bookmark--buffer location)))))

(ert-deftest asb-invalid-record-and-missing-directory-are-ordinary-messages ()
  (asb-test-with-shell
    (let ((record (agent-shell-bookmark-make-record)) (debug-on-error t))
      (setcdr (assq 'agent-shell-bookmark-version (cdr record)) 99)
      (agent-shell-bookmark-jump record)
      (should (eq buffer (current-buffer)))
      (setcdr (assq 'agent-shell-bookmark-version (cdr record)) 1)
      (setcdr (assq 'agent-shell-bookmark-directory (cdr record))
              (expand-file-name "absent" directory))
      (agent-shell-bookmark-jump record)
      (should (eq buffer (current-buffer))))))

(ert-deftest asb-ambiguous-agent-and-unstarted-session-cannot-be-saved ()
  (asb-test-with-shell
    (let ((agent-shell-agent-configs (list asb-test-config asb-test-config)))
      (should-error (agent-shell-bookmark-make-record) :type 'user-error))
    (map-put! agent-shell--state :session nil)
    (should-error (agent-shell-bookmark-make-record) :type 'user-error)))

(ert-deftest asb-mode-restores-previous-record-maker ()
  (asb-test-with-shell
    (setq-local bookmark-make-record-function #'ignore)
    (agent-shell-bookmark-mode 1)
    (agent-shell-bookmark-mode 1)
    (should (eq bookmark-make-record-function #'agent-shell-bookmark-make-record))
    (agent-shell-bookmark-mode -1)
    (should (eq bookmark-make-record-function #'ignore))))

(ert-deftest asb-strict-resume-never-falls-back ()
  (asb-test-with-shell
    (let ((agent-shell-bookmark-session--target "session-42")
          (debug-on-error t) resumed completed)
      (map-put! agent-shell--state :supports-session-load t)
      (cl-letf (((symbol-function 'agent-shell--initiate-session-resume-by-id)
                 (lambda (&rest args)
                   (setq resumed (plist-get args :session-id))
                   (funcall (plist-get args :on-failure)))))
        (agent-shell-bookmark-session--initiate
         (lambda (&rest _) (ert-fail "Fallback called"))
         :on-session-init (lambda () (setq completed t)))
        (should (equal resumed "session-42"))
        (should-not completed)
        (should (eq agent-shell-bookmark-session--status 'failed))))))

(ert-deftest asb-unsupported-agent-never-creates-a-session ()
  (asb-test-with-shell
    (let ((agent-shell-bookmark-session--target "session-42"))
      (agent-shell-bookmark-session--initiate
       (lambda (&rest _) (ert-fail "Fallback called")) :on-session-init #'ignore)
      (should (eq agent-shell-bookmark-session--status 'failed)))))

(ert-deftest asb-ordinary-session-keeps-upstream-behavior ()
  (asb-test-with-shell
    (let (called)
      (agent-shell-bookmark-session--initiate
       (lambda (&rest args) (setq called args)) :on-session-init #'ignore)
      (should (equal called '(:on-session-init ignore))))))

(ert-deftest asb-success-completes-once ()
  (asb-test-with-shell
    (let ((agent-shell-bookmark-session--target "session-42") (completed 0))
      (map-put! agent-shell--state :supports-session-resume t)
      (cl-letf (((symbol-function 'agent-shell--initiate-session-resume-by-id)
                 (lambda (&rest args) (funcall (plist-get args :on-session-init)))))
        (agent-shell-bookmark-session--initiate
         #'ignore :on-session-init (lambda () (setq completed (1+ completed))))
        (should (= completed 1))
        (should (eq agent-shell-bookmark-session--status 'ready))))))

(ert-deftest asb-successful-restore-does-not-hijack-later-session-start ()
  (asb-test-with-shell
    (let ((agent-shell-bookmark-session--target "session-42")
          (agent-shell-bookmark-session--status 'ready) called)
      (agent-shell-bookmark-session--initiate
       (lambda (&rest _) (setq called t)) :on-session-init #'ignore)
      (should called))))

(ert-deftest asb-disable-restores-inherited-binding ()
  (asb-test-with-shell
    (kill-local-variable 'bookmark-make-record-function)
    (agent-shell-bookmark-mode 1)
    (agent-shell-bookmark-mode -1)
    (should-not (local-variable-p 'bookmark-make-record-function))))
