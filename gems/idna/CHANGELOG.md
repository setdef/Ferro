<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Changelog

All notable changes to ferro-idna are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for its
own API. Releases are tagged `ferro-idna/vX.Y.Z`.

## [Unreleased]

### Added

- `Ferro::Idna` binding idna 1.1.0: `domain_to_ascii_cow`, `domain_to_ascii_from_cow`, `domain_to_ascii`, `domain_to_ascii_strict`, and `domain_to_unicode`, which returns its text beside an unraised `Errors`.
- `Uts46::Uts46` with `to_ascii`, `to_unicode`, `to_user_interface`, and `process`, whose sinks are Strings; `Uts46.verify_dns_length`; `Uts46::AsciiDenyList` (also `Idna::AsciiDenyList`) with `EMPTY`, `STD3`, and `URL`; and `Hyphens`, `DnsLength`, `ErrorPolicy`, and `ProcessingSuccess` constants.
- `Punycode` with `decode_to_string`, `decode`, `encode_str`, and `encode`.
- The deprecated `Config` and `Idna`, warning as deprecated constants.
- `Errors` and `Uts46::ProcessingError` with a subclass per variant. A panic inside idna raises `Errors` instead of ending the process, and the inputs idna panics on raise `ArgumentError` with idna's message.

[Unreleased]: https://github.com/setdef/Ferro/commits/trunk/gems/idna
