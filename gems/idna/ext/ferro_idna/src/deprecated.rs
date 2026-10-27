// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! idna's deprecated `Config` and `Idna` (idna 1.1.0 `src/deprecated.rs`).
//!
//! `Config`'s fields are private, so Ruby holds its four flags and each
//! function here rebuilds the value through idna's own setters (plan 006,
//! decision 9). The crate marks both types `#[deprecated]`, and binding
//! them is the point, so this module allows the lint.
#![allow(deprecated)]

use idna::{Config, Idna};
use magnus::{Error, Ruby};

use crate::{errors, guarded};

/// A `Config`'s flags, in the order its fields are declared
/// (`src/deprecated.rs:135-140`): `use_std3_ascii_rules`,
/// `transitional_processing`, `verify_dns_length`, `check_hyphens`.
pub type Flags = (bool, bool, bool, bool);

/// The `Config` with `flags`, built from `Config::default()` through its
/// setters (`src/deprecated.rs:143-201`).
fn config(flags: Flags) -> Config {
    let (std3, transitional, dns_length, hyphens) = flags;
    Config::default()
        .use_std3_ascii_rules(std3)
        .transitional_processing(transitional)
        .verify_dns_length(dns_length)
        .check_hyphens(hyphens)
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the assertion of idna 1.1.0's
//   Config::use_idna_2008_rules (src/deprecated.rs:204-214)

/// What `Config::use_idna_2008_rules` asserts (`src/deprecated.rs:212`).
pub const IDNA_2008: &str = "IDNA 2008 rules are no longer supported";

// SPDX-SnippetEnd

/// `Config::use_idna_2008_rules(value)` (`src/deprecated.rs:204-214`),
/// which changes nothing and panics for `true`; `true` is refused first
/// with `ArgumentError` and idna's message (plan 006, decision 8).
pub fn config_use_idna_2008_rules(ruby: &Ruby, value: bool) -> Result<(), Error> {
    if value {
        return Err(Error::new(ruby.exception_arg_error(), IDNA_2008));
    }
    guarded(ruby, move || {
        let _ = Config::default().use_idna_2008_rules(value);
        Ok(())
    })
}

/// `Config::to_ascii(domain)` (`src/deprecated.rs:234-239`).
pub fn config_to_ascii(ruby: &Ruby, flags: Flags, domain: String) -> Result<String, Error> {
    guarded(ruby, move || {
        config(flags)
            .to_ascii(&domain)
            .map_err(|error| errors(ruby, &error))
    })
}

/// `Config::to_unicode(domain)` (`src/deprecated.rs:241-247`): the text,
/// and whether idna found no error.
pub fn config_to_unicode(
    ruby: &Ruby,
    flags: Flags,
    domain: String,
) -> Result<(String, bool), Error> {
    guarded(ruby, move || {
        let (text, result) = config(flags).to_unicode(&domain);
        Ok((text, result.is_ok()))
    })
}

/// `Idna::new(config).to_ascii(domain, &mut out)` (`src/deprecated.rs:76-106`),
/// with `out` starting as Ruby's String: the String after the call, and
/// whether it succeeded. idna checks the DNS length of all of `out`, not
/// only what it appended, so `out`'s earlier text counts.
pub fn idna_to_ascii(
    ruby: &Ruby,
    flags: Flags,
    domain: String,
    out: String,
) -> Result<(String, bool), Error> {
    guarded(ruby, move || {
        let mut out = out;
        let result = Idna::new(config(flags)).to_ascii(&domain, &mut out);
        Ok((out, result.is_ok()))
    })
}

/// `Idna::new(config).to_unicode(domain, &mut out)`
/// (`src/deprecated.rs:108-128`): the String after the call, and whether
/// it succeeded.
pub fn idna_to_unicode(
    ruby: &Ruby,
    flags: Flags,
    domain: String,
    out: String,
) -> Result<(String, bool), Error> {
    guarded(ruby, move || {
        let mut out = out;
        let result = Idna::new(config(flags)).to_unicode(&domain, &mut out);
        Ok((out, result.is_ok()))
    })
}

#[cfg(test)]
mod tests {
    use super::{config, IDNA_2008};
    use idna::Config;

    #[test]
    fn the_refusal_is_idnas_own_panic() {
        let payload = std::panic::catch_unwind(|| Config::default().use_idna_2008_rules(true))
            .err()
            .expect("idna panics");
        assert_eq!(crate::panic_of(&payload).0, IDNA_2008);
    }

    #[test]
    fn flags_reach_the_config() {
        assert_eq!(
            config((false, false, false, false))
                .to_ascii("a_b.com")
                .ok(),
            Some("a_b.com".to_owned())
        );
        assert!(config((true, false, false, false))
            .to_ascii("a_b.com")
            .is_err());
        assert_eq!(
            config((false, true, false, false)).to_ascii("faß.de").ok(),
            Some("fass.de".to_owned())
        );
        assert!(config((false, false, true, false))
            .to_ascii("a..b")
            .is_err());
        assert!(config((false, false, false, true))
            .to_ascii("-a.com")
            .is_err());
    }
}
