<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Parity checklist

Check each row against the cited crate source and write the citation into
the plan's API table.

## Names and shape

- Type, method, field, and variant names match the crate's
  (`get_text`, not `text`; `Error::ContentNotAvailable`, not `EmptyError`).
- Every public item at the bound version appears in the plan: bound,
  translated, or deferred with a reason.
- Arity follows the crate: an `Option<T>` parameter is still a parameter,
  passed `nil`, not a default the crate lacks.
- Builders hold their receiver (`clipboard.get.text`); options return the
  builder; the terminal method does the work.
- Rust machinery is translated, not ported: lifetimes, moves, `Send`,
  `Sync`, and Cargo features have no Ruby API. Every feature is on.
- A platform item (`#[cfg(target_os)]`, a platform trait) is defined only on
  that platform, chosen by the extension's own `cfg`, so `defined?` and
  `respond_to?` answer.

## Messages

- Each error variant raises its own class under the crate's `Error`, with
  the crate's `Display` text, verbatim, typos included.
- A `#[non_exhaustive]` enum gets a fallback to the base class.
- A Rust unit test pins each `Display` text the Ruby side copies, so a
  crate upgrade that rewords one fails.

## Values and encodings

- Bytes cross as binary Strings, both ways; text as UTF-8.
- Integers convert through magnus, which raises `RangeError` outside the
  Rust type's range.
- Paths: byte for byte where the platform allows; `to_path` objects are
  accepted through `File.path`.
- A type Rust has and Ruby lacks (`Instant`, `Duration`) maps to the value
  Ruby code already uses for it, written down as a decision.

## Failure

- No input reachable from Ruby panics the crate. Calls run under
  `catch_unwind`; known panics are refused first with the crate's error.
- A lock poisoned by a panic is recovered, or the reason it cannot be is
  written down.
- A `LoadError` from the extension surfaces with its real message.
- Settings the platform's crate lacks are refused by the native layer, not
  silently ignored.

## Concurrency

- Ractor safety follows the crate's types (`Send`, `Sync`): mark the
  extension Ractor-safe when they allow it, and test a call from a non-main
  Ractor.
- A call that can block runs with the GVL released, touching no Ruby object
  while unlocked, with a test that another thread makes progress.
- Each `unsafe` block has a `SAFETY` comment citing its source.

## Documentation

- Every behavioral caveat in the crate's rustdoc is ported (dropping the
  clipboard before exit, Windows' single-thread clipboard, Linux ownership).
- Every deviation is in the plan and in the RDoc or README a user reads,
  with the precedence tier that justifies it.
