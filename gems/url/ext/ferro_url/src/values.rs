// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! url's values: `Host`, `Origin`, `OpaqueOrigin`, `ParseError`, and
//! `SyntaxViolation` (url 2.5.8 `src/host.rs`, `src/origin.rs`,
//! `src/parser.rs`).
//!
//! A host crosses as `[variant, value]`: `["Domain", String]`,
//! `["Ipv4", Integer]`, or `["Ipv6", Integer]`, the address as its number.
//! An origin crosses as `["Opaque", Native::OpaqueOrigin]` or
//! `["Tuple", scheme, host, port]` (plan 005, decision 4).

use std::cmp::Ordering;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::net::{Ipv4Addr, Ipv6Addr};

use magnus::{function, prelude::*, Error, IntoValue, RArray, RModule, Ruby, Symbol, Value};
use url::{Host, OpaqueOrigin, Origin, ParseError, SyntaxViolation};

use crate::{guarded, raise};

/// The Ruby `Ferro::Url::Native::OpaqueOrigin`, which
/// `Ferro::Url::OpaqueOrigin` holds. url keeps its number private
/// (`src/origin.rs:113-115`), so Ruby holds the value itself.
#[magnus::wrap(
    class = "Ferro::Url::Native::OpaqueOrigin",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NativeOpaqueOrigin(pub OpaqueOrigin);

/// `host` as Ruby holds it: `[variant, value]`.
pub fn host_to_ruby<S: AsRef<str>>(ruby: &Ruby, host: &Host<S>) -> RArray {
    let (variant, value): (&str, Value) = match host {
        Host::Domain(domain) => (
            "Domain",
            ruby.str_new(domain.as_ref()).into_value_with(ruby),
        ),
        Host::Ipv4(address) => ("Ipv4", u32::from(*address).into_value_with(ruby)),
        Host::Ipv6(address) => (
            "Ipv6",
            ruby.integer_from_u128(u128::from(*address))
                .into_value_with(ruby),
        ),
    };
    ruby.ary_new_from_values(&[variant.into_value_with(ruby), value])
}

/// The `Host<String>` a Ruby `[variant, value]` describes.
pub fn host_from_ruby(ruby: &Ruby, parts: RArray) -> Result<Host, Error> {
    let variant: String = parts.entry(0)?;
    match variant.as_str() {
        "Domain" => Ok(Host::Domain(parts.entry(1)?)),
        "Ipv4" => Ok(Host::Ipv4(Ipv4Addr::from(parts.entry::<u32>(1)?))),
        "Ipv6" => Ok(Host::Ipv6(Ipv6Addr::from(parts.entry::<u128>(1)?))),
        other => Err(Error::new(
            ruby.exception_arg_error(),
            format!("no Host variant {other}"),
        )),
    }
}

/// `origin` as Ruby holds it.
pub fn origin_to_ruby(ruby: &Ruby, origin: Origin) -> RArray {
    match origin {
        Origin::Opaque(opaque) => ruby.ary_new_from_values(&[
            "Opaque".into_value_with(ruby),
            NativeOpaqueOrigin(opaque).into_value_with(ruby),
        ]),
        Origin::Tuple(scheme, host, port) => ruby.ary_new_from_values(&[
            "Tuple".into_value_with(ruby),
            scheme.into_value_with(ruby),
            host_to_ruby(ruby, &host).into_value_with(ruby),
            port.into_value_with(ruby),
        ]),
    }
}

/// The `Origin` a Ruby origin describes.
fn origin_from_ruby(ruby: &Ruby, parts: RArray) -> Result<Origin, Error> {
    let variant: String = parts.entry(0)?;
    match variant.as_str() {
        "Opaque" => Ok(Origin::Opaque(
            parts.entry::<&NativeOpaqueOrigin>(1)?.0.clone(),
        )),
        "Tuple" => Ok(Origin::Tuple(
            parts.entry(1)?,
            host_from_ruby(ruby, parts.entry(2)?)?,
            parts.entry(3)?,
        )),
        other => Err(Error::new(
            ruby.exception_arg_error(),
            format!("no Origin variant {other}"),
        )),
    }
}

/// The class path, under `Ferro::Url`, of url's `ParseError` variant
/// (`src/parser.rs:88-99`). A variant a later url adds goes to the base
/// class, since the enum is `#[non_exhaustive]`.
pub const fn parse_error_path(error: ParseError) -> &'static str {
    match error {
        ParseError::EmptyHost => "ParseError::EmptyHost",
        ParseError::IdnaError => "ParseError::IdnaError",
        ParseError::InvalidPort => "ParseError::InvalidPort",
        ParseError::InvalidIpv4Address => "ParseError::InvalidIpv4Address",
        ParseError::InvalidIpv6Address => "ParseError::InvalidIpv6Address",
        ParseError::InvalidDomainCharacter => "ParseError::InvalidDomainCharacter",
        ParseError::RelativeUrlWithoutBase => "ParseError::RelativeUrlWithoutBase",
        ParseError::RelativeUrlWithCannotBeABaseBase => {
            "ParseError::RelativeUrlWithCannotBeABaseBase"
        }
        ParseError::SetHostOnCannotBeABaseUrl => "ParseError::SetHostOnCannotBeABaseUrl",
        ParseError::Overflow => "ParseError::Overflow",
        _ => "ParseError",
    }
}

