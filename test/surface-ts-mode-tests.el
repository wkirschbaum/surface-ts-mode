(require 'ert)
(require 'ert-x)
(require 'treesit)

(ert-deftest surface-ts-mode-test-indentation ()
  (skip-unless (treesit-ready-p 'surface))
  (ert-test-erts-file (ert-resource-file "indent.erts")))

(ert-deftest surface-ts-mode-test-known-issues ()
  (skip-unless (treesit-ready-p 'surface))
  (ert-test-erts-file (ert-resource-file "known-issues.erts")))

(provide 'surface-ts-mode-tests)
