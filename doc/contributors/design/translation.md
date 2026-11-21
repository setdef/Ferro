<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Translating a Crate to Ruby

A Ferro gem mirrors its crate one to one ([ADR 001](../adr/001.md)).
Fidelity to the crate comes first, then what Ruby the language can
express, then Ruby culture, as AGENTS.md's design precedence orders them.
A gem differs from its crate only where Ruby cannot do what Rust does:
Rust constructs with no Ruby meaning are translated, never ported. This document holds the
translations every gem makes, so that each gem makes them the same way.

The first table rows came with ADR 001 on 2026-10-24. The maintainer
settled the rows from `Display` to hidden items on 2026-11-05, after plan
011's audit found gems translating them differently. The rows from tuple
variants on follow from the precedence as it reads, and were recorded the
same day. The error rule was recorded on 2026-11-05 as well.

## The table

| Rust | Ruby |
|---|---|
| crate `arboard` | gem `ferro-arboard`, `require "ferro/arboard"`, module `Ferro::Arboard` |
| crate with a hyphen, `notify-rust` | gem `ferro-notify-rust`, `require "ferro/notify_rust"`, module `Ferro::NotifyRust`: the require path and module follow Cargo's library name, `notify_rust`, not RubyGems' hyphen-to-slash habit, which would invent a nesting the crate lacks ([plan 003](../plan/003.md)) |
| type, method, and variant names | kept: `Clipboard#get_text`, `ImageData`, `Error::ContentNotAvailable` |
| `Result<T, E>` | returns `T`, or raises |
| an error enum | an exception class per variant under the crate's `Error < StandardError`, with the crate's `Display` text as the message |
| `Option<T>` | `T` or `nil` |
| `String`, `&str`, `Cow<str>`, `impl Into<Cow<str>>` | `String` |
| `Vec<u8>`, `&[u8]`, `Cow<[u8]>` | binary `String` |
| `PathBuf`, `&Path`, `impl AsRef<Path>` | `String` |
| a struct with public fields | `Data.define` |
| a borrowing builder (`clipboard.get().text()`) | an object that holds its clipboard: `clipboard.get.text` |
| lifetimes, `Send`/`Sync` bounds | dropped; documented where they change behavior |
| a Cargo feature | built in when Ruby reaches it; dropped when only Rust can; offered at install, by Cargo's own `--features` and `--no-default-features`, when it changes behavior, excludes another, or needs what not every machine has ([cargo-features.md](cargo-features.md); offering is not built yet) |
| an item a Cargo feature gates | defined only when that feature is built; `FEATURES` names the built ones |
| a `#[cfg(target_os)]` item or platform trait | defined only on that platform, so `respond_to?` answers |
| `Display` | `to_s` |
| `Debug` | `debug`, which answers the crate's `Debug` text exactly, formatted by Rust so it cannot drift; `inspect` stays Ruby's, naming the class, because Rubyists rely on what `inspect` shows |
| a method that consumes `self` | a block form wherever Rust ties something to the end of a scope, as `File.open` takes a block, and without a block a consumed value raises on further use, as a closed `IO` does |
| a method returning `impl Iterator`, or an iterator type | an `Enumerator`, or a class with Rust's `next` (+nil+ at the end, by the `Option` row), `each`, and `Enumerable`; never an `Array`, which loses laziness and cannot hold an endless iterator |
| std's `Duration` | in, any `Numeric` number of seconds; out, a `Rational` number of seconds, exact to the nanosecond, as Ruby's own `Time#subsec` and `Time#to_r` are; never `ActiveSupport::Duration`, whose calendar arithmetic is not a `Duration`'s and whose gem a non-Rails app should not need |
| an item `#[doc(hidden)]` or `#[deprecated]` | not part of the gem's API, and unbound, unless Tauri needs it, so Tokra does; then bound, marked `:nodoc:` and deprecated in RDoc |
| a tuple variant's fields (`AlreadyRegistered(HotKey)`) | positional, as Rust leaves them: `deconstruct` and `to_a`, so `in AlreadyRegistered[hotkey]` reads as Rust's pattern does; no reader names the crate does not give |
| a fieldless enum's integer value (`Urgency::Low as u8`) | `to_i`, Ruby's own conversion to an Integer, since Rust's `as` has no name to keep |
| an extension trait on a type the crate does not own (time's `ext::NumericalDuration`) | a refinement of the Ruby class, in a module named for the trait, brought into scope with `using` as Rust's is with `use`; nothing outside that scope changes |
| an error type the crate re-exports from another crate's tree (notify-rust's `MacOsError`) | the crate's own tree of classes, as the error row above makes it, not folded into a neighbor's |

