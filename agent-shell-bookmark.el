;;; agent-shell-bookmark.el --- Restore agent conversations with bookmarks -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Sacha De Vos
;; Author: Sacha De Vos
;; Maintainer: Sacha De Vos
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (agent-shell "0.89.5"))
;; Keywords: convenience
;; URL: https://github.com/cark/agent-shell-bookmark
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Save agent-shell conversations with standard Emacs bookmarks.  Activities
;; can then restore their buffers as part of a saved window layout.
;; Enable `agent-shell-bookmark-mode', then use `bookmark-set'.

;;; Code:
(require 'bookmark)
(require 'agent-shell)
(require 'map)
(require 'seq)
(require 'agent-shell-bookmark-session)

(defvar-local agent-shell-bookmark--previous-maker nil
  "Local binding and record maker displaced while the addon is enabled.")
(defvar-local agent-shell-bookmark--installed nil
  "Whether this addon installed a bookmark record maker in this buffer.")

(defun agent-shell-bookmark--config (identifier)
  "Find exactly one configured agent with IDENTIFIER.
For example, IDENTIFIER can be the symbol `codex'."
  (let ((configs (seq-filter (lambda (config)
                               (eq identifier (map-elt config :identifier)))
                             agent-shell-agent-configs)))
    (unless (= (length configs) 1)
      (user-error "Configure exactly one agent named %s before restoring" identifier))
    (car configs)))

(defun agent-shell-bookmark-make-record ()
  "Return a bookmark for this shell's established conversation.
The record contains an agent identifier, directory and session ID only."
  (let ((session (agent-shell-session-id))
        (identifier (map-elt (agent-shell-get-config (current-buffer)) :identifier))
        (directory (directory-file-name (expand-file-name (agent-shell-cwd)))))
    (unless (and (stringp session) (not (string-empty-p session)))
      (user-error "Wait for a session before bookmarking this shell"))
    (unless (and identifier (symbolp identifier))
      (user-error "This agent needs a stable identifier before bookmarking"))
    (agent-shell-bookmark--config identifier)
    (when (file-remote-p directory)
      (user-error "Remote working directories are not supported yet"))
    `(,(format "%s: %s" identifier (buffer-name))
      (handler . agent-shell-bookmark-jump)
      (agent-shell-bookmark-version . 1)
      (agent-shell-bookmark-agent . ,identifier)
      (agent-shell-bookmark-directory . ,directory)
      (agent-shell-bookmark-session . ,session))))

(defun agent-shell-bookmark--read (record)
  "Validate RECORD and return its location as a keyword alist."
  (let ((version (bookmark-prop-get record 'agent-shell-bookmark-version))
        (agent (bookmark-prop-get record 'agent-shell-bookmark-agent))
        (directory (bookmark-prop-get record 'agent-shell-bookmark-directory))
        (session (bookmark-prop-get record 'agent-shell-bookmark-session)))
    (unless (and (eql version 1) agent (symbolp agent)
                 (stringp directory) (file-name-absolute-p directory)
                 (not (file-remote-p directory))
                 (stringp session) (not (string-empty-p session)))
      (user-error "Invalid or unsupported Agent Shell bookmark"))
    (unless (file-directory-p directory)
      (user-error "Working directory is unavailable: %s" directory))
    `((:agent . ,agent) (:directory . ,(directory-file-name (expand-file-name directory)))
      (:session . ,session))))

(defun agent-shell-bookmark--buffer (location)
  "Find a living or starting shell matching LOCATION."
  (seq-find
   (lambda (buffer)
     (with-current-buffer buffer
       (and (derived-mode-p 'agent-shell-mode)
            (eq (map-elt location :agent)
                (map-elt (agent-shell-get-config buffer) :identifier))
            (equal (map-elt location :directory)
                   (directory-file-name (expand-file-name (agent-shell-cwd))))
            (or (equal (map-elt location :session) (agent-shell-session-id))
                (and (eq agent-shell-bookmark-session--status 'starting)
                     (equal (map-elt location :session)
                            agent-shell-bookmark-session--target))))))
   (buffer-list)))

;;;###autoload
(defun agent-shell-bookmark-jump (record)
  "Restore RECORD's conversation for `bookmark-jump' or Activities.
Reuse a matching shell; otherwise start its exact saved session in background."
  (let ((origin (current-buffer)))
    (condition-case failure
        (let* ((location (agent-shell-bookmark--read record))
               (config (agent-shell-bookmark--config (map-elt location :agent)))
               (buffer (or (agent-shell-bookmark--buffer location)
                           (agent-shell-bookmark-session-start
                            :config config :directory (map-elt location :directory)
                            :session (map-elt location :session)))))
          ;; The bookmark caller owns display and Activities owns the layout.
          (set-buffer buffer))
      (error
       (set-buffer origin)
       (message "Agent Shell bookmark: %s" (error-message-string failure))))))

(defun agent-shell-bookmark--enable-buffer ()
  "Install the record maker in an `agent-shell' buffer."
  (when (and (derived-mode-p 'agent-shell-mode) (not agent-shell-bookmark--installed))
    (setq agent-shell-bookmark--previous-maker
          (list (cons :local (local-variable-p 'bookmark-make-record-function))
                (cons :value bookmark-make-record-function))
          agent-shell-bookmark--installed t)
    (setq-local bookmark-make-record-function #'agent-shell-bookmark-make-record)))

(defun agent-shell-bookmark--disable-buffer ()
  "Restore the previous record maker without replacing a newer integration."
  (when agent-shell-bookmark--installed
    (when (eq bookmark-make-record-function #'agent-shell-bookmark-make-record)
      (if (map-elt agent-shell-bookmark--previous-maker :local)
          (setq-local bookmark-make-record-function
                      (map-elt agent-shell-bookmark--previous-maker :value))
        (kill-local-variable 'bookmark-make-record-function)))
    (setq agent-shell-bookmark--installed nil)))

;;;###autoload
(define-minor-mode agent-shell-bookmark-mode
  "Save `agent-shell' conversations as standard Emacs bookmarks.
Enable globally with (agent-shell-bookmark-mode 1)."
  :global t :group 'agent-shell
  (if agent-shell-bookmark-mode
      (add-hook 'agent-shell-mode-hook #'agent-shell-bookmark--enable-buffer)
    (remove-hook 'agent-shell-mode-hook #'agent-shell-bookmark--enable-buffer))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (if agent-shell-bookmark-mode
          (agent-shell-bookmark--enable-buffer)
        (agent-shell-bookmark--disable-buffer)))))

(provide 'agent-shell-bookmark)
;;; agent-shell-bookmark.el ends here
