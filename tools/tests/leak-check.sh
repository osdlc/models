#!/bin/sh
# Checks that tools/leak-check.sh catches each kind of leak, passes a clean
# tree, and fails with exit 2 when it cannot scan.
#
# Each case copies the script into a fresh temporary root that holds small
# profiles/x/, profiles/claims/ and corpora/y/ folders, writes one file, and
# runs the copy there.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
script="$here/../leak-check.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failed=0
n=0

# check <name> <want exit> <want text> <file> <content>
# An empty <file> writes nothing. A <file> of `-corpora` removes corpora/.
check() {
  name=$1
  want_status=$2
  want_text=$3
  file=$4
  content=$5
  n=$((n + 1))
  root="$work/$n"
  mkdir -p "$root/tools" "$root/profiles/x" "$root/profiles/claims" "$root/corpora/y"
  cp "$script" "$root/tools/leak-check.sh"
  echo "A clean record." >"$root/profiles/x/README.md"
  echo "A clean record." >"$root/profiles/claims/README.md"
  echo "A clean record." >"$root/corpora/y/README.md"
  case $file in
    "") ;;
    -corpora) rm -rf "$root/corpora" ;;
    *) printf '%s\n' "$content" >"$root/$file" ;;
  esac

  status=0
  out=$(sh "$root/tools/leak-check.sh" 2>&1) || status=$?
  if [ "$status" -eq "$want_status" ] && printf '%s\n' "$out" | grep -qF "$want_text"; then
    echo "pass: $name"
  else
    echo "FAIL: $name: want exit $want_status and \"$want_text\", got exit $status:"
    printf '%s\n' "$out" | sed 's/^/  /'
    failed=1
  fi
}

check "clean tree" 0 "ok: no private data" "" ""
check "repo URL ending .git" 1 "leak (private repo)" profiles/x/package.json \
  '"url": "git+https://github.com/sksizer/dev.git"'
check "repo name ending a sentence" 1 "leak (private repo)" corpora/y/README.md \
  "See sksizer/dev."
check "repo name at end of line" 1 "leak (private repo)" corpora/y/README.md \
  "see sksizer/dev"
check "longer repo names are not the private repo" 0 "ok: no private data" profiles/x/README.md \
  "See sksizer/dev-tools and sksizer/devx."
check "macOS home path" 1 "leak (home path)" profiles/x/README.md \
  "Open /Users/someone/notes.md."
check "Linux home path" 1 "leak (home path)" corpora/y/README.md \
  "Open /home/someone/notes.md."
check "email address" 1 "leak (email address)" profiles/x/README.md \
  "Write to someone@example.com."
check "home-relative path in a profile" 1 "leak (home-relative path)" profiles/x/README.md \
  "Read ~/notes.md."
check "home-relative path in a corpus" 1 "leak (home-relative path)" corpora/y/README.md \
  "Read ~/notes.md."
check "home-relative path in profiles/claims/ is allowed" 0 "ok: no private data" profiles/claims/README.md \
  "The tool reads ~/.config/tool.toml."
check "a missing root is an error" 2 "could not scan" -corpora ""

if [ "$failed" -ne 0 ]; then
  echo "leak-check tests failed"
  exit 1
fi
echo "ok: $n leak-check cases"