The crate's rustdoc, examples, and tests are the answer key. Tests run
against the real crate, never a stub. A case the table does not cover is a
design decision: write it in the gem's plan and in the RDoc a user reads.

## The error rule

Errors a gem raises where its crate would not follow one rule. A crate's
error classes are raised only for what the crate returns. An input the
crate would panic on is refused first, as AGENTS.md requires, with the
crate's own variant, or with `ArgumentError` or `RangeError` and the
panic's text verbatim, each pinned by a Rust test that drives the real
panic; any other caught panic raises the gem's base `Error` as "<crate>
panicked: ...". A breach of Ruby's own rules (a wrong type, a missing
block, a frozen receiver, a consumed value, allocation) raises the
built-in class Ruby itself raises for it, never a crate class. The gem's
own machinery is not a source of errors: it waits rather than refuses, as
Ruby's `Mutex` makes a second thread wait, never runs blocking work with
the GVL held, and falls back to the crate's own behavior when a helper
cannot start. Where a wait could never finish, such as a thread re-entering
work it already holds, the gem raises the built-in Ruby raises for that
(`ThreadError`), documented and tested. Each gem's plan records its own
cases.

One kind of call stands outside "never runs blocking work with the GVL
held": a crate's run loop that calls back into Ruby, as tao's
`EventLoop::run` does. Such a loop keeps the GVL, and hands it to the Ruby
threads waiting for it once in each turn, so what the rule is for still
holds: other threads run while the loop waits. Releasing the GVL around
the loop and taking it back for each callback is not sound, for the
reasons Tokra's
[ADR 012](https://github.com/setdef/Tokra/blob/trunk/doc/contributors/adr/012.md)
records. That record moves to Ferro with the code it describes.

## Platform items

The native layer reports the platform it was built for, so the Ruby side
defines a platform trait's module exactly where the crate compiles the
trait, as the table's `#[cfg(target_os)]` row has it.

## Ractors

Ferro owns no Ractor design. A gem exposes the crate's types as plain Ruby
objects. It marks the extension Ractor-safe only where the crate's types
allow calls from any thread, and it freezes and shares objects only where
the crate's types are `Sync`. Tokra's Ractor rules stay in Tokra's
plugins, which decide where a Ferro object lives. `unsafe` beyond what
magnus wrapping needs, such as marking an extension Ractor-safe or
releasing the GVL, carries what AGENTS.md asks of it.

## Ruby's `Time` and `Date`

ferro-time binds the time crate, whose module is `Ferro::Time` and which
holds its own `Ferro::Time::Date` ([plan 007](../plan/007.md)). Every
Ferro gemspec loads its `version.rb`, so wherever ferro-time is in a
bundle, `Ferro::Time` exists, and a bare `Time` written anywhere inside
`module Ferro` names it instead of Ruby's class.

So code inside `module Ferro`, in every gem but ferro-time, writes `::Time`
and `::Date` for Ruby's classes, in `lib/` and in `sig/` alike; ferro-time's
own `Time` and `Date` are the crate's types and stay bare there. RuboCop's
`Lint/ConstantResolution`, limited to `Time` and `Date` and to
`gems/*/lib` outside ferro-time, refuses a bare one in Ruby, and a tooling
test (`test/tasks/test_top_level_constants.rb`) refuses one in the
signatures, which RuboCop does not read. A later gem whose module name
shadows another core constant adds that name to both.
