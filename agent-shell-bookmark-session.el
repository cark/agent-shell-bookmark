;;; agent-shell-bookmark-session.el --- Exact session restoration -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Sacha De Vos
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Keep the private agent-shell integration here.  Ordinary sessions retain
;; upstream's behavior; bookmark restores must never choose another session.

;;; Code:
(require 'agent-shell)
(require 'map)

(defvar-local agent-shell-bookmark-session--target nil
  "Exact session requested by a bookmark in this buffer.")
(defvar-local agent-shell-bookmark-session--status nil
  "Bookmark restoration status: starting, ready, or failed.")

(defun agent-shell-bookmark-session--fail (text)
  "Show restore failure TEXT without opening another conversation."
  (setq agent-shell-bookmark-session--status 'failed)
  (agent-shell-heartbeat-stop :heartbeat (map-elt (agent-shell--state) :heartbeat))
  (agent-shell--update-bootstrapping-fragment
   :state (agent-shell--state) :block-id "starting"
   :label-left "Bookmark restore failed" :body text :expanded t)
  (message "Agent Shell bookmark: %s" text))

(defun agent-shell-bookmark-session--initiate (original &rest args)
  "Call ORIGINAL with ARGS unless this buffer requires exact restoration."
  (if-let* (((not (eq agent-shell-bookmark-session--status 'ready)))
             (target agent-shell-bookmark-session--target))
      (let ((state (agent-shell--state))
            (ready (plist-get args :on-session-init)))
        (setq agent-shell-bookmark-session--target target
              agent-shell-bookmark-session--status 'starting)
        (if (or (map-elt state :supports-session-load)
                (map-elt state :supports-session-resume))
            (agent-shell--initiate-session-resume-by-id
             :session-id target :shell-buffer (current-buffer)
             :on-session-init
             (lambda ()
               (setq agent-shell-bookmark-session--status 'ready)
               (funcall ready))
             :on-failure
             (lambda ()
               (agent-shell-bookmark-session--fail
                "Session unavailable. Close this buffer and retry the bookmark.")))
          (agent-shell-bookmark-session--fail
           "This agent cannot restore sessions. No new session was created.")))
    (apply original args)))

(cl-defun agent-shell-bookmark-session-start (&key config directory session)
  "Return a background shell for CONFIG in DIRECTORY, restoring SESSION.
For example, SESSION may be an opaque ID such as \"conversation-42\"."
  (unless (advice-member-p #'agent-shell-bookmark-session--initiate
                           'agent-shell--initiate-session)
    (advice-add 'agent-shell--initiate-session :around
                #'agent-shell-bookmark-session--initiate))
  (let ((guarded-config (copy-alist config))
        (client-maker (map-elt config :client-maker))
        (arming t) owned-buffer completed)
    ;; Upstream calls the client maker before starting asynchronous work.
    ;; Arming ends when this start returns, so later restarts keep their policy.
    (setf (map-elt guarded-config :client-maker)
          (lambda (buffer)
            (when arming
              (setq owned-buffer buffer)
              (with-current-buffer buffer
                (setq agent-shell-bookmark-session--target session
                      agent-shell-bookmark-session--status 'starting)))
            (funcall client-maker buffer)))
    (unwind-protect
        (prog1 (agent-shell--start :config guarded-config :cwd directory :no-focus t
                                  :new-session t :session-strategy 'new
                                  :session-id session)
          (setq completed t))
      (setq arming nil)
      (when (and (not completed) (buffer-live-p owned-buffer))
        (with-current-buffer owned-buffer
          (let ((kill-buffer-query-functions nil))
            (kill-buffer owned-buffer)))))))

(provide 'agent-shell-bookmark-session)
;;; agent-shell-bookmark-session.el ends here
