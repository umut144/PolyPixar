#!/bin/sh
set -eu

# Adapter that lets the check/checkt shell functions verify this repository.
#
#   ./scripts/check.sh            the full wrapper, as AGENTS.md requires
#   ./scripts/check.sh --tests    the same; the flag is accepted, not needed
#   ./scripts/check.sh tests      a single step, passed through to verify.sh
#
# Those functions find the Git root, run its scripts/check.sh, wait for it and
# write the whole output to a log file. They carry no project knowledge and
# call the script with --tests when they are invoked as checkt, so a repository
# joins that contract by answering to this path. The verification itself stays
# in tools/verify.sh, which also backs .github/workflows/verify.yml.
#
# Unlike sibling repositories this one offers no cheap tier. AGENTS.md is
# explicit that the editor parse is not the parser of record - it reported
# clean on a script with undeclared identifiers that the test run caught at
# once - so a default that skipped the suite would answer a question nobody
# asked. --tests therefore changes nothing: both spellings run all four steps.
# A deliberately narrower run is still available by naming steps, which are
# forwarded unchanged.

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_directory=$(dirname -- "$script_directory")
cd -- "$project_directory"

steps=""
for argument in "$@"; do
  case "$argument" in
    --tests) ;;
    -*)
      echo "usage: $0 [--tests] [step ...]" >&2
      exit 2
      ;;
    *) steps="${steps:+$steps }$argument" ;;
  esac
done

# Unquoted on purpose: empty means every step, otherwise one word per step.
# shellcheck disable=SC2086
exec tools/verify.sh $steps
