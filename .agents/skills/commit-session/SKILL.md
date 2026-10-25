---
name: commit-session
description: Finishes a Ferro working session - runs the clean-build gate, stages the work, and makes the single scoped Conventional Commit AGENTS.md asks for, without pushing. Use when the work is done and the user wants it committed, or asks to wrap up, finish, or commit the session.
---

<!-- SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com> -->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Commit a session

AGENTS.md ("Committing", "Changelog", "Definition of done") sets the rules:
one commit per session on `trunk`, no transcript, scoped Conventional
Commits with a prose body and the AI footer, never push, tag, or release.
Follow them; this skill is the order of operations. If your instructions
say an orchestrator commits, stop after step 2 and hand over the message
instead.

## 1. Check the definition of done

Walk the session's plan item by item. Each is done, or deferred with a
written reason in the plan. Confirm each touched gem's CHANGELOG, RDoc,
RBS, and README cover every change a user can observe.

## 2. Run the clean-build gate

Remove build output and run the full gate. If a gemspec, a `Cargo.toml`,
or an `extconf.rb` changed, also run `bundle exec rake package:install`.

```sh
bundle exec rake rubocop:autocorrect
git add -N <new files>        # rake tasks and gemspecs read git ls-files
rm -rf tmp target gems/*/tmp
find gems -name '*.bundle' -delete
bundle exec rake
```

It passes with zero errors and zero warnings, or you do not commit. Note
the test counts and skips for the report.

## 3. Stage and commit

```sh
git add -A
PAGER=cat git status
PAGER=cat git diff --cached --stat
git commit -F <message file>
```

The message: a scoped Conventional Commits subject (`feat(arboard): ...`
for one gem, no scope for repository-wide work), a blank line, then a body
wrapped at 72 columns that explains in prose why this approach beat the
alternatives. No lists, no Markdown, no file inventory. End with the AI
footer AGENTS.md spells out ("Committing").

## 4. Stop

Do not push, tag, or release. Report the commit hash, the gate's counts,
and anything deferred.
