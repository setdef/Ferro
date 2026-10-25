<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Lessons

Each entry names a mistake, where it was found, and the habit that
prevents it. Most come from Tokra, the project Ferro spun out of, whose
clipboard plugin carried the first arboard binding.

## Reading the source

- **An earlier binding is not the source.** Tokra's binding guarded
  arboard 3.6.1's macOS panics; arboard 3.7.0 fixed one of them and its
  Linux and Windows encoders still assert a buffer length. Re-read the
  crate at the version you bind.
- **Read the signature, not just the body.** A function that returns `!`
  never returns; a builder that consumes `self` is single-use in Rust and
  reusable in Ruby. Say which in the docs.
- **Follow the input to the dependency.** arboard's own code looked safe
  for a short image buffer; the `image` crate's PNG encoder underneath it
  asserts the length.

## Testing

- **A stub can hide a missing method.** Test the real crate, and let
  `rbs:parity` catch a declaration only an ancestor provides.
- **Name what you could not test.** Platform paths this machine cannot run
  are listed as unverified in the plan, with what would check them.
- **A test that passes with its code deleted is not a test.** Revert the
  line and watch it fail.

## Failure paths

- **Rust panics end the VM.** magnus raises `fatal` for a panic in a bound
  method. Catch it, and refuse known panicking inputs with the crate's own
  error (Tokra's plan 016, item 6:
  https://git.sr.ht/~kerrick/tokra/tree/trunk/item/doc/contributors/plan/016.md).
- **Validate in the language's words.** A wrong Ruby type raises
  `TypeError` worded as Ruby words it, not a message you invent.

## Packaging

- **The working tree hides packaging bugs.** A file `spec.files` forgets
  still loads from the repository, and a crate that inherits from a
  workspace the gem lacks still compiles there. `package:check` builds and
  loads each gem from its package (Tokra's plan 017:
  https://git.sr.ht/~kerrick/tokra/tree/trunk/item/doc/contributors/plan/017.md).
- **An installed gem builds alone.** Each gem is its own Cargo workspace
  with a committed `Cargo.lock`, built `--locked`; no `workspace = true`
  inheritance.

## Documentation

- **Undocumented deviations count as bugs.** Every place the binding
  differs from calling the crate in Rust is in the plan and in the RDoc or
  README.
