// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! idna's crate-level functions, its `punycode` module, and its `uts46`
//! module (idna 1.1.0 `src/lib.rs`, `src/punycode.rs`, `src/uts46.rs`).

use idna::uts46::{
    AsciiDenyList, DnsLength, ErrorPolicy, Hyphens, ProcessingError, ProcessingSuccess, Uts46,
};
use magnus::{Error, RString, Ruby, Symbol, Value};

use crate::callback::OutputAsUnicode;
use crate::{errors, guarded};

/// The Ruby `Ferro::Idna::Native::AsciiDenyList`, which
/// `Ferro::Idna::Uts46::AsciiDenyList` holds. idna's `AsciiDenyList` keeps
/// its bits private (`src/uts46.rs:269-274`), so Ruby holds the value
/// itself. It is `Copy` and nothing changes it, so a frozen one is
/// shareable.
#[magnus::wrap(
    class = "Ferro::Idna::Native::AsciiDenyList",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct DenyList(pub AsciiDenyList);

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the assertions of idna 1.1.0's AsciiDenyList::new
//   (src/uts46.rs:294-322), checked here before idna would panic

/// The assertion idna's `AsciiDenyList::new` would fail on `deny_list`, in
/// the order it checks each byte (`src/uts46.rs:301-321`), or `None`.
pub fn refusal(deny_list: &str) -> Option<&'static str> {
    deny_list.bytes().find_map(|b| {
        if b >= 0x80 {
            Some("ASCII deny list must be ASCII.")
        } else if b == b'.' {
            Some("ASCII deny list must not contain the dot.")
        } else if b == b'-' {
            Some("ASCII deny list must not contain the hyphen.")
        } else if b.is_ascii_digit() {
            Some("ASCII deny list must not contain digits.")
        } else if b.is_ascii_alphabetic() {
            Some("ASCII deny list must not contain letters.")
        } else {
            None
        }
    })
}

// SPDX-SnippetEnd

/// `AsciiDenyList::new(deny_glyphless, deny_list)` (`src/uts46.rs:277-322`),
/// refusing with `ArgumentError` and idna's message what it would panic on.
pub fn ascii_deny_list_new(
    ruby: &Ruby,
    deny_glyphless: bool,
    deny_list: String,
) -> Result<DenyList, Error> {
    if let Some(message) = refusal(&deny_list) {
        return Err(Error::new(ruby.exception_arg_error(), message));
    }
    guarded(ruby, move || {
        Ok(DenyList(AsciiDenyList::new(deny_glyphless, &deny_list)))
    })
}

/// `AsciiDenyList::EMPTY`, `STD3`, or `URL` (`src/uts46.rs:325-351`).
pub fn ascii_deny_list_constant(ruby: &Ruby, name: Symbol) -> Result<DenyList, Error> {
    match name.name()?.as_ref() {
        "EMPTY" => Ok(DenyList(AsciiDenyList::EMPTY)),
        "STD3" => Ok(DenyList(AsciiDenyList::STD3)),
        "URL" => Ok(DenyList(AsciiDenyList::URL)),
        other => Err(Error::new(
            ruby.exception_arg_error(),
            format!("no AsciiDenyList constant {other}"),
        )),
    }
}

/// `AsciiDenyList`'s `PartialEq` (`src/uts46.rs:270`).
pub fn ascii_deny_list_eq(left: &DenyList, right: &DenyList) -> bool {
    left.0 == right.0
}

/// The `Hyphens` variant named `name` (`src/uts46.rs:354-376`).
fn hyphens(ruby: &Ruby, name: Symbol) -> Result<Hyphens, Error> {
    match name.name()?.as_ref() {
        "Allow" => Ok(Hyphens::Allow),
        "CheckFirstLast" => Ok(Hyphens::CheckFirstLast),
        "Check" => Ok(Hyphens::Check),
        other => Err(unknown(ruby, "Hyphens", other)),
    }
}

