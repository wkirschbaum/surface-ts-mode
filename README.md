# Surface Major Mode using tree-sitter

Using [tree-sitter](https://tree-sitter.github.io/tree-sitter/) for font-lock, indentation, imenu and navigation.

## Installing

- Ensure you have tree-sitter 0.20.7 installed ( tree-sitter --version )
- Ensure you are using the latest `emacs-29` or `master` branch.
- You have to configure and compile emacs after you install tree-sitter
- Ensure you have heex-ts-mode loaded as it is a package dependency
- Clone this repository
- Add the following to your emacs config

```elisp
(load "[cloned wkirschbaum/surface-ts-mode]/surface-ts-mode.el")
```

Run `M-x surface-ts-install-grammar`

