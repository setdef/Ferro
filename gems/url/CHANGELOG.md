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

## [0.1.0.pre.1] - 2026-10-27

### Added

- `Ferro::Url::Url` binding url 2.5.8: `parse`, `parse_with_params`, `from_str`, `try_from`, `options`, `join`, `make_relative`, every getter and setter, `origin`, `socket_addrs`, `from_file_path`, `from_directory_path`, `to_file_path`, slicing by `Position`, `check_invariants`, and the deprecated `into_string`.
- `ParseOptions` with `base_url`, `encoding_override`, `syntax_violation_callback`, and `parse`.
- `Host` with `Domain`, `Ipv4`, and `Ipv6`, `Host.parse`, and `Host.parse_opaque`; `Origin` with `Opaque` and `Tuple`, and `OpaqueOrigin`; `Position`; `SyntaxViolation`.
- `PathSegmentsMut`, `UrlQuery`, and `FormUrlencoded` (form_urlencoded 1.2.2) with `parse`, `byte_serialize`, and `Serializer`.
- `Quirks`, url's WHATWG URL API getters and setters, and `Quirks::InternalComponents`.
- `ParseError` with a subclass per variant, and `Error` for url's `Err(())` results. A panic inside url raises `Error` instead of ending the process.
- Built with url's `serde` and `expose_internals` features.

[Unreleased]: https://github.com/setdef/Ferro/compare/ferro-url/v0.1.0.pre.1...HEAD
[0.1.0.pre.1]: https://github.com/setdef/Ferro/releases/tag/ferro-url/v0.1.0.pre.1
