<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# AGENTS.md

## Project

Ferro is a repository of Ruby gems (Ruby >= 4.0) that bind Rust crates one to one: `ferro-arboard` binds arboard, and more follow. Each gem lives in `gems/<name>/` with its own gemspec, Cargo workspace, tests, CHANGELOG, and version. A gem adds no Ruby-isms and no functionality its crate lacks. Rust (rb-sys + magnus) is a thin native layer; the public API is Ruby, with RDoc and RBS. Ferro spun out of Tokra, a Ruby port of Tauri whose plugins build on these gems. ADR 001 (`doc/contributors/adr/001.md`) records the decisions behind all of this.

Pre-1.0, zero external users. Prefer good design over backward compatibility; record every breaking change in the gem's CHANGELOG.

## Design precedence

1. **Ruby the language.** What Ruby can and cannot express. Rust constructs with no Ruby meaning (lifetimes, moves, `Send` and `Sync` bounds, Cargo features) are translated, not ported. Every Cargo feature is simply on.
2. **Crate fidelity.** Names, types, error variants and their `Display` text, platform gating, and behavior MUST match the crate's source at the bound version. Do not invent "more Ruby-like" APIs.
3. **Ruby culture.** Idioms yield to 1 and 2.

ADR 001's translation table is the rulebook: `Result` raises, each error variant is a class, `Option` is `nil`, bytes are binary Strings, public-field structs are `Data.define`, builders hold their receiver, platform items exist only on their platform. A case the table does not cover is a design decision: write it in the plan and in the RDoc a user reads.

The authority is the crate's source at the version the gem's `Cargo.lock` pins. Run `cargo metadata --format-version 1` in `gems/<name>` and read the directory of the crate's `manifest_path`; the same goes for magnus, rb-sys, and any dependency whose behavior matters. Bind a crate's latest release. Never guess at a source's contents. Cite the file and lines you bind, and add an SPDX snippet with the crate's license and copyright line around any code or prose derived from it.

## How to work

- Research before designing: read the crate at its exact version and ADR 001 first. Enumerate the crate's whole public API into the plan, each item bound, translated, or deferred with a reason.
- Root-cause every fix. If you cannot explain why a change fixed the symptom, it is not a fix.
- Write tests first, against the real crate and the real system resource, never a stub. A test must fail if the code it covers is deleted or mutated. Port the crate's own tests and examples. Save and restore user state (the clipboard's text) around a suite that changes it.
- No input reachable from Ruby may panic the crate: magnus turns a panic into Ruby's uncatchable `fatal`. Run every crate call under `catch_unwind`, and refuse known panicking inputs with the crate's own error.
- Each `unsafe` block beyond what magnus wrapping generates (such as `rb_ext_ractor_safe` or releasing the GVL) carries a `// SAFETY:` comment citing the Ruby, rb-sys, or crate source that justifies it, an `#[allow(unsafe_code)]` scoped to that block, and a test that fails if the block is removed. A new dependency needs a stated reason in the plan.
- Design in the spirit of Kent Beck (small steps, Implementation Patterns), Freeman & Pryce (tests drive interfaces), Sandi Metz (duplication over the wrong abstraction), Rebecca Wirfs-Brock (responsibility-driven roles), Martin Fowler (refactor in behavior-preserving steps), and Matz (programmer happiness). Write prose in the style of `doc/contributors/documentation_style.md`.
- Skills in `.agents/skills/` hold the detailed workflows: `bind-crate` before binding or changing a gem, `audit-parity` before approving a diff, `commit-session` to finish a session. Mutation testing is not automated yet, so reviewers check by hand that each changed behavior has a test that fails when its code is reverted.

## Ruby, RBS, and docs

- `Data.define` for value objects (`class Foo < Data.define(...)`), `class` for entities.
- Every Ruby method has an RBS signature in the gem's `sig/`, mirroring `lib/`. No `untyped`, and no comments in `.rbs` beyond the SPDX header. For `Data.define` classes, declare `self.new` instead of `initialize`; plain classes declare `initialize` as usual. Signatures for one platform's API go in their own file, listed in the gem's `platform_sigs` in `tasks/ferro_gems.rb`.
- RDoc (never YARD) in `.rb` files only, complete for every public class, module, method, attribute, and constant. Wrap SPDX headers in `#--` / `#++`. No endless methods in `lib/`.
- Architectural decisions get an ADR in `doc/contributors/adr/`; plans live in `doc/contributors/plan/`, written before the code.

## Commands

- Run Ruby with `bundle exec ruby`. Run tests with `bundle exec rake test`, or one gem's with `bundle exec rake test:<name>`. Never `ruby -Ilib:test`.
- `bundle exec rake` is the gate, across every gem: tests (tooling, Rust, Ruby), RuboCop, Steep, RBS validation and parity, RDoc coverage, REUSE, Clippy, rustfmt, the magnus and rb-sys pin check, and a packaging check that loads each built gem outside the repository. It must pass with zero errors and zero warnings; every cargo step, the extension compile included, fails on any rustc, Clippy, or Cargo warning. `bundle exec rake gate:<name>` runs one gem's checks while you work. Run `bundle exec rake rubocop:autocorrect` first to save time.
- Approved exceptions live in `rbs_exceptions.rb` and `clippy_exceptions.rb`; adding one needs a justification that it is impossible otherwise.
- Each gem is its own Cargo workspace with a committed `Cargo.lock`, built with `--locked`. During development every gem compiles into the shared `target/` directory. After changing a gemspec, `Cargo.toml`, or `extconf.rb`, and before any release, also run `bundle exec rake package:install`, which compiles every gem from its packaged sources.
- Rake tasks and gemspecs use `git ls-files`: new or deleted files must be staged (`git add -N` will do) before they count.
- Always `PAGER=cat` for git.

## Committing

- One commit per working session, on `trunk`, after the gate passes. Never push, tag, or release; `rake release:<name>` is for the maintainer alone.
- Include any plan or ADR the session produced. Never commit session transcripts.
- Scoped Conventional Commits, plain text, wrapped at 72: `feat(arboard): ...` for one gem, no scope for repository-wide work, so `git log -- gems/<name>` reads as that gem's history. The body explains why this approach over alternatives, in prose (no lists, no markdown, no file inventories). Types: gem code feat/fix/refactor/perf; `tasks/`, the Rakefile, and CI chore; `doc/` and READMEs docs; tests test. End with the AI footer, after a blank line:

  ```
  Generated with Claude Code (https://claude.com/claude-code)

  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```

  (or the agent and model that did the work).

## Changelog

Each gem keeps its own `CHANGELOG.md`: Keep a Changelog + SemVer, versioned by the gem's own API, not the crate's. Only changes users of that gem can observe: public APIs, behavior, breaking changes, deprecations, dependency changes (including the bound crate version). Not tests, docs, internal refactors, or tooling. Terse one-line entries under `## [Unreleased]`, which means "since the gem's last tag": a change undone before the next tag removes its entry instead of adding a "Fixed" line. Never edit released sections.

## Definition of done

1. Every item in the plan is done, or explicitly deferred with a reason.
2. The binding matches the cited crate source; deviations are justified by the precedence above and documented.
3. `bundle exec rake` passes from a clean build (`rm -rf tmp target`), zero errors, zero warnings.
4. RDoc, RBS, `doc/`, the gem's README, and its CHANGELOG are updated where behavior changed. The README and gemspec metadata name the bound crate version.
5. A commit message is written (and the commit made, per Committing).
