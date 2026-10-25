---
name: audit-parity
description: Audits a Ferro commit, branch, or diff against the Rust crate it binds, checking API completeness, fidelity, failure paths (panics above all), tests, packaging, and docs, and reports a verdict with a findings table (BUG, PARITY, TEST-GAP, DOC, NIT) citing file:line in the change and in the crate. Use when asked to review, audit, or verify a change to a Ferro gem, or before approving a binding.
---

<!-- SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com> -->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Audit a binding for crate parity

You are a reviewer, not the author. Read the change, then the crate it
binds, and report what is wrong. Do not fix anything unless asked.
AGENTS.md defines the precedence and the definition of done; ADR 001 holds
the translation table you audit against.

## 1. Scope the change

```sh
PAGER=cat git log --oneline <base>..<head>
PAGER=cat git diff --stat <base>..<head>
PAGER=cat git diff <base>..<head> -- gems
```

Read the plan the change executes (`doc/contributors/plan/`) and the ADRs it
cites. List every behavior the change adds or alters; each one gets checked.

## 2. Verify against the crate

Open the crate at the version the gem locks (`cargo metadata
--format-version 1` in the gem's directory gives its `manifest_path`), and
compare. Walk the crate's public API yourself and diff it against the
plan's table: a public item the table omits is a finding. Use
[references/parity-checklist.md](references/parity-checklist.md) for names,
messages, encodings, failure paths, concurrency, and docs. A citation that
does not say what the change claims is itself a finding.

Check the failure modes bindings have hit before:

- An input reachable from Ruby that panics the crate, or a call into the
  crate outside `catch_unwind`.
- An error variant without its own class, or a message not copied verbatim.
- A platform item defined everywhere, or a setting the native layer
  silently ignores on a platform that lacks it.
- A method declared in `sig/` that only an ancestor provides, or a test
  double standing in for the crate.
- A file the gem loads that `spec.files` misses, or a crate that only
  builds inside the repository.
- Crate-derived code or prose without an SPDX snippet and citation.
- A deviation not recorded in the plan and the RDoc or README.
- `unsafe` without a `SAFETY` comment citing its source, or without a test
  that fails when it is removed.
- Ruby API touched while the GVL is released, or a blocking call that holds
  it.
- Plan items silently skipped, or "done" without the clean-build gate.

## 3. Run the manual mutation check

Automated mutation testing does not exist yet. Do it by hand:

1. For each new or changed behavior, name the test that fails if the line is
   deleted or a key constant or branch changes. No such test is a TEST-GAP.
2. Spot-check a sample, at least one per changed file: revert or alter the
   line, run only the named test (`bundle exec rake test:<gem>
   N=/test_name/`, or `cargo test <name>` in the gem for Rust), confirm it
   fails, then restore the line and confirm `git diff` shows nothing you
   introduced.
3. Report each spot-check: the line, the mutation, the test, and whether it
   failed.

## 4. Run the gates

Run the clean-build gate from AGENTS.md. Report test counts, skips with
their reasons, and any error or warning. A gate you could not run is
UNVERIFIED.

## 5. Report

Give a verdict, a findings table, the mutation spot-checks, the gate
results, and what you could not verify. Order findings by severity. Each
finding cites `path:line` in the change and the crate `path:line` it
diverges from, and proposes a fix.

```markdown
**Verdict:** APPROVE | APPROVE WITH NITS | CHANGES REQUESTED | REJECT
<two or three sentences: is the binding faithful, and what matters most>

Sources read: <crate> <version>; magnus <version>; rb-sys <version>

| # | Severity | Where | Crate source | Finding | Fix |
|---|---|---|---|---|---|
| 1 | BUG | gems/arboard/ext/ferro_arboard/src/lib.rs:310 | src/platform/linux/mod.rs:30-46 | An empty image reaches the PNG encoder, which panics | Refuse it with ConversionFailure first |

Mutation spot-checks: | Line | Mutation | Test | Failed? |
Gates: clean build pass/fail, runs, assertions, failures, errors, skips, warnings
UNVERIFIED: <claim>: <why not checked> (<what would check it>)
```

| Severity | Meaning |
|---|---|
| BUG | Wrong behavior a user can hit: a panic, a hang, data loss, a broken install |
| PARITY | Differs from the crate without a documented, justified deviation, or omits a public item |
| TEST-GAP | Behavior no test would catch if deleted or mutated, or a test that exercises only a stub |
| DOC | RDoc, RBS, CHANGELOG, README, ADR, or plan is missing, wrong, or contradicts the crate's docs |
| NIT | Style or clarity; never blocks |

Mark anything you inferred but did not read or run as UNVERIFIED, and say
what would verify it.
