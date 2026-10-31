;;; check.el --- Isolated checks -*- lexical-binding: t; -*-
(require 'bytecomp)
(require 'checkdoc)
(require 'cl-lib)
(require 'package-lint)
(require 'lisp-mnt)
;; Give the offline linter metadata from the dependency we actually load.
(with-temp-buffer
  (insert-file-contents (locate-library "agent-shell"))
  (setq package-alist
        (list (cons 'agent-shell
                    (list (package-desc-create :name 'agent-shell
                                               :version (version-to-list (lm-version))))))))
(setq load-prefer-newer t byte-compile-error-on-warn t)
(let ((output (make-temp-file "asb-bytecode-" t)))
  (unwind-protect
      (dolist (file '("agent-shell-bookmark-session.el" "agent-shell-bookmark.el"))
        (with-temp-buffer
          (insert-file-contents file)
          (emacs-lisp-mode)
          (check-parens))
        (let ((byte-compile-dest-file-function
               (lambda (source) (expand-file-name (concat (file-name-base source) ".elc") output))))
          (unless (byte-compile-file file) (error "Compilation failed: %s" file)))
        (cl-letf (((symbol-function 'display-warning)
                   (lambda (&rest warning) (error "Checkdoc: %S" warning))))
          (checkdoc-file file))
        (with-temp-buffer
          (insert-file-contents file)
          (setq buffer-file-name (expand-file-name file))
          (emacs-lisp-mode)
          (let ((package-lint-main-file (expand-file-name "agent-shell-bookmark.el")))
            (when-let* ((warnings (package-lint-buffer)))
              (error "Package lint: %S" warnings)))))
    (delete-directory output t)))
(load "tests/agent-shell-bookmark-tests.el" nil t)
(load "tests/integration-tests.el" nil t)
(ert-run-tests-batch-and-exit "^asb-")
