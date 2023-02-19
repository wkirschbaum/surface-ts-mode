;;; surface-ts-mode.el --- Major mode for Surface with tree-sitter support -*- lexical-binding: t; -*-

;; Copyright (C) 2022, 2023 Wilhelm H Kirschbaum

;; Author           : Wilhelm H Kirschbaum
;; Version          : 0.1
;; URL              : https://github.com/wkirschbaum/surface-ts-mode
;; Package-Requires : ((emacs "29") (heex-ts-mode "1.1"))
;; Created          : February 2023
;; Keywords         : surface elixir languages tree-sitter

;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.

;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package defines surface-ts-mode which is a major mode for editing
;; Surface UI files: https://surface-ui.org/.

;;; Code:

(require 'treesit)
(require 'heex-ts-mode)
(eval-when-compile (require 'rx))

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-node-child "treesit.c")
(declare-function treesit-node-type "treesit.c")
(declare-function treesit-install-language-grammar "treesit.el")

(defcustom surface-ts-mode-indent-offset 2
  "Indentation of Surface statements."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'surface)

(defvar surface-ts-mode-default-grammar-sources
  '((surface . ("https://github.com/wkirschbaum/tree-sitter-surface.git"))))

;; There seems to be no parent directive block
;; so we ignore it for until we learn how surface treesit
;; represents directive blocks
;; https://github.com/phoenixframework/tree-sitter-surface/issues/28
(defvar surface-ts-mode--indent-rules
  (let ((offset surface-ts-mode-indent-offset))
    `((surface
       ((parent-is "fragment")
        (lambda (node parent &rest _)
          ;; if surface is embedded indent to parent
          ;; otherwise indent to the bol
          (if (eq (treesit-language-at (point-min)) 'surface)
              (point-min)
            (save-excursion
              (goto-char (treesit-node-start parent))
              (back-to-indentation)
              (point))
            )) 0)
       ((node-is "end_tag") parent-bol 0)
       ((node-is "end_component") parent-bol 0)
       ((node-is "/>") parent-bol 0)
       ((node-is ">") parent-bol 0)
       ((parent-is "comment") prev-adaptive-prefix 0)
       ((parent-is "component") parent-bol ,offset)
       ((parent-is "tag") parent-bol ,offset)
       ((parent-is "start_tag") parent-bol ,offset)
       ((parent-is "component") parent-bol ,offset)
       ((parent-is "start_component") parent-bol ,offset)
       ((parent-is "self_closing_tag") parent-bol ,offset)
       (no-node parent-bol ,offset)))))

(defvar surface-ts-mode--font-lock-settings
  (when (treesit-available-p)
    (treesit-font-lock-rules
     :language 'surface
     :feature 'surface-comment
     '((comment) @font-lock-comment-face)
     :language 'surface
     :feature 'surface-tag
     `([(tag_name) (block_name)] @font-lock-function-name-face)
     :language 'surface
     :feature 'surface-attribute
     `((attribute_name) @font-lock-variable-name-face)
     :language 'surface
     :feature 'surface-string
     `([(attribute_value)] @font-lock-constant-face)))
  "Tree-sitter font-lock settings.")

(defun surface-ts-install-grammar ()
  "Experimental function to install the tree-sitter-surface grammar."
  (interactive)
  (if (and (treesit-available-p) (boundp 'treesit-language-source-alist))
      (let ((treesit-language-source-alist
             (append
              treesit-language-source-alist
              surface-ts-mode-default-grammar-sources)))
        (if (y-or-n-p
             (format
              (concat "The following language grammar repository which will be "
                      "downloaded and installed "
                      "%s, proceed?")
              (cadr (assoc 'surface treesit-language-source-alist))))
            (treesit-install-language-grammar 'surface)))
    (display-warning
     'treesit
     (concat "Cannot install grammar because"
             " "
             "tree-sitter library is not compiled with Emacs"))))

(defun surface-ts-mode-treesit-ready-p ()
  (let ((language-version 14))
    (and (treesit-ready-p 'surface)
         (if (< (treesit-language-abi-version 'surface) language-version)
             (progn
               (display-warning
                'treesit
                (format "Cannot activate tree-sitter for %s, because tree-sitter language version %s or later is required" "surface-ts-mode" language-version))
               nil)
           t))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sface\\'" . surface-ts-mode))

;;;###autoload
(define-derived-mode surface-ts-mode heex-ts-mode "Surface"
  "Major mode for editing Surface, powered by tree-sitter."
  :group 'surface

  (when (surface-ts-mode-treesit-ready-p)
    (treesit-parser-create 'surface)

    (setq-local treesit-font-lock-settings surface-ts-mode--font-lock-settings)

    (setq-local treesit-simple-indent-rules surface-ts-mode--indent-rules)

    (setq-local treesit-font-lock-feature-list
                '(( surface-comment surface-keyword surface-doctype )
                  ( surface-component surface-tag surface-attribute surface-string )
                  () ()))

    (treesit-major-mode-setup)))

(provide 'surface-ts-mode)
;;; surface-ts-mode.el ends here
