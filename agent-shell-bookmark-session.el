;;; agent-shell-bookmark-session.el --- Exact session restoration -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Sacha De Vos
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Keep the private agent-shell integration here.  Ordinary sessions retain
;; upstream's behavior; bookmark restores must never choose another session.

;;; Code:
(require 'agent-shell)
(require 'map)

(defvar agent-shell-bookmark-session--starting nil
  "Session ID being started synchronously by this addon.")
(defvar-local agent-shell-bookmark-session--target nil
  "Exact session requested by a bookmark in this buffer.")
(defvar-local agent-shell-bookmark-session--status nil
  "Bookmark restoration status: starting, ready, or failed.")

(defun agent-shell-bookmark-session--fail (text)
  "Show restore failure TEXT without opening another conversation."
  (setq agent-shell-bookmark-session--status 'failed)
  (agent-shell-heartbeat-stop :heartbeat (map-elt (agent-shell--state) :heartbeat))
  (setq-local header-line-format (concat "Bookmark: " text))
  (message "Agent Shell bookmark: %s" text))

(defun agent-shell-bookmark-session--initiate (original &rest args)
  "Call ORIGINAL with ARGS unless this buffer requires exact restoration."
  (if-let* ((target (or (and (not (eq agent-shell-bookmark-session--status 'ready))
                                  agent-shell-bookmark-session--target)
                             (and agent-shell-bookmark-session--starting
                                  (equal agent-shell-bookmark-session--starting
                                         (map-elt (agent-shell--state) :resume-session-id))
                                  agent-shell-bookmark-session--starting))))
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
  (let* ((agent-shell-bookmark-session--starting session)
         (buffer (agent-shell--start :config config :cwd directory :no-focus t
                                    :new-session t :session-strategy 'new
                                    :session-id session)))
    (with-current-buffer buffer
      (setq agent-shell-bookmark-session--target session)
      (unless agent-shell-bookmark-session--status
        (setq agent-shell-bookmark-session--status 'starting)))
    buffer))

(provide 'agent-shell-bookmark-session)
;;; agent-shell-bookmark-session.el ends here
