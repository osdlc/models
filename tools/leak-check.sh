#!/bin/sh
# Fails when a package folder holds private data. The profiles and corpora
# ship to a public registry, and some of their content is carried over from
# private repos.
#
# It looks for:
#
# - a link or path into the private repo sksizer/dev;
# - an absolute home path, /Users/<name> or /home/<name>;
# - an email address;
# - a ~/ path, except in profiles/claims/, whose example is about the config
#   paths of a made-up tool under ~/.
#
# A link to a record the corpus does not hold is the validator's check, not
# this one.
#
# usage: sh tools/leak-check.sh
set -eu
cd "$(dirname "$0")/.."

failed=0
# scan <what> <extended regex> <path>...
scan() {
  what=$1
  pattern=$2
  shift 2
  if hits=$(grep -rnIE --exclude-dir=node_modules "$pattern" "$@"); then
    printf '%s\n' "$hits" | sed "s|^|leak ($what): |"
    failed=1
  fi
}

scan "private repo" 'sksizer/dev([^a-zA-Z0-9_.-]|$)' profiles corpora
scan "home path" '/(Users|home)/[A-Za-z0-9_.-]+' profiles corpora
scan "email address" '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' profiles corpora
tilde=corpora
for dir in profiles/*/; do
  [ "$dir" = profiles/claims/ ] || tilde="$tilde ${dir%/}"
done
# $tilde is a list of folders without spaces, so it is left unquoted.
# shellcheck disable=SC2086
scan "home-relative path" '(^|[^A-Za-z0-9_])~/' $tilde

if [ "$failed" -ne 0 ]; then
  echo "::error::private data in a package folder; remove it before publishing"
  exit 1
fi
echo "ok: no private data in profiles/ or corpora/"
