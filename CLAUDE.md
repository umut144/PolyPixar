# Claude project instructions

## Important first notice: limited internet data allowance

The developer is currently working with a limited internet data allowance.
Use external network access only when it is strictly necessary for the current
task and local repository files, installed dependencies, caches, and existing
documentation are insufficient. Keep the number of requests, transferred data,
and downloads to the absolute minimum. Ask for permission before any external
access that is not clearly essential.

## Project instructions

Before planning, discussing, or changing this project, read `AGENTS.md` in
full and follow all instructions and document-reading requirements defined
there. Treat `AGENTS.md` as the canonical source for project workflow, scope,
architecture, validation, and Git rules.

## Verification from the sandbox: the check watcher

This session cannot run `tools/verify.sh` itself. Instead of asking the
developer to run it by hand, it requests a run from the watcher that is
already running in a terminal tab:

```bash
./scripts/check-agent-run.sh            # the standard path
./scripts/check-agent-run.sh --tests    # additionally the test projects
./scripts/check-agent-run.sh --poll     # wait on a run already requested
./scripts/check-agent-run.sh --full     # the whole output instead of a tail
```

The runner takes only the arguments of its whitelist, `--tests` by default, so
the step names that check.sh forwards — `editor`, `smoke`, `tests`,
`whitespace` — are refused with exit code `2`. A deliberately narrow run
allows them for that one call:

```bash
CHECK_AGENT_ARGS='--tests editor smoke tests whitespace' \
  ./scripts/check-agent-run.sh tests
```

The three repositories share this script and the other two do not have these
step names, so the allowance stays per call and never becomes the default.
`./scripts/check-agent-run.sh --tests` remains the routine path; verify.sh
runs all four steps anyway, a failed one included.

Exit code `0` means the run succeeded and `1` that it failed, with check.sh's
own code in the `exit=` line of the header. `4` means the run is still going —
then call again with `--poll` rather than requesting a second one. `2` means
the call itself is wrong: `--poll` without an open request of this session, or
an argument outside `CHECK_AGENT_ARGS`. Fix the call, do not repeat it
unchanged. `5` means the request was dropped without a result, after a
watcher restart or because it sat too long: request a new run instead of
waiting for one that will never arrive. `3` means no watcher is running.

Exit code `3` always needs the developer: say plainly that the watcher is
off, ask them to type `checkw start` in a terminal tab, and wait for their
confirmation instead of falling back to "please run it by hand".

Beyond exit code 3, stop and ask the developer whenever the obstacle is not
yours to remove: the same request fails or is dropped three times in a row, a
run keeps polling far past its usual duration, or the failure names something
about the machine rather than the code — a missing toolchain, a full disk, a
binary that is gone. Say what you tried, what you saw, and what you need.
Changing code in response to a broken environment is worse than waiting.

The watcher answers below `.agent-check/`, which the .gitignore keeps out of
the repository. Every run is kept on its own there, so parallel sessions do
not disturb each other: `requests/<id>` is the request, `pending/<session>`
the id a session waits for, `results/<id>` the header — `id`, `exit`, `args`,
`duration`, `lines` — followed by the output, and `logs/<id>.log` the raw
output, which greps well. `result` and `last.log` still exist, but they are
only a copy of the most recently finished run, whoever asked for it; for the
result of this session's own run, rely on what the runner prints instead. Runs
the developer makes by hand stay separate as `manual-result` and `manual.log`;
look there for a result that already exists before asking for a new one.

`scripts/check-agent.sh` (the watcher) and `scripts/check-agent-run.sh` (the
runner for this session) are taken unchanged from world01 and carry no project
knowledge: they ask for the Git root and call `./scripts/check.sh`. They are
meant to stay identical in every repository, so do not change them.

The validation rules of AGENTS.md apply unchanged. The watcher is only the
transport; what counts as a pass is still decided there.

## Git from the sandbox: no optional locks

The sandbox cannot delete files, so a plain `git status` in this session leaves
a stale `.git/index.lock` behind that blocks the developer's next Git command.
Always use `git --no-optional-locks ...` for read-only Git commands from here
(`status`, `diff --stat`, `grep`); it refreshes nothing and leaves no lock.

Never move or delete anything below `.git/` by hand; the `_to_delete/` rule
below does not reach in there. A lock that a running Git still holds belongs
to it, and taking it away destroys its commit. If a Git command fails on a
lock, run `./scripts/git-unlock.sh`; if it refuses, say so and ask.

Run `GIT_UNLOCK_AGE=5 ./scripts/git-unlock.sh` after each of your own commits,
not only after a Git command has already failed on a lock: every commit leaves
locks and temp objects behind that this session cannot delete, and they block
whoever commits next. The script's own default is 15 seconds; 5 is enough at
this call site because `lsof` is the real check and the age is only its
fallback, and a loosened margin belongs where it can be read rather than in the
default. If the script refuses because the leftovers are still too young, wait
a moment and run it again; if it still refuses, say so and ask.

## Deleting files from the sandbox

This session cannot delete files. When a change requires removing a file, move
it into `_to_delete/` at the repository root instead. Do this silently: do not
ask first, and do not report it afterwards. The developer empties that folder
when the day's work is done.

Commit the change as usual, but never stage `_to_delete/` itself. It stays
untracked on purpose, so that the folder appears in the developer's `git
status` at the end of the day while nothing of it reaches the history.

Never read, search, or reference anything below `_to_delete/`. Its contents are
discarded work; treat the folder as if it were empty.

The empty `.gdignore` in that folder keeps the Godot editor from importing what
is parked there. Leave it in place.
