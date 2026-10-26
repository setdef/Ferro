---
name: bind-crate
description: Binds a Rust crate's public API to a Ferro gem one to one, or changes an existing binding. Covers reading the crate at its exact version, enumerating its public API into the plan, the Rust-to-Ruby translation, test-first work against the real crate, panic and image-style guards, platform extensions, SPDX attribution, and the definition of done. Use when adding a gem under gems/, binding a new crate release, or changing what a gem exposes.
---

<!-- SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com> -->
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

# Bind a crate

AGENTS.md is the contract: design precedence, RBS and RDoc rules, commands,
changelog, and the definition of done. ADR 001 holds the translation table.
This skill is the workflow around them. Read both first, then
`doc/contributors/documentation_style.md` before writing prose.

## 1. Find the authority, never guess

| Source | Where |
|---|---|
| The crate you bind | Its latest release on crates.io. Add it to the gem's `Cargo.toml`, run `cargo metadata --format-version 1` in `gems/<name>`, and read the directory of the package's `manifest_path`. |
| magnus, rb-sys | The locked copies, found the same way. `pins:check` keeps every gem on the same ones. |
| The crate's dependencies | The locked copies again, when the crate's behavior depends on them (arboard's PNG encoder asserts its buffer length). |
| Ruby itself | The tag of the Ruby version you run (`gc.c` at `v4.0.1`, for example). |

Record every version you read. Cite `file:line` at that version for every
API you bind and every behavior you rely on. A claim you could not check is
marked UNVERIFIED, not stated as fact.

## 2. Enumerate before you design

List the crate's whole public API in the plan, from its source, not its
docs: every `pub` type, function, method, field, enum variant, trait and
trait method (platform traits included), every `#[cfg]` that gates one, and
every Cargo feature. Each row gets its citation, its Ruby counterpart, and a
status: bound, translated (say how), or deferred (say why). Nothing is left
off the list because it looked unimportant.

## 3. Translate, never port Rust machinery

Follow ADR 001's table. In short: names stay; `Result` raises; each error
variant is a class with the crate's `Display` text; `Option` is `nil`;
strings, bytes, and paths are Strings; public-field structs are
`Data.define`; builders hold their receiver; lifetimes, moves, and `Send`
bounds disappear; every feature is on; platform items exist only on their
platform. A case the table does not cover is a design decision: write it
into the plan with the precedence tier that justifies it, and into the RDoc
a user reads.

Keep the native layer thin. Ruby owns the public API, with RDoc and RBS;
Rust exposes the smallest set of private methods that reach the crate, each
citing the crate function it calls.

## 4. Test first, against the real crate

- Write the test, run it, and watch it fail for the reason you expect.
- Port the crate's own tests and examples. They are the answer key.
- Test against the real crate and the real system resource. When a test
  changes state the user owns (the clipboard, a keyring), save and restore
  it around the suite.
- A platform-only test skips elsewhere and says which platform it needs.
- For each behavior, name the test that fails if its line is reverted, and
  spot-check by reverting the line, running the test, and restoring it.
- Code Ruby cannot reach (panic capture, a pure conversion) gets a Rust
  unit test.

## 5. Guard the boundary

Work through [references/parity-checklist.md](references/parity-checklist.md).
Above all: no input reachable from Ruby may panic the crate, because magnus
turns a panic into Ruby's uncatchable `fatal`. Wrap every call into the
crate in `catch_unwind`, and refuse, with the crate's own error, any input
you know the crate panics on.

## 6. Attribute

Code or prose derived from the crate gets an SPDX snippet with the crate's
license and copyright line. Ruby files wrap the markers in `#--`/`#++`;
see `gems/arboard/lib/ferro/arboard/error.rb`.

## 7. Finish

- Signatures in `gems/<name>/sig/` for every public method; platform-only
  signatures in their own file, listed in the gem's `platform_sigs`
  (`tasks/ferro_gems.rb`) so `rbs:parity` skips them elsewhere.
- RDoc in Context-Problem-Solution form, citing the crate; no endless
  `def x = y`.
- A line in the gem's CHANGELOG for anything a user can observe.
- The gem's README and `arboard_version`-style metadata name the crate
  version. Every README carries the Certified Shovelware badge directly
  under its title: in RDoc,
  `{rdoc-image:https://justin.searls.co/img/shovelware.svg}[https://justin.searls.co/shovelware/]`.
- `bundle exec rake gate:<name>` while you work; the full gate before you
  hand off. Then walk the plan item by item and mark each done or
  deferred with a reason.
- Hand off with the commit-session skill.
- A new gem starts at `0.1.0.pre.1` with its entries under Unreleased.
  Its first release is `rake bump:<name>:current`, which releases that
  version rather than skipping to `pre.2`; then `rake release:<name>:tag`.

The mistakes that shaped these rules are in
[references/lessons.md](references/lessons.md). Skim it before designing.
