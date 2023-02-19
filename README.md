# Surface Major Mode using tree-sitter

Using [tree-sitter](https://tree-sitter.github.io/tree-sitter/) for font-lock, indentation, imenu and navigation.

This package is a dependency for and should be used with
[elixir-ts-mode](https://github.com/wkirschbaum/elixir-ts-mode) from where
you can find all the documentation and installation instructions.

## Installing

- Ensure you have tree-sitter 0.20.7 installed ( tree-sitter --version )
- Ensure you are using the latest `emacs-29` or `master` branch.
- You have to configure and compile emacs after you install tree-sitter
- Clone this repository
- Add the following to your emacs config

```elisp
(load "[cloned wkirschbaum/surface-ts-mode]/surface-ts-mode.el")
```

Run `M-x surface-ts-install-grammar`