/// The `DnsLength` variant named `name` (`src/uts46.rs:378-389`).
fn dns_length(ruby: &Ruby, name: Symbol) -> Result<DnsLength, Error> {
    match name.name()?.as_ref() {
        "Ignore" => Ok(DnsLength::Ignore),
        "VerifyAllowRootDot" => Ok(DnsLength::VerifyAllowRootDot),
        "Verify" => Ok(DnsLength::Verify),
        other => Err(unknown(ruby, "DnsLength", other)),
    }
}

/// The `ErrorPolicy` variant named `name` (`src/uts46.rs:391-401`).
fn error_policy(ruby: &Ruby, name: Symbol) -> Result<ErrorPolicy, Error> {
    match name.name()?.as_ref() {
        "FailFast" => Ok(ErrorPolicy::FailFast),
        "MarkErrors" => Ok(ErrorPolicy::MarkErrors),
        other => Err(unknown(ruby, "ErrorPolicy", other)),
    }
}

fn unknown(ruby: &Ruby, enumeration: &str, name: &str) -> Error {
    Error::new(
        ruby.exception_arg_error(),
        format!("no {enumeration} variant {name}"),
    )
}

/// A String's bytes, whatever its encoding (plan 006, decision 4).
fn bytes(domain: RString) -> Vec<u8> {
    domain.to_bytes().to_vec()
}

/// `domain_to_ascii_cow(domain, ascii_deny_list)` (`src/lib.rs:86-115`).
pub fn domain_to_ascii_cow(ruby: &Ruby, domain: RString, list: &DenyList) -> Result<String, Error> {
    let domain = bytes(domain);
    let list = list.0;
    guarded(ruby, move || {
        idna::domain_to_ascii_cow(&domain, list)
            .map(std::borrow::Cow::into_owned)
            .map_err(|error| errors(ruby, &error))
    })
}

/// `domain_to_ascii_from_cow(domain, ascii_deny_list)` (`src/lib.rs:117-142`).
pub fn domain_to_ascii_from_cow(
    ruby: &Ruby,
    domain: RString,
    list: &DenyList,
) -> Result<String, Error> {
    let domain = bytes(domain);
    let list = list.0;
    guarded(ruby, move || {
        idna::domain_to_ascii_from_cow(domain.into(), list)
            .map(std::borrow::Cow::into_owned)
            .map_err(|error| errors(ruby, &error))
    })
}

/// `domain_to_ascii(domain)` (`src/lib.rs:144-157`).
pub fn domain_to_ascii(ruby: &Ruby, domain: String) -> Result<String, Error> {
    guarded(ruby, move || {
        idna::domain_to_ascii(&domain).map_err(|error| errors(ruby, &error))
    })
}

/// `domain_to_ascii_strict(domain)` (`src/lib.rs:159-175`).
pub fn domain_to_ascii_strict(ruby: &Ruby, domain: String) -> Result<String, Error> {
    guarded(ruby, move || {
        idna::domain_to_ascii_strict(&domain).map_err(|error| errors(ruby, &error))
    })
}

/// `domain_to_unicode(domain)` (`src/lib.rs:177-198`): the text, and
/// whether idna found no error.
pub fn domain_to_unicode(ruby: &Ruby, domain: String) -> Result<(String, bool), Error> {
    guarded(ruby, move || {
        let (text, result) = idna::domain_to_unicode(&domain);
        Ok((text, result.is_ok()))
    })
}

/// `punycode::decode_to_string(input)` (`src/punycode.rs:42-56`).
pub fn punycode_decode_to_string(ruby: &Ruby, input: String) -> Result<Option<String>, Error> {
    guarded(ruby, move || Ok(idna::punycode::decode_to_string(&input)))
}

/// `punycode::decode(input)` (`src/punycode.rs:57-70`).
pub fn punycode_decode(ruby: &Ruby, input: String) -> Result<Option<Vec<char>>, Error> {
    guarded(ruby, move || Ok(idna::punycode::decode(&input)))
}