/// url's `ParseError` as a Ruby exception, with its `Display` text.
pub fn parse_error(ruby: &Ruby, error: ParseError) -> Error {
    raise(ruby, parse_error_path(error), error.to_string())
}

/// The constant name of url's `SyntaxViolation` variant
/// (`src/parser.rs:107-151`), its `Debug` text.
pub fn syntax_violation_name(violation: SyntaxViolation) -> String {
    format!("{violation:?}")
}

/// The `SyntaxViolation` named `name`.
fn syntax_violation(name: &str) -> Option<SyntaxViolation> {
    Some(match name {
        "Backslash" => SyntaxViolation::Backslash,
        "C0SpaceIgnored" => SyntaxViolation::C0SpaceIgnored,
        "EmbeddedCredentials" => SyntaxViolation::EmbeddedCredentials,
        "ExpectedDoubleSlash" => SyntaxViolation::ExpectedDoubleSlash,
        "ExpectedFileDoubleSlash" => SyntaxViolation::ExpectedFileDoubleSlash,
        "FileWithHostAndWindowsDrive" => SyntaxViolation::FileWithHostAndWindowsDrive,
        "NonUrlCodePoint" => SyntaxViolation::NonUrlCodePoint,
        "NullInFragment" => SyntaxViolation::NullInFragment,
        "PercentDecode" => SyntaxViolation::PercentDecode,
        "TabOrNewlineIgnored" => SyntaxViolation::TabOrNewlineIgnored,
        "UnencodedAtSign" => SyntaxViolation::UnencodedAtSign,
        _ => return None,
    })
}

/// `SyntaxViolation::description` (`src/parser.rs:124-132`) of the variant
/// named `name`.
fn syntax_violation_description(ruby: &Ruby, name: Symbol) -> Result<String, Error> {
    let name = name.name()?;
    syntax_violation(&name)
        .map(|violation| violation.description().to_owned())
        .ok_or_else(|| {
            Error::new(
                ruby.exception_arg_error(),
                format!("no SyntaxViolation variant {name}"),
            )
        })
}

/// `Host::parse(input)` (`src/host.rs:78-83`).
fn host_parse(ruby: &Ruby, input: String) -> Result<RArray, Error> {
    guarded(ruby, move || {
        Host::parse(&input)
            .map(|host| host_to_ruby(ruby, &host))
            .map_err(|error| parse_error(ruby, error))
    })
}

/// `Host::parse_opaque(input)` (`src/host.rs:85-88`).
fn host_parse_opaque(ruby: &Ruby, input: String) -> Result<RArray, Error> {
    guarded(ruby, move || {
        Host::parse_opaque(&input)
            .map(|host| host_to_ruby(ruby, &host))
            .map_err(|error| parse_error(ruby, error))
    })
}

/// `Host`'s `Display` (`src/host.rs:186-198`).
fn host_to_s(ruby: &Ruby, parts: RArray) -> Result<String, Error> {
    let host = host_from_ruby(ruby, parts)?;
    guarded(ruby, move || Ok(host.to_string()))
}

/// `Host`'s derived `Ord` (`src/host.rs:44`): -1, 0, or 1.
fn host_cmp(ruby: &Ruby, left: RArray, right: RArray) -> Result<i8, Error> {
    let left = host_from_ruby(ruby, left)?;
    let right = host_from_ruby(ruby, right)?;
    guarded(ruby, move || {
        Ok(match left.cmp(&right) {
            Ordering::Less => -1,
            Ordering::Equal => 0,
            Ordering::Greater => 1,
        })
    })
}

/// `Origin::new_opaque()` (`src/origin.rs:65-69`).
fn origin_new_opaque(ruby: &Ruby) -> Result<RArray, Error> {
    guarded(ruby, || Ok(origin_to_ruby(ruby, Origin::new_opaque())))
}

/// `Origin::ascii_serialization` (`src/origin.rs:77-89`).
fn origin_ascii_serialization(ruby: &Ruby, parts: RArray) -> Result<String, Error> {
    let origin = origin_from_ruby(ruby, parts)?;
    guarded(ruby, move || Ok(origin.ascii_serialization()))
}

/// `Origin::unicode_serialization` (`src/origin.rs:91-110`).
fn origin_unicode_serialization(ruby: &Ruby, parts: RArray) -> Result<String, Error> {
    let origin = origin_from_ruby(ruby, parts)?;
    guarded(ruby, move || Ok(origin.unicode_serialization()))
}

/// `OpaqueOrigin`'s `PartialEq` (`src/origin.rs:113`).
fn opaque_origin_eq(left: &NativeOpaqueOrigin, right: &NativeOpaqueOrigin) -> bool {
    left.0 == right.0
}

