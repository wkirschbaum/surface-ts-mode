;;; surface-ts-mode.el --- Major mode for Surface with tree-sitter support -*- lexical-binding: t; -*-

;; Copyright (C) 2022, 2023 Wilhelm H Kirschbaum

;; Author           : Wilhelm H Kirschbaum
;; Version          : 0.1
;; URL              : https://github.com/wkirschbaum/surface-ts-mode
;; Package-Requires : ((emacs "29"))
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
;; Elixir and Surface files.

;;; Code:

(require 'treesit)
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

(defconst surface-ts-mode--brackets
  '("%>" "--%>" "-->" "/>" "<!" "<!--" "<" "<%!--" "<%" "<%#"
    "<%%=" "<%=" "</" "</:" "<:" ">" "{" "}"))

(defconst surface-ts-mode-sexp-regexp
  (rx bol
      (or "directive" "tag" "component" "slot"
          "attribute" "attribute_value" "quoted_attribute_value")
      eol))

(defconst surface-ts-mode--brackets-vector
  (apply #'vector surface-ts-mode--brackets))

(defvar surface-ts-mode-default-grammar-sources
  '((surface . ("https://github.com/connorlay/tree-sitter-surface.git"))))

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
       ((node-is "end_slot") parent-bol 0)
       ((node-is "/>") parent-bol 0)
       ((node-is ">") parent-bol 0)
       ((parent-is "comment") prev-adaptive-prefix 0)
       ((parent-is "component") parent-bol ,offset)
       ((parent-is "tag") parent-bol ,offset)
       ((parent-is "start_tag") parent-bol ,offset)
       ((parent-is "component") parent-bol ,offset)
       ((parent-is "start_component") parent-bol ,offset)
       ((parent-is "slot") parent-bol ,offset)
       ((parent-is "start_slot") parent-bol ,offset)
       ((parent-is "self_closing_tag") parent-bol ,offset)
       (no-node parent-bol ,offset)))))

(defvar surface-ts-mode--font-lock-settings
  (when (treesit-available-p)
    (treesit-font-lock-rules
     :language 'surface
     :feature 'surface-comment
     '((comment) @font-lock-comment-face)
     :language 'surface
     :feature 'surface-doctype
     '((doctype) @font-lock-doc-face)
     :language 'surface
     :feature 'surface-tag
     `([(tag_name) (slot_name)] @font-lock-function-name-face)
     :language 'surface
     :feature 'surface-attribute
     `((attribute_name) @font-lock-variable-name-face)
     :language 'surface
     :feature 'surface-keyword
     `((special_attribute_name) @font-lock-keyword-face)
     :language 'surface
     :feature 'surface-string
     `([(attribute_value) (quoted_attribute_value)] @font-lock-constant-face)
     :language 'surface
     :feature 'surface-component
     `([
        (component_name) @font-lock-function-name-face
        (module) @font-lock-keyword-face
        (function) @font-lock-keyword-face
        "." @font-lock-keyword-face
        ])))
  "Tree-sitter font-lock settings.")

(defun surface-ts-mode--comment-region (beg end &optional _arg)
  "Comments the region between BEG and END."
  (save-excursion
    (goto-char beg)
    (insert comment-start " ")
    (goto-char end)
    (goto-char (pos-eol))
    (forward-comment (- (point-max)))
    (insert " " comment-end)))

(defun surface-ts-mode--defun-name (node)
  "Return the name of the defun NODE.
Return nil if NODE is not a defun node or doesn't have a name."
  (pcase (treesit-node-type node)
    ((or "component" "slot" "tag")
     (string-trim
      (treesit-node-text
       (treesit-node-child (treesit-node-child node 0) 1) nil)))
    (_ nil)))

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

(defun surface-ts-mode--forward-sexp (&optional arg)
  (interactive "^p")
  (or arg (setq arg 1))
  (funcall
   (if (> arg 0) #'treesit-end-of-thing #'treesit-beginning-of-thing)
   surface-ts-mode-sexp-regexp
   (abs arg)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sface\\'" . surface-ts-mode))

;;;###autoload
(define-derived-mode surface-ts-mode html-mode "Surface"
  "Major mode for editing Surface, powered by tree-sitter."
  :group 'surface

  (when (surface-ts-mode-treesit-ready-p)
    (treesit-parser-create 'surface)

    ;; Comments
    (setq-local treesit-text-type-regexp
                (regexp-opt '("comment" "text")))

    (setq-local forward-sexp-function #'surface-ts-mode--forward-sexp)

    ;; Navigation.
    (setq-local treesit-defun-type-regexp
                (rx bol (or "component" "tag" "slot") eol))
    (setq-local treesit-defun-name-function #'surface-ts-mode--defun-name)

    ;; Imenu
    (setq-local treesit-simple-imenu-settings
                '(("Component" "\\`component\\'" nil nil)
                  ("Slot" "\\`slot\\'" nil nil)
                  ("Tag" "\\`tag\\'" nil nil)))

    (setq-local treesit-font-lock-settings surface-ts-mode--font-lock-settings)

    (setq-local treesit-simple-indent-rules surface-ts-mode--indent-rules)

    (setq-local treesit-font-lock-feature-list
                '(( surface-comment surface-keyword surface-doctype )
                  ( surface-component surface-tag surface-attribute surface-string )
                  () ()))

    (treesit-major-mode-setup)))

(provide 'surface-ts-mode)
;;; surface-ts-mode.el ends here