/// `punycode::encode_str(input)` (`src/punycode.rs:318-330`).
pub fn punycode_encode_str(ruby: &Ruby, input: String) -> Result<Option<String>, Error> {
    guarded(ruby, move || Ok(idna::punycode::encode_str(&input)))
}

/// `punycode::encode(input)` (`src/punycode.rs:332-345`). magnus converts
/// each element to a `char`, raising `TypeError` for a String that is not
/// one character (plan 006, decision 6).
pub fn punycode_encode(ruby: &Ruby, input: Vec<char>) -> Result<Option<String>, Error> {
    guarded(ruby, move || Ok(idna::punycode::encode(&input)))
}

/// `uts46::verify_dns_length(domain_name, allow_trailing_dot)`
/// (`src/uts46.rs:456-486`).
pub fn verify_dns_length(
    ruby: &Ruby,
    domain_name: String,
    allow_trailing_dot: bool,
) -> Result<bool, Error> {
    guarded(ruby, move || {
        Ok(idna::uts46::verify_dns_length(
            &domain_name,
            allow_trailing_dot,
        ))
    })
}

/// `Uts46::to_ascii(domain_name, ascii_deny_list, hyphens, dns_length)`
/// (`src/uts46.rs:512-586`).
pub fn uts46_to_ascii(
    ruby: &Ruby,
    domain_name: RString,
    list: &DenyList,
    hyphens_name: Symbol,
    dns_length_name: Symbol,
) -> Result<String, Error> {
    let domain_name = bytes(domain_name);
    let list = list.0;
    let hyphens = hyphens(ruby, hyphens_name)?;
    let dns_length = dns_length(ruby, dns_length_name)?;
    guarded(ruby, move || {
        Uts46::new()
            .to_ascii(&domain_name, list, hyphens, dns_length)
            .map(std::borrow::Cow::into_owned)
            .map_err(|error| errors(ruby, &error))
    })
}

/// `Uts46::to_unicode(domain_name, ascii_deny_list, hyphens)`
/// (`src/uts46.rs:588-617`): the text, and whether idna found no error.
pub fn uts46_to_unicode(
    ruby: &Ruby,
    domain_name: RString,
    list: &DenyList,
    hyphens_name: Symbol,
) -> Result<(String, bool), Error> {
    let domain_name = bytes(domain_name);
    let list = list.0;
    let hyphens = hyphens(ruby, hyphens_name)?;
    guarded(ruby, move || {
        let (text, result) = Uts46::new().to_unicode(&domain_name, list, hyphens);
        Ok((text.into_owned(), result.is_ok()))
    })
}

/// `Uts46::to_user_interface(domain_name, ascii_deny_list, hyphens,
/// output_as_unicode)` (`src/uts46.rs:619-691`), with a Ruby callable as
/// the closure: the text, and whether idna found no error.
pub fn uts46_to_user_interface(
    ruby: &Ruby,
    domain_name: RString,
    list: &DenyList,
    hyphens_name: Symbol,
    callable: Value,
) -> Result<(String, bool), Error> {
    let domain_name = bytes(domain_name);
    let list = list.0;
    let hyphens = hyphens(ruby, hyphens_name)?;
    guarded(ruby, move || {
        let mut callback = OutputAsUnicode::new(ruby, callable);
        let (text, result) =
            Uts46::new().to_user_interface(&domain_name, list, hyphens, |label, tld, is_bidi| {
                callback.decide(label, tld, is_bidi)
            });
        let text = text.into_owned();
        callback.finish()?;
        Ok((text, result.is_ok()))
    })
}

