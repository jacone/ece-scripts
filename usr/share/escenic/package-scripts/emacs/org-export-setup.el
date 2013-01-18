(setq load-path
      (append (list "~/.emacs.d/org-7.9.3d/lisp"
                    "~/.emacs.d/org-7.9.3d/contrib/lisp")
              load-path))
(require 'org)
(require 'org-export)
(require 'org-e-man)
