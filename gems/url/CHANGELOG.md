<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to ferro-url are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for its
own API. Releases are tagged `ferro-url/vX.Y.Z`.

## [Unreleased]

## [0.1.0] - 2026-11-05

### Added

- `debug` on `Url`, `Host`, `Origin`, `OpaqueOrigin`, `Position`, `SyntaxViolation`, each `ParseError` variant, `PathSegmentsMut`, and `FormUrlencoded::ByteSerialize`, answering url's `Debug` text as Rust formats it.
- `Url#path_segments_mut` and `Url#query_pairs_mut` take a block, the Rust value's scope: they yield the value, return the block's value, and drop the value when the block ends, after which any call on it raises `IOError`.
- `FormUrlencoded::Parse` and `FormUrlencoded::ByteSerialize`, form_urlencoded's iterators, with `next` (`nil` at the end), `each`, and `Enumerable`; `Parse#dup` copies its place, and `ByteSerialize#size_hint` is form_urlencoded's.

### Changed

- **Breaking:** `inspect` on `Url`, `OpaqueOrigin`, `Position`, and `SyntaxViolation` is Ruby's default, naming the class; url's `Debug` text moved to `debug`.
- **Breaking:** `Url#query_pairs` and `FormUrlencoded.parse` return a `FormUrlencoded::Parse`, and `FormUrlencoded.byte_serialize` a `FormUrlencoded::ByteSerialize`, instead of an Enumerator; each reads one item per `next`, and `each` consumes what remains.
- **Breaking:** A `FormUrlencoded::Serializer` used after `finish` raises `IOError`, not `Error`, with form_urlencoded's message.
- **Breaking:** A backward slice, `url[Position::AfterPath...Position::BeforePath]`, raises `RangeError` with Rust's message, `byte range starts at 21 but ends at 19`, instead of `Error` with the gem's own.
- **Breaking:** A `Serializer` start position inside a character is refused only by `clear`, where form_urlencoded panics, with `ArgumentError` and std's message, `assertion failed: self.is_char_boundary(new_len)`; `for_suffix` and the appends accept it, as form_urlencoded does.
- `Url#socket_addrs` runs the lookup on the calling thread, with the GVL still released, when no lookup thread can start, instead of raising `Error`.

### Removed

- Built without url's `expose_internals` feature, which only adds to the unbound `quirks` module.
- `Position` no longer includes `Comparable`; only `<=>`, which Range needs, remains.
- **Breaking:** `Url#into_string`, which url deprecates, and `Url#check_invariants` and `Quirks` (with `Quirks::InternalComponents`), which url hides with `#[doc(hidden)]`.

### Fixed

- `Url#socket_addrs` no longer hangs, spinning with the GVL held and stalling every Ruby thread, when called with an interrupt pending that Ruby holds back (as inside a custom `Exception#backtrace`): it never waits for the lookup, or runs it, with the GVL held.
- `Url#socket_addrs` applies the block's port to the URL as it was when called, even if the block changes the URL.
- `Url#[]` refuses an inclusive beginless range (`..Position::X`) with `TypeError`, as url implements no `RangeToInclusive` index.
- A frozen `Url`'s native value refuses every change, so private methods can no longer change a frozen or Ractor-shared `Url` through another `Url`.

## [0.1.0.pre.1] - 2026-10-27

### Added

- `Ferro::Url::Url` binding url 2.5.8: `parse`, `parse_with_params`, `from_str`, `try_from`, `options`, `join`, `make_relative`, every getter and setter, `origin`, `socket_addrs`, `from_file_path`, `from_directory_path`, `to_file_path`, slicing by `Position`, `check_invariants`, and the deprecated `into_string`.
- `ParseOptions` with `base_url`, `encoding_override`, `syntax_violation_callback`, and `parse`.
- `Host` with `Domain`, `Ipv4`, and `Ipv6`, `Host.parse`, and `Host.parse_opaque`; `Origin` with `Opaque` and `Tuple`, and `OpaqueOrigin`; `Position`; `SyntaxViolation`.
- `PathSegmentsMut`, `UrlQuery`, and `FormUrlencoded` (form_urlencoded 1.2.2) with `parse`, `byte_serialize`, and `Serializer`.
- `Quirks`, url's WHATWG URL API getters and setters, and `Quirks::InternalComponents`.
- `ParseError` with a subclass per variant, and `Error` for url's `Err(())` results. A panic inside url raises `Error` instead of ending the process.
- Built with url's `serde` and `expose_internals` features.

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-url/v0.1.0...HEAD
[0.1.0]: https://github.com/setdef/Ferro/compare/ferro-url/v0.1.0.pre.1...ferro-url/v0.1.0
[0.1.0.pre.1]: https://github.com/setdef/Ferro/releases/tag/ferro-url/v0.1.0.pre.1
