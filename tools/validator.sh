# shellcheck shell=sh disable=SC2154
# Sourced by scripts that run the validator, after they set $repo to the
# repository root.
#
# corpus_schema <subcommand> <args>... runs the corpus-schema bin that the root
# devDependency @osdlc/corpus-schema installs. Set CORPUS_SCHEMA to the
# command of another validator to run that one instead.
#
# validate <folder>... is corpus_schema validate.
corpus_schema() {
  if [ -n "${CORPUS_SCHEMA:-}" ]; then
    $CORPUS_SCHEMA "$@"
  elif [ -x "$repo/node_modules/.bin/corpus-schema" ]; then
    "$repo/node_modules/.bin/corpus-schema" "$@"
  else
    echo "corpus-schema is not installed: run pnpm install at the repository root" >&2
    return 2
  fi
}

validate() {
  corpus_schema validate "$@"
}