/// `Uts46::process(domain_name, ascii_deny_list, hyphens, error_policy,
/// output_as_unicode, sink, ascii_sink)` (`src/uts46.rs:693-1045`), with a
/// Ruby callable as the closure and Rust Strings as the sinks (plan 006,
/// decision 14): the outcome's variant name, under `ProcessingSuccess` or
/// `ProcessingError`, and what each sink received. `ascii_sink` is `None`
/// unless `with_ascii_sink`.
pub fn uts46_process(
    ruby: &Ruby,
    domain_name: RString,
    list: &DenyList,
    hyphens_name: Symbol,
    error_policy_name: Symbol,
    callable: Value,
    with_ascii_sink: bool,
) -> Result<(String, String, Option<String>), Error> {
    let domain_name = bytes(domain_name);
    let list = list.0;
    let hyphens = hyphens(ruby, hyphens_name)?;
    let error_policy = error_policy(ruby, error_policy_name)?;
    guarded(ruby, move || {
        let mut callback = OutputAsUnicode::new(ruby, callable);
        let mut sink = String::new();
        let mut ascii_sink = with_ascii_sink.then(String::new);
        let outcome = Uts46::new().process(
            &domain_name,
            list,
            hyphens,
            error_policy,
            |label, tld, is_bidi| callback.decide(label, tld, is_bidi),
            &mut sink,
            ascii_sink.as_mut(),
        );
        callback.finish()?;
        Ok((outcome_name(outcome).to_owned(), sink, ascii_sink))
    })
}

/// The path, under `Uts46`, of the value or class `outcome` names.
const fn outcome_name(outcome: Result<ProcessingSuccess, ProcessingError>) -> &'static str {
    match outcome {
        Ok(ProcessingSuccess::Passthrough) => "ProcessingSuccess::Passthrough",
        Ok(ProcessingSuccess::WroteToSink) => "ProcessingSuccess::WroteToSink",
        Err(ProcessingError::ValidityError) => "ProcessingError::ValidityError",
        Err(ProcessingError::SinkError) => "ProcessingError::SinkError",
    }
}

#[cfg(test)]
mod tests {
    use super::{outcome_name, refusal};
    use idna::uts46::{AsciiDenyList, ProcessingError, ProcessingSuccess};

    /// The message `AsciiDenyList::new` panics with for `deny_list`.
    fn idnas_panic(deny_list: &str) -> String {
        let payload = std::panic::catch_unwind(|| AsciiDenyList::new(false, deny_list))
            .err()
            .expect("idna panics");
        crate::panic_of(&payload).0
    }

    #[test]
    fn each_refusal_is_idnas_own_panic() {
        for list in ["é", ".", "-", "7", "q", "Q", "%-", "%a."] {
            assert_eq!(refusal(list), Some(idnas_panic(list).as_str()), "{list}");
        }
    }

    #[test]
    fn idna_accepts_what_is_not_refused() {
        assert_eq!(refusal(""), None);
        assert_eq!(refusal("%#/:<>?@[\\]^|"), None);
        assert!(AsciiDenyList::new(true, "%#/:<>?@[\\]^|") == AsciiDenyList::URL);
    }

    #[test]
    fn outcomes_name_their_variants() {
        assert_eq!(
            outcome_name(Ok(ProcessingSuccess::Passthrough)),
            "ProcessingSuccess::Passthrough"
        );
        assert_eq!(
            outcome_name(Ok(ProcessingSuccess::WroteToSink)),
            "ProcessingSuccess::WroteToSink"
        );
        assert_eq!(
            outcome_name(Err(ProcessingError::ValidityError)),
            "ProcessingError::ValidityError"
        );
        assert_eq!(
            outcome_name(Err(ProcessingError::SinkError)),
            "ProcessingError::SinkError"
        );
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the Debug texts of idna 1.1.0's ProcessingError
    //   (src/uts46.rs:421-433), which Ruby's messages copy

    #[test]
    fn processing_errors_debug_as_their_names() {
        assert_eq!(
            format!("{:?}", ProcessingError::ValidityError),
            "ValidityError"
        );
        assert_eq!(format!("{:?}", ProcessingError::SinkError), "SinkError");
    }

    // SPDX-SnippetEnd
}