/// `OpaqueOrigin`'s `Hash` (`src/origin.rs:113`), through std's default
/// hasher, whose keys are fixed, so equal origins hash alike.
fn opaque_origin_hash(origin: &NativeOpaqueOrigin) -> u64 {
    let mut hasher = DefaultHasher::new();
    origin.0.hash(&mut hasher);
    hasher.finish()
}

/// `OpaqueOrigin`'s `Debug` (`src/origin.rs:113`): `OpaqueOrigin(3)`.
fn opaque_origin_inspect(origin: &NativeOpaqueOrigin) -> String {
    format!("{:?}", origin.0)
}

pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("host_parse", function!(host_parse, 1))?;
    native.define_singleton_method("host_parse_opaque", function!(host_parse_opaque, 1))?;
    native.define_singleton_method("host_to_s", function!(host_to_s, 1))?;
    native.define_singleton_method("host_cmp", function!(host_cmp, 2))?;
    native.define_singleton_method("origin_new_opaque", function!(origin_new_opaque, 0))?;
    native.define_singleton_method(
        "origin_ascii_serialization",
        function!(origin_ascii_serialization, 1),
    )?;
    native.define_singleton_method(
        "origin_unicode_serialization",
        function!(origin_unicode_serialization, 1),
    )?;
    native.define_singleton_method("opaque_origin_eq", function!(opaque_origin_eq, 2))?;
    native.define_singleton_method("opaque_origin_hash", function!(opaque_origin_hash, 1))?;
    native.define_singleton_method("opaque_origin_inspect", function!(opaque_origin_inspect, 1))?;
    native.define_singleton_method(
        "syntax_violation_description",
        function!(syntax_violation_description, 1),
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{parse_error_path, syntax_violation, syntax_violation_name};
    use url::{ParseError, SyntaxViolation};

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the Display texts of url 2.5.8's ParseError and
    //   the descriptions of its SyntaxViolation (src/parser.rs:88-151),
    //   which these tests pin

    #[test]
    fn each_parse_error_goes_to_its_class_with_urls_text() {
        let cases = [
            (ParseError::EmptyHost, "EmptyHost", "empty host"),
            (
                ParseError::IdnaError,
                "IdnaError",
                "invalid international domain name",
            ),
            (
                ParseError::InvalidPort,
                "InvalidPort",
                "invalid port number",
            ),
            (
                ParseError::InvalidIpv4Address,
                "InvalidIpv4Address",
                "invalid IPv4 address",
            ),
            (
                ParseError::InvalidIpv6Address,
                "InvalidIpv6Address",
                "invalid IPv6 address",
            ),
            (
                ParseError::InvalidDomainCharacter,
                "InvalidDomainCharacter",
                "invalid domain character",
            ),
            (
                ParseError::RelativeUrlWithoutBase,
                "RelativeUrlWithoutBase",
                "relative URL without a base",
            ),
            (
                ParseError::RelativeUrlWithCannotBeABaseBase,
                "RelativeUrlWithCannotBeABaseBase",
                "relative URL with a cannot-be-a-base base",
            ),
            (
                ParseError::SetHostOnCannotBeABaseUrl,
                "SetHostOnCannotBeABaseUrl",
                "a cannot-be-a-base URL doesn\u{2019}t have a host to set",
            ),
            (
                ParseError::Overflow,
                "Overflow",
                "URLs more than 4 GB are not supported",
            ),
        ];
        for (error, variant, text) in cases {
            assert_eq!(parse_error_path(error), format!("ParseError::{variant}"));
            assert_eq!(error.to_string(), text);
            assert_eq!(format!("{error:?}"), variant);
        }
    }

    #[test]
    fn each_syntax_violation_round_trips_by_name_with_its_description() {
        let cases = [
            (SyntaxViolation::Backslash, "backslash"),
            (
                SyntaxViolation::C0SpaceIgnored,
                "leading or trailing control or space character are ignored in URLs",
            ),
            (
                SyntaxViolation::EmbeddedCredentials,
                "embedding authentication information (username or password) in an URL is not recommended",
            ),
            (SyntaxViolation::ExpectedDoubleSlash, "expected //"),
            (SyntaxViolation::ExpectedFileDoubleSlash, "expected // after file:"),
            (
                SyntaxViolation::FileWithHostAndWindowsDrive,
                "file: with host and Windows drive letter",
            ),
            (SyntaxViolation::NonUrlCodePoint, "non-URL code point"),
            (
                SyntaxViolation::NullInFragment,
                "NULL characters are ignored in URL fragment identifiers",
            ),
            (SyntaxViolation::PercentDecode, "expected 2 hex digits after %"),
            (
                SyntaxViolation::TabOrNewlineIgnored,
                "tabs or newlines are ignored in URLs",
            ),
            (
                SyntaxViolation::UnencodedAtSign,
                "unencoded @ sign in username or password",
            ),
        ];
        for (violation, description) in cases {
            let name = syntax_violation_name(violation);
            assert_eq!(syntax_violation(&name), Some(violation));
            assert_eq!(violation.description(), description);
            assert_eq!(violation.to_string(), description);
        }
        assert_eq!(syntax_violation("Nope"), None);
    }

    // SPDX-SnippetEnd
}
