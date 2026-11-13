---
name: commit-session
description: Commits a finished step of Ferro work on trunk and pushes it - checks the definition of done, makes a scoped Conventional Commit, lets the pre-push hook run the gate on exactly that commit, and stops short of tagging or releasing. Use when a step is done and the user wants it committed or pushed, or asks to wrap up, finish, or land the work.
---

<!-- SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com> -->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Commit and push a step

AGENTS.md ("Committing", "Changelog", "Definition of done") sets the rules:
small, complete commits on `trunk`, no transcript, scoped Conventional
Commits with a prose body and the AI footer, the gate before every push,
never a force-push. Releases and tags have their own rake tasks and rules
there. Follow them; this skill is the order of operations. If your
instructions say an orchestrator commits, stop after step 1 and hand over
the message instead.

## 1. Check the definition of done

Walk the step's plan item by item. Each is done, or deferred with a
written reason in the plan. Confirm each touched gem's CHANGELOG, RDoc,
RBS, and README cover every change a user can observe. Run the tests the
change touches (`bundle exec rake gate:<name>` for one gem), and
`bundle exec rake rubocop:autocorrect`.

## 2. Commit

```sh
git add -A                       # rake tasks and gemspecs read git ls-files
PAGER=cat git status
PAGER=cat git diff --cached --stat
git commit -F <message file>
```

The message: a scoped Conventional Commits subject (`feat(arboard): ...`
for one gem, no scope for repository-wide work), a blank line, then a body
wrapped at 72 columns that explains in prose why this approach beat the
alternatives. No lists, no Markdown, no file inventory. End with the AI
footer AGENTS.md spells out ("Committing").

## 3. Push through the gate

For the clean build the definition of done asks for, remove build output
first:

```sh
rm -rf tmp target gems/*/tmp gems/*/target
find gems \( -name '*.bundle' -o -name '*.so' -o -name '*.dll' \) -delete
```

Then sync and push the commit you have checked out, which is `trunk` in
the main clone and a branch of its own in a worktree:

```sh
git fetch origin && git rebase origin/trunk
git push origin HEAD:trunk
```

The pre-push hook (`.githooks/pre-push`, which `bin/setup` installs) runs
the gate, `bundle exec rake`, on that commit. It refuses the push while
anything is uncommitted or untracked, since the gate would test it. The
gate passes with zero errors and zero warnings, or nothing is pushed: fix
the cause, commit, and push again. Never pass `--no-verify`. If a gemspec,
a `Cargo.toml`, or an `extconf.rb` changed, run `bundle exec rake
package:install` before the push too.

## 4. Stop

Do not tag or release unless AGENTS.md's release rules say you may. Report
the commit hash, the gate's counts and skips, and anything deferred. CI
runs the gate on the systems yours is not; if it turns `trunk` red, fixing
or reverting that commit comes before any other work.
