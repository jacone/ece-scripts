#! /usr/bin/env bash

# by tkj@vizrt.com

handbook_org=vosa-handbook.org

$(which blockdiag >/dev/null) || {
  cat <<EOF
You must have blockdiag installed. On Debian & Ubuntu the package is
called python-blockdiag
EOF
  exit 1
}

# generate the diagram
for el in graphics/*.blockdiag; do
  echo "Generating PNG of $el ..."
  blockdiag $el
done

# use emacs to generate HTML from the ORG files
echo "Generating new handbook HTML from ORG ..." 
emacs --batch --visit $handbook_org \
  --funcall org-export-as-html-batch 2>/dev/null || {
  cat <<EOF
You must have Emacs 24 + org mode from git to use this export
function.
EOF
  exit 1
}

echo "$(basename $handbook_org .org).html is now ready"



