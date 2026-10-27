// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! url's `quirks` module, the WHATWG URL API's getters and setters (url
//! 2.5.8 `src/quirks.rs`; plan 005, decision 7).

use magnus::{function, prelude::*, Error, RModule, Ruby, Symbol};
use url::quirks;

use crate::native_url::{unit, NativeUrl};
use crate::{guarded, Failure};

/// `quirks::domain_to_ascii` (`src/quirks.rs:62-68`).
fn quirks_domain_to_ascii(ruby: &Ruby, domain: String) -> Result<String, Error> {
    guarded(ruby, move || Ok(quirks::domain_to_ascii(&domain)))
}

/// `quirks::domain_to_unicode` (`src/quirks.rs:70-79`).
fn quirks_domain_to_unicode(ruby: &Ruby, domain: String) -> Result<String, Error> {
    guarded(ruby, move || Ok(quirks::domain_to_unicode(&domain)))
}

/// One of the getters, by name (`src/quirks.rs:81-316`).
fn quirks_get(ruby: &Ruby, url: &NativeUrl, name: Symbol) -> Result<String, Error> {
    let name = name.name()?;
    url.read(|url| {
        Some(match name.as_ref() {
            "href" => quirks::href(url).to_owned(),
            "origin" => quirks::origin(url),
            "protocol" => quirks::protocol(url).to_owned(),
            "username" => quirks::username(url).to_owned(),
            "password" => quirks::password(url).to_owned(),
            "host" => quirks::host(url).to_owned(),
            "hostname" => quirks::hostname(url).to_owned(),
            "port" => quirks::port(url).to_owned(),
            "pathname" => quirks::pathname(url).to_owned(),
            "search" => quirks::search(url).to_owned(),
            "hash" => quirks::hash(url).to_owned(),
            _ => return None,
        })
    })
    .map_err(|failure| failure.into_error(ruby))?
    .ok_or_else(|| {
        Error::new(
            ruby.exception_arg_error(),
            format!("no quirks getter {name}"),
        )
    })
}

/// The setters, by name.
const SETTERS: [&str; 10] = [
    "set_href",
    "set_protocol",
    "set_username",
    "set_password",
    "set_host",
    "set_hostname",
    "set_port",
    "set_pathname",
    "set_search",
    "set_hash",
];

/// One of the setters, by name (`src/quirks.rs:86-328`). `set_href` raises
/// `ParseError`; the setters that return `Result<(), ()>` raise `Error`.
fn quirks_set(ruby: &Ruby, url: &NativeUrl, name: Symbol, value: String) -> Result<(), Error> {
    let name = name.name()?.into_owned();
    if !SETTERS.contains(&name.as_str()) {
        return Err(Error::new(
            ruby.exception_arg_error(),
            format!("no quirks setter {name}"),
        ));
    }
    url.mutate(move |url| match name.as_str() {
        "set_href" => quirks::set_href(url, &value).map_err(Failure::Parse),
        "set_protocol" => unit(
            quirks::set_protocol(url, &value),
            "url::quirks::set_protocol",
        ),
        "set_username" => unit(
            quirks::set_username(url, &value),
            "url::quirks::set_username",
        ),
        "set_password" => unit(
            quirks::set_password(url, &value),
            "url::quirks::set_password",
        ),
        "set_host" => unit(quirks::set_host(url, &value), "url::quirks::set_host"),
        "set_hostname" => unit(
            quirks::set_hostname(url, &value),
            "url::quirks::set_hostname",
        ),
        "set_port" => unit(quirks::set_port(url, &value), "url::quirks::set_port"),
        "set_pathname" => {
            quirks::set_pathname(url, &value);
            Ok(())
        }
        "set_search" => {
            quirks::set_search(url, &value);
            Ok(())
        }
        _ => {
            quirks::set_hash(url, &value);
            Ok(())
        }
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// `quirks::InternalComponents`' fields, in declaration order
/// (`src/quirks.rs:31-42`).
type Components = (
    u32,
    u32,
    u32,
    u32,
    Option<u16>,
    u32,
    Option<u32>,
    Option<u32>,
);

/// `quirks::internal_components` (`src/quirks.rs:44-60`).
fn quirks_internal_components(ruby: &Ruby, url: &NativeUrl) -> Result<Components, Error> {
    url.read(|url| {
        let parts = quirks::internal_components(url);
        (
            parts.scheme_end,
            parts.username_end,
            parts.host_start,
            parts.host_end,
            parts.port,
            parts.path_start,
            parts.query_start,
            parts.fragment_start,
        )
    })
    .map_err(|failure| failure.into_error(ruby))
}

pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method(
        "quirks_domain_to_ascii",
        function!(quirks_domain_to_ascii, 1),
    )?;
    native.define_singleton_method(
        "quirks_domain_to_unicode",
        function!(quirks_domain_to_unicode, 1),
    )?;
    native.define_singleton_method("quirks_get", function!(quirks_get, 2))?;
    native.define_singleton_method("quirks_set", function!(quirks_set, 3))?;
    native.define_singleton_method(
        "quirks_internal_components",
        function!(quirks_internal_components, 1),
    )?;
    Ok(())
}
