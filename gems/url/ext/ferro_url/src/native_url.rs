// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `Url`, `ParseOptions`, `PathSegmentsMut`, and slicing (url 2.5.8
//! `src/lib.rs`, `src/path_segments.rs`, `src/slicing.rs`).

use std::borrow::Cow;
use std::cell::RefCell;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::path::PathBuf;
#[cfg(feature = "test-hooks")]
use std::sync::Condvar;
use std::sync::{Mutex, MutexGuard, PoisonError};

use magnus::{
    function, prelude::*, typed_data::Obj, Error, RArray, RModule, RString, Ruby, Symbol, Value,
};
use url::{Position, Url};

use crate::form::{self, Encodings};
use crate::gvl;
use crate::iter::{self, NativeParse};
use crate::values::{host_to_ruby, origin_to_ruby, parse_error, syntax_violation_name};
use crate::{capture, error, guarded, panicked, Failure};

/// The Ruby `Ferro::Url::Native::Url`, which `Ferro::Url::Url` holds.
///
/// url's `Url` is `Send` and `Sync`, and a Ruby object may be reached from
/// several threads, so it sits behind a `Mutex`. The lock is held only
/// around url's own work, which touches nothing of Ruby's: no call, no
/// allocation, no class lookup (plan 005, decision 20). `read` and `mutate`
/// return Rust values and a `Failure`, and callers build Ruby values once
/// the lock is released.
#[magnus::wrap(
    class = "Ferro::Url::Native::Url",
    free_immediately,
    size,
    frozen_shareable
)]
pub struct NativeUrl(Mutex<Url>);

impl NativeUrl {
    pub const fn new(url: Url) -> Self {
        Self(Mutex::new(url))
    }

    /// The `Url`, recovering a lock a panic poisoned: `mutate` restores the
    /// value a panic interrupted before the lock is released, so the value
    /// is always whole.
    pub fn lock(&self) -> MutexGuard<'_, Url> {
        self.0.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// A copy of the `Url`, as `Clone` makes one.
    pub fn snapshot(&self) -> Url {
        self.lock().clone()
    }

    /// Runs `read` on the `Url` under `catch_unwind`, with the lock held
    /// only for the call. `read` touches nothing of Ruby's.
    pub fn read<T>(&self, read: impl FnOnce(&Url) -> T) -> Result<T, Failure> {
        let url = self.lock();
        capture(|| read(&url)).map_err(Failure::Panic)
    }

    /// Runs `change` on the `Url` under `catch_unwind`, with the lock held
    /// only for the call. If url panics, the `Url` is put back as it was, so
    /// no broken offsets survive (plan 005, decision 3). `change` touches
    /// nothing of Ruby's.
    pub fn mutate<T>(
        &self,
        change: impl FnOnce(&mut Url) -> Result<T, Failure>,
    ) -> Result<T, Failure> {
        let mut url = self.lock();
        change_or_restore(&mut url, change).unwrap_or_else(|panic| Err(Failure::Panic(panic)))
    }
}

/// The native URL `url` wraps, or `FrozenError` if `url` is frozen, through
/// magnus 0.9.3's `check_frozen` (`value.rs:1064-1072`), which works like
/// Ruby's `rb_check_frozen` but sets no `FrozenError#receiver`.
/// A frozen `Ferro::Url::Url` freezes its native URL, so this refuses a
/// change however the native URL is reached (plan 005, decision 3).
pub fn writable(url: &Obj<NativeUrl>) -> Result<&NativeUrl, Error> {
    url.check_frozen()?;
    Ok(url)
}

/// `Err(())` as a `Failure` naming `function` (plan 005, decision 6).
pub const fn unit(result: Result<(), ()>, function: &'static str) -> Result<(), Failure> {
    match result {
        Ok(()) => Ok(()),
        Err(()) => Err(Failure::Unit(function)),
    }
}

/// `ArgumentError` for a name the Ruby side never sends.
fn unknown(ruby: &Ruby, what: &str, name: &str) -> Error {
    Error::new(ruby.exception_arg_error(), format!("no {what} {name}"))
}

/// Runs `change` on `url` under `catch_unwind`, putting `url` back as it
/// was before when `change` panics.
fn change_or_restore<T>(
    url: &mut Url,
    change: impl FnOnce(&mut Url) -> T,
) -> Result<T, crate::Panic> {
    let before = url.clone();
    let outcome = capture(|| change(url));
    if outcome.is_err() {
        *url = before;
    }
    outcome
}

/// `Url::parse(input)` (`src/lib.rs:319-343`).
fn url_parse(ruby: &Ruby, input: String) -> Result<NativeUrl, Error> {
    guarded(ruby, move || {
        Url::parse(&input)
            .map(NativeUrl::new)
            .map_err(|error| parse_error(ruby, error))
    })
}

/// `Url::parse_with_params(input, pairs)` (`src/lib.rs:345-385`).
fn url_parse_with_params(
    ruby: &Ruby,
    input: String,
    pairs: Vec<(String, String)>,
) -> Result<NativeUrl, Error> {
    guarded(ruby, move || {
        Url::parse_with_params(&input, &pairs)
            .map(NativeUrl::new)
            .map_err(|error| parse_error(ruby, error))
    })
}

/// The first exception a Ruby callback raised during a parse, kept so the
/// callback can answer url and the exception be raised once url returns.
struct Failures(RefCell<Option<Error>>);

impl Failures {
    const fn new() -> Self {
        Self(RefCell::new(None))
    }

    fn failed(&self) -> bool {
        self.0.borrow().is_some()
    }

    fn keep(&self, failure: Error) {
        self.0.borrow_mut().get_or_insert(failure);
    }

    fn finish(self) -> Result<(), Error> {
        self.0.into_inner().map_or(Ok(()), Err)
    }
}

/// `ParseOptions::parse(input)` (`src/lib.rs:305-315`) with the options a
/// Ruby `ParseOptions` holds: a copy of the base URL, and the Ruby
/// callables for the encoding override and the syntax violations, which
/// the Ruby side wraps to take and return plain values (plan 005,
/// decision 10).
fn url_options_parse(
    ruby: &Ruby,
    input: String,
    base: Option<&NativeUrl>,
    encoding: Option<Value>,
    violation: Option<Value>,
) -> Result<NativeUrl, Error> {
    let base = base.map(NativeUrl::snapshot);
    let failures = Failures::new();
    let parsed = {
        let encode = form::encoder(|text| {
            let fallback = || Cow::Owned(text.as_bytes().to_vec());
            match encoding {
                Some(callable) if !failures.failed() => {
                    match callable.funcall::<_, _, RString>("call", (text,)) {
                        Ok(bytes) => Cow::Owned(bytes.to_bytes().to_vec()),
                        Err(failure) => {
                            failures.keep(failure);
                            fallback()
                        }
                    }
                }
                _ => fallback(),
            }
        });
        let report = |found: url::SyntaxViolation| {
            let Some(callable) = violation else { return };
            if failures.failed() {
                return;
            }
            if let Err(failure) =
                callable.funcall::<_, _, Value>("call", (syntax_violation_name(found),))
            {
                failures.keep(failure);
            }
        };
        guarded(ruby, move || {
            let encode: &dyn Fn(&str) -> Cow<'_, [u8]> = &encode;
            let report: &dyn Fn(url::SyntaxViolation) = &report;
            Ok(Url::options()
                .base_url(base.as_ref())
                .encoding_override(encoding.map(|_| encode))
                .syntax_violation_callback(violation.map(|_| report))
                .parse(&input))
        })?
    };
    failures.finish()?;
    parsed
        .map(NativeUrl::new)
        .map_err(|error| parse_error(ruby, error))
}

/// `join(input)` (`src/lib.rs:413-473`).
fn url_join(ruby: &Ruby, url: &NativeUrl, input: String) -> Result<NativeUrl, Error> {
    url.read(move |url| url.join(&input))
        .and_then(|joined| joined.map_err(Failure::Parse))
        .map(NativeUrl::new)
        .map_err(|failure| failure.into_error(ruby))
}

/// `make_relative(other)` (`src/lib.rs:475-605`). `other` is copied first,
/// since it may be the same `Url`, whose lock is held.
fn url_make_relative(
    ruby: &Ruby,
    url: &NativeUrl,
    other: &NativeUrl,
) -> Result<Option<String>, Error> {
    let other = other.snapshot();
    url.read(|url| url.make_relative(&other))
        .map_err(|failure| failure.into_error(ruby))
}

/// `Clone` (`src/lib.rs:227`).
fn url_clone(ruby: &Ruby, url: &NativeUrl) -> Result<NativeUrl, Error> {
    url.read(|url| NativeUrl::new(url.clone()))
        .map_err(|failure| failure.into_error(ruby))
}

/// `as_str` (`src/lib.rs:634-655`), which `Display`, `From<Url> for String`,
/// `AsRef<str>`, and `quirks::href` also return.
fn url_as_str(ruby: &Ruby, url: &NativeUrl) -> Result<String, Error> {
    url.read(|url| url.as_str().to_owned())
        .map_err(|failure| failure.into_error(ruby))
}

/// `Debug` (`src/lib.rs:2809-2826`), formatted by Rust.
fn url_debug(ruby: &Ruby, url: &NativeUrl) -> Result<String, Error> {
    url.read(|url| format!("{url:?}"))
        .map_err(|failure| failure.into_error(ruby))
}

/// `origin` (`src/lib.rs:811-885`).
fn url_origin(ruby: &Ruby, url: &NativeUrl) -> Result<RArray, Error> {
    let origin = url
        .read(Url::origin)
        .map_err(|failure| failure.into_error(ruby))?;
    Ok(origin_to_ruby(ruby, origin))
}

/// One of the getters that return a `&str`, by name.
fn url_str(ruby: &Ruby, url: &NativeUrl, name: Symbol) -> Result<String, Error> {
    let name = name.name()?;
    url.read(|url| {
        match name.as_ref() {
            "scheme" => Some(url.scheme()),
            "authority" => Some(url.authority()),
            "username" => Some(url.username()),
            "path" => Some(url.path()),
            _ => None,
        }
        .map(str::to_owned)
    })
    .map_err(|failure| failure.into_error(ruby))?
    .ok_or_else(|| unknown(ruby, "Url getter", &name))
}

/// One of the getters that return an `Option<&str>`, by name.
fn url_option_str(ruby: &Ruby, url: &NativeUrl, name: Symbol) -> Result<Option<String>, Error> {
    let name = name.name()?;
    url.read(|url| {
        match name.as_ref() {
            "password" => Ok(url.password()),
            "host_str" => Ok(url.host_str()),
            "domain" => Ok(url.domain()),
            "query" => Ok(url.query()),
            "fragment" => Ok(url.fragment()),
            _ => Err(()),
        }
        .map(|text| text.map(str::to_owned))
    })
    .map_err(|failure| failure.into_error(ruby))?
    .map_err(|()| unknown(ruby, "Url getter", &name))
}

/// One of the getters that return a `bool`, by name.
fn url_bool(ruby: &Ruby, url: &NativeUrl, name: Symbol) -> Result<bool, Error> {
    let name = name.name()?;
    url.read(|url| match name.as_ref() {
        "is_special" => Ok(url.is_special()),
        "has_authority" => Ok(url.has_authority()),
        "cannot_be_a_base" => Ok(url.cannot_be_a_base()),
        "has_host" => Ok(url.has_host()),
        _ => Err(()),
    })
    .map_err(|failure| failure.into_error(ruby))?
    .map_err(|()| unknown(ruby, "Url getter", &name))
}

/// `port` and `port_or_known_default` (`src/lib.rs:1244-1303`).
fn url_port(ruby: &Ruby, url: &NativeUrl, or_known_default: bool) -> Result<Option<u16>, Error> {
    url.read(|url| {
        if or_known_default {
            url.port_or_known_default()
        } else {
            url.port()
        }
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// `host` (`src/lib.rs:1170-1208`), copied out under the lock and turned
/// into Ruby values after it.
fn url_host(ruby: &Ruby, url: &NativeUrl) -> Result<Option<RArray>, Error> {
    let host = url
        .read(|url| url.host().map(|host| host.to_owned()))
        .map_err(|failure| failure.into_error(ruby))?;
    Ok(host.map(|host| host_to_ruby(ruby, &host)))
}

/// `path_segments` (`src/lib.rs:1400-1445`), collected.
fn url_path_segments(ruby: &Ruby, url: &NativeUrl) -> Result<Option<Vec<String>>, Error> {
    url.read(|url| {
        url.path_segments()
            .map(|segments| segments.map(str::to_owned).collect())
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// `query_pairs` (`src/lib.rs:1485-1511`): url's `Parse` over a copy of
/// the `Url`, taken under the lock.
fn url_query_pairs(url: &NativeUrl) -> NativeParse {
    iter::query_pairs(url.snapshot())
}

/// Whether url's `socket_addrs` would call its `default_port_number`: the
/// URL has a host and no port url knows (`src/lib.rs:1356-1360`).
fn url_socket_addrs_asks_for_port(ruby: &Ruby, url: &NativeUrl) -> Result<bool, Error> {
    url.read(|url| url.host().is_some() && url.port_or_known_default().is_none())
        .map_err(|failure| failure.into_error(ruby))
}

/// A resolved address as Ruby builds an `Addrinfo` from it: the IP, the
/// port, and an IPv6 scope id (plan 005, decision 12).
type Address = (String, u16, u32);

fn address(socket: SocketAddr) -> Address {
    match socket {
        SocketAddr::V4(v4) => (v4.ip().to_string(), v4.port(), 0),
        SocketAddr::V6(v6) => (v6.ip().to_string(), v6.port(), v6.scope_id()),
    }
}

/// `socket_addrs(|| default_port)` (`src/lib.rs:1305-1366`), on a thread of
/// its own while this one waits with the GVL released, so an interrupt
/// ends the wait (plan 005, decision 11). An `io::Error` raises the `Errno`
/// class of its OS code on Unix, and `IOError` with Rust's text otherwise.
fn url_socket_addrs(
    ruby: &Ruby,
    url: &NativeUrl,
    default_port: Option<u16>,
) -> Result<Vec<Address>, Error> {
    let url = url.snapshot();
    let outcome = gvl::in_background(ruby, move || {
        #[cfg(feature = "test-hooks")]
        wait_while_held();
        url.socket_addrs(|| default_port)
            .map(|addresses| addresses.into_iter().map(address).collect::<Vec<_>>())
            .map_err(|failure| (io_errno(&failure), failure.to_string()))
    })?;
    match outcome {
        Ok(Ok(addresses)) => Ok(addresses),
        Ok(Err((errno, message))) => Err(io_error(ruby, errno, message)),
        Err(payload) => Err(error(ruby, panicked(&crate::panic_of(&payload)))),
    }
}

/// The Ruby exception for an `io::Error`: the `Errno` class for `errno`,
/// or `IOError` with Rust's message.
fn io_error(ruby: &Ruby, errno: Option<i32>, message: String) -> Error {
    let exception = errno.map_or_else(
        || ruby.exception_io_error().new_instance((message,)),
        |errno| {
            ruby.exception_system_call_error()
                .new_instance((Option::<String>::None, errno))
        },
    );
    match exception {
        Ok(exception) => Error::from(exception),
        Err(failure) => failure,
    }
}

/// The `errno` of an `io::Error` on Unix, where Ruby's `Errno` classes
/// match it; `None` elsewhere, where Windows' codes are not errno values
/// (plan 002, decision 10).
#[cfg(unix)]
fn io_errno(failure: &std::io::Error) -> Option<i32> {
    failure.raw_os_error()
}

#[cfg(not(unix))]
const fn io_errno(_failure: &std::io::Error) -> Option<i32> {
    None
}

/// How many waits have run with the GVL released, for the tests. A hook:
/// only a build with the `test-hooks` feature has it (`Cargo.toml`).
#[cfg(feature = "test-hooks")]
fn gvl_releases() -> usize {
    gvl::RELEASES.load(std::sync::atomic::Ordering::Relaxed)
}

/// How many lookups have run on the calling thread, for the tests. A hook.
#[cfg(feature = "test-hooks")]
fn gvl_fallbacks() -> usize {
    gvl::FALLBACKS.load(std::sync::atomic::Ordering::Relaxed)
}

/// Whether lookups wait before they resolve, and the signal that they may
/// go on, for the tests (`gvl_hold_lookups`, a hook).
#[cfg(feature = "test-hooks")]
static HOLD: (Mutex<bool>, Condvar) = (Mutex::new(false), Condvar::new());

/// Waits, on the lookup's own thread, while the tests hold lookups. No
/// Ruby value is touched under the lock.
#[cfg(feature = "test-hooks")]
fn wait_while_held() {
    let (held, released) = &HOLD;
    let guard = held.lock().unwrap_or_else(PoisonError::into_inner);
    drop(
        released
            .wait_while(guard, |held| *held)
            .unwrap_or_else(PoisonError::into_inner),
    );
}

/// Holds every lookup that starts, or lets every held one go on, so the
/// tests decide when a `socket_addrs` of a name the system resolves
/// without the network, such as `localhost`, finishes, with no clock.
/// A hook.
#[cfg(feature = "test-hooks")]
fn gvl_hold_lookups(held: bool) -> bool {
    let (lock, released) = &HOLD;
    *lock.lock().unwrap_or_else(PoisonError::into_inner) = held;
    released.notify_all();
    held
}

/// Makes the lookup thread refuse to start, or start again, so the tests
/// reach the fallback that runs the lookup on the calling thread. A hook.
#[cfg(feature = "test-hooks")]
fn gvl_refuse_threads(refused: bool) -> bool {
    gvl::REFUSE_THREADS.store(refused, std::sync::atomic::Ordering::Relaxed);
    refused
}

/// `set_fragment`, `set_query` (`src/lib.rs:1559-1667`).
fn url_set_option_str(
    ruby: &Ruby,
    url: Obj<NativeUrl>,
    name: Symbol,
    value: Option<String>,
) -> Result<(), Error> {
    let url = writable(&url)?;
    let name = name.name()?.into_owned();
    if !matches!(name.as_str(), "set_fragment" | "set_query") {
        return Err(unknown(ruby, "Url setter", &name));
    }
    url.mutate(move |url| {
        if name == "set_fragment" {
            url.set_fragment(value.as_deref());
        } else {
            url.set_query(value.as_deref());
        }
        Ok(())
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// `set_path` (`src/lib.rs:1732-1790`).
fn url_set_path(ruby: &Ruby, url: Obj<NativeUrl>, path: String) -> Result<(), Error> {
    let url = writable(&url)?;
    url.mutate(move |url| {
        url.set_path(&path);
        Ok(())
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// `set_port` (`src/lib.rs:1819-1898`).
fn url_set_port(ruby: &Ruby, url: Obj<NativeUrl>, port: Option<u16>) -> Result<(), Error> {
    let url = writable(&url)?;
    url.mutate(|url| unit(url.set_port(port), "url::Url::set_port"))
        .map_err(|failure| failure.into_error(ruby))
}

/// `set_host` (`src/lib.rs:1939-2083`).
fn url_set_host(ruby: &Ruby, url: Obj<NativeUrl>, host: Option<String>) -> Result<(), Error> {
    let url = writable(&url)?;
    url.mutate(move |url| url.set_host(host.as_deref()).map_err(Failure::Parse))
        .map_err(|failure| failure.into_error(ruby))
}

/// `set_ip_host` (`src/lib.rs:2128-2177`), with the address as its family
/// (4 or 6) and number.
fn url_set_ip_host(
    ruby: &Ruby,
    url: Obj<NativeUrl>,
    family: u8,
    number: u128,
) -> Result<(), Error> {
    let url = writable(&url)?;
    let address = match family {
        4 => IpAddr::V4(Ipv4Addr::from(u32::try_from(number).map_err(|_| {
            Error::new(ruby.exception_range_error(), "an IPv4 address is 32 bits")
        })?)),
        6 => IpAddr::V6(Ipv6Addr::from(number)),
        _ => {
            return Err(Error::new(
                ruby.exception_arg_error(),
                format!("no IP family {family}"),
            ))
        }
    };
    url.mutate(|url| unit(url.set_ip_host(address), "url::Url::set_ip_host"))
        .map_err(|failure| failure.into_error(ruby))
}

/// `set_password` (`src/lib.rs:2179-2262`).
fn url_set_password(
    ruby: &Ruby,
    url: Obj<NativeUrl>,
    password: Option<String>,
) -> Result<(), Error> {
    let url = writable(&url)?;
    url.mutate(move |url| {
        unit(
            url.set_password(password.as_deref()),
            "url::Url::set_password",
        )
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// `set_username` and `set_scheme` (`src/lib.rs:2264-2511`).
fn url_set_str(ruby: &Ruby, url: Obj<NativeUrl>, name: Symbol, value: String) -> Result<(), Error> {
    let url = writable(&url)?;
    let name = name.name()?.into_owned();
    if !matches!(name.as_str(), "set_username" | "set_scheme") {
        return Err(unknown(ruby, "Url setter", &name));
    }
    url.mutate(move |url| {
        if name == "set_username" {
            unit(url.set_username(&value), "url::Url::set_username")
        } else {
            unit(url.set_scheme(&value), "url::Url::set_scheme")
        }
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// One `PathSegmentsMut` method (`src/path_segments.rs:77-267`), or
/// `None` for `path_segments_mut()` alone.
pub enum PathOperation {
    None,
    Clear,
    PopIfEmpty,
    Pop,
    Push(String),
    Extend(Vec<String>),
}

impl PathOperation {
    /// The operation a Ruby `[name, args...]` names.
    pub fn from_ruby(ruby: &Ruby, operation: RArray) -> Result<Self, Error> {
        let name: Symbol = operation.entry(0)?;
        Ok(match name.name()?.as_ref() {
            "none" => Self::None,
            "clear" => Self::Clear,
            "pop_if_empty" => Self::PopIfEmpty,
            "pop" => Self::Pop,
            "push" => Self::Push(operation.entry(1)?),
            "extend" => Self::Extend(operation.entry(1)?),
            other => return Err(unknown(ruby, "PathSegmentsMut method", other)),
        })
    }

    /// Runs the operation on `path`, through url's own method.
    pub fn apply(&self, path: &mut url::PathSegmentsMut<'_>) {
        match self {
            Self::None => {}
            Self::Clear => {
                path.clear();
            }
            Self::PopIfEmpty => {
                path.pop_if_empty();
            }
            Self::Pop => {
                path.pop();
            }
            Self::Push(segment) => {
                path.push(segment);
            }
            Self::Extend(segments) => {
                path.extend(segments);
            }
        }
    }
}

/// `path_segments_mut` (`src/lib.rs:1792-1802`) and one
/// `PathSegmentsMut` operation (`src/path_segments.rs:77-267`), dropped
/// at once, which puts back the rest of the URL (plan 005, decision 8).
/// `[:none]` only asks for it, raising `Error` for a cannot-be-a-base URL.
fn url_path_segments_mut(ruby: &Ruby, url: Obj<NativeUrl>, operation: RArray) -> Result<(), Error> {
    let url = writable(&url)?;
    let operation = PathOperation::from_ruby(ruby, operation)?;
    url.mutate(|url| {
        let Ok(mut path) = url.path_segments_mut() else {
            return Err(Failure::Unit("url::Url::path_segments_mut"));
        };
        operation.apply(&mut path);
        Ok(())
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// `PathSegmentsMut`'s derived `Debug` (`src/path_segments.rs:41`) for the
/// guard a Ruby `PathSegmentsMut` stands for: a real guard made on a copy
/// of `start`, the URL as it was when the Ruby one was made, with the
/// Ruby one's `operations` run on it, so the fields a long-lived guard
/// keeps (`old_after_path_position` among them) are Rust's own.
///
/// url's `Debug` for a guard over a URL with a query or a fragment reads
/// offsets the guard has cut away, and panics or reads the wrong bytes.
/// Where it would panic, `guard_debug_panic` says so first and this raises
/// `ArgumentError` with std's text; where it reads the wrong bytes, this
/// answers them, as url does (plan 005, decisions 17 and 21).
fn path_segments_mut_debug(
    ruby: &Ruby,
    start: &NativeUrl,
    operations: RArray,
) -> Result<String, Error> {
    let operations = operations
        .into_iter()
        .map(|operation| PathOperation::from_ruby(ruby, RArray::try_convert(operation)?))
        .collect::<Result<Vec<_>, Error>>()?;
    let mut url = start.snapshot();
    let debug = capture(move || {
        if let Some(panic) = guard_debug_panic(&url, &operations) {
            return Some(Err(panic));
        }
        let mut path = url.path_segments_mut().ok()?;
        for operation in &operations {
            operation.apply(&mut path);
        }
        Some(Ok(format!("{path:?}")))
    });
    match debug {
        Ok(Some(Ok(text))) => Ok(text),
        Ok(Some(Err(panic))) => Err(Error::new(ruby.exception_arg_error(), panic)),
        Ok(None) => Err(Failure::Unit("url::Url::path_segments_mut").into_error(ruby)),
        Err(panic) => Err(error(ruby, panicked(&panic))),
    }
}

/// What url's `Debug` panics with for a `PathSegmentsMut` made on `start`
/// with `operations` run on it, or `None` where it formats, rightly or
/// not, or where `start` is cannot-be-a-base.
///
/// `path_segments::new` cuts the query and fragment from the serialization
/// with `take_after_path`, which keeps `query_start` and `fragment_start`
/// (`src/lib.rs:1721-1730`), and no `PathSegmentsMut` method moves them
/// (`src/path_segments.rs:77-267`). The guard's derived `Debug`
/// (`src/path_segments.rs:41`) formats `Url`'s `Debug`, whose fields
/// (`src/lib.rs:2810-2825`) slice the serialization, in this order, at
/// `path` (`path_start..` the query or fragment start, `:1391-1398`),
/// `query` (`query_start + 1..` the fragment start or the end,
/// `:1471-1483`), and `fragment` (`fragment_start + 1..`, `:1545-1550`).
/// The fields before `path` read only offsets before the path, which the
/// guard keeps. The offsets come from `start` through `Position`, which
/// reads them on a whole URL (`src/slicing.rs:185-205`), and the
/// serialization the guard holds from a copy of `start` without its query
/// and fragment, the bytes `take_after_path` leaves, with `operations` run
/// on it. The first slice std refuses is url's panic in a release build;
/// a debug build trips url's `debug_assert!`s on `query` and `fragment`
/// first, but the gem is built in release.
pub fn guard_debug_panic(start: &Url, operations: &[PathOperation]) -> Option<String> {
    let query_start = start.query().map(|_| offset(start, Position::AfterPath));
    let fragment_start = start
        .fragment()
        .map(|_| offset(start, Position::AfterQuery));
    let cut = query_start.or(fragment_start)?;
    let mut guarded = start.clone();
    guarded.set_query(None);
    guarded.set_fragment(None);
    {
        let mut path = guarded.path_segments_mut().ok()?;
        for operation in operations {
            operation.apply(&mut path);
        }
    }
    let text = guarded.as_str();
    let len = text.len();
    slice_panic(text, offset(start, Position::BeforePath), cut)
        .or_else(|| {
            query_start
                .and_then(|query| slice_panic(text, query + 1, fragment_start.unwrap_or(len)))
        })
        .or_else(|| fragment_start.and_then(|fragment| slice_panic(text, fragment + 1, len)))
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: The Rust Project Developers
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic text of std's str slicing,
//   slice_error_fail_rt in library/core/src/str/mod.rs

/// What std panics with for `&text[begin..end]`, or `None` where the slice
/// is valid. `text[begin..]` panics as `text[begin..text.len()]` does.
/// The text and the order of its checks are std's `slice_error_fail_rt`
/// (`library/core/src/str/mod.rs`), which a test drives against the
/// toolchain's own panic.
pub fn slice_panic(text: &str, begin: usize, end: usize) -> Option<String> {
    if text.get(begin..end).is_some() {
        return None;
    }
    let len = text.len();
    Some(if begin > len {
        format!("start byte index {begin} is out of bounds for string of length {len}")
    } else if end > len {
        format!("end byte index {end} is out of bounds for string of length {len}")
    } else if begin > end {
        format!("byte range starts at {begin} but ends at {end}")
    } else {
        let (side, index) = if text.is_char_boundary(begin) {
            ("end", end)
        } else {
            ("start", begin)
        };
        let range = text.floor_char_boundary(index)..text.ceil_char_boundary(index);
        let inside = text[range.clone()].chars().next().unwrap_or_default();
        format!(
            "{side} byte index {index} is not a char boundary; it is inside {inside:?} (bytes {range:?} of string)"
        )
    })
}

// SPDX-SnippetEnd

/// `query_pairs_mut` (`src/lib.rs:1669-1719`) and one `Serializer`
/// operation over its `UrlQuery`, dropped at once, which puts the
/// fragment back (plan 005, decision 8).
fn url_query_pairs_mut(
    ruby: &Ruby,
    url: Obj<NativeUrl>,
    operation: RArray,
    encodings: Option<RArray>,
) -> Result<(), Error> {
    let url = writable(&url)?;
    let operation = form::Operation::from_ruby(ruby, operation)?;
    let encodings = Encodings::from_ruby(encodings)?;
    url.mutate(|url| {
        let encode = encodings.encoder();
        let mut serializer = url.query_pairs_mut();
        if encodings.is_some() {
            serializer.encoding_override(Some(&encode));
        }
        operation.apply(&mut serializer);
        drop(serializer);
        encodings.finish().map_err(Failure::Message)
    })
    .map_err(|failure| failure.into_error(ruby))
}

/// A path from Ruby: its bytes on Unix.
#[cfg(unix)]
fn path_from_ruby(path: RString) -> PathBuf {
    use std::os::unix::ffi::OsStringExt;
    PathBuf::from(std::ffi::OsString::from_vec(path.to_bytes().to_vec()))
}

/// A path from Ruby, which Windows takes as UTF-8.
#[cfg(not(unix))]
fn path_from_ruby(path: RString) -> Result<PathBuf, Error> {
    path.to_string().map(PathBuf::from)
}

/// A path for Ruby, in the file system's encoding on Unix.
#[cfg(unix)]
fn path_to_ruby(ruby: &Ruby, path: &std::path::Path) -> RString {
    use std::os::unix::ffi::OsStrExt;
    ruby.enc_str_new(path.as_os_str().as_bytes(), ruby.filesystem_encoding())
}

/// A path for Ruby: UTF-8 on Windows, where url builds it from UTF-8
/// (`src/lib.rs:3126-3192`).
#[cfg(not(unix))]
fn path_to_ruby(ruby: &Ruby, path: &std::path::Path) -> RString {
    ruby.str_new(&path.to_string_lossy())
}

/// `Url::from_file_path` and `from_directory_path` (`src/lib.rs:2513-2607`).
fn url_from_path(ruby: &Ruby, path: RString, directory: bool) -> Result<NativeUrl, Error> {
    #[cfg(unix)]
    let path = path_from_ruby(path);
    #[cfg(not(unix))]
    let path = path_from_ruby(path)?;
    guarded(ruby, move || {
        let (url, function) = if directory {
            (
                Url::from_directory_path(&path),
                "url::Url::from_directory_path",
            )
        } else {
            (Url::from_file_path(&path), "url::Url::from_file_path")
        };
        url.map(NativeUrl::new)
            .map_err(|()| Failure::Unit(function).into_error(ruby))
    })
}

/// `to_file_path` (`src/lib.rs:2694-2758`).
fn url_to_file_path(ruby: &Ruby, url: &NativeUrl) -> Result<RString, Error> {
    let path = url
        .read(Url::to_file_path)
        .map_err(|failure| failure.into_error(ruby))?;
    path.map(|path| path_to_ruby(ruby, &path))
        .map_err(|()| Failure::Unit("url::Url::to_file_path").into_error(ruby))
}

/// The `Position` named `name` (`src/slicing.rs:104-122`).
pub fn position(ruby: &Ruby, name: Symbol) -> Result<Position, Error> {
    Ok(match name.name()?.as_ref() {
        "BeforeScheme" => Position::BeforeScheme,
        "AfterScheme" => Position::AfterScheme,
        "BeforeUsername" => Position::BeforeUsername,
        "AfterUsername" => Position::AfterUsername,
        "BeforePassword" => Position::BeforePassword,
        "AfterPassword" => Position::AfterPassword,
        "BeforeHost" => Position::BeforeHost,
        "AfterHost" => Position::AfterHost,
        "BeforePort" => Position::BeforePort,
        "AfterPort" => Position::AfterPort,
        "BeforePath" => Position::BeforePath,
        "AfterPath" => Position::AfterPath,
        "BeforeQuery" => Position::BeforeQuery,
        "AfterQuery" => Position::AfterQuery,
        "BeforeFragment" => Position::BeforeFragment,
        "AfterFragment" => Position::AfterFragment,
        other => {
            return Err(Error::new(
                ruby.exception_arg_error(),
                format!("no Position variant {other}"),
            ))
        }
    })
}

/// The byte offset of `position` in `url`, found through url's own
/// `Index<RangeTo<Position>>`, which cannot panic.
fn offset(url: &Url, position: Position) -> usize {
    url[..position].len()
}

/// What Rust's string slicing panics with when `url[start..end]` runs
/// backward, as url's `Index<Range<Position>>` slices its serialization
/// (`src/slicing.rs:34-39`), or `None` (plan 005, decision 15). The text
/// is std's, which a test drives.
pub fn backward(url: &Url, start: Position, end: Position) -> Option<String> {
    let (from, to) = (offset(url, start), offset(url, end));
    (from > to).then(|| format!("byte range starts at {from} but ends at {to}"))
}

/// `url[start..end]` through url's four `Index` impls
/// (`src/slicing.rs:13-39`), `None` standing for an open end.
fn url_slice(
    ruby: &Ruby,
    url: &NativeUrl,
    start: Option<Symbol>,
    end: Option<Symbol>,
) -> Result<String, Error> {
    let start = start.map(|name| position(ruby, name)).transpose()?;
    let end = end.map(|name| position(ruby, name)).transpose()?;
    url.read(|url| match (start, end) {
        (None, None) => Ok(url[..].to_owned()),
        (Some(start), None) => Ok(url[start..].to_owned()),
        (None, Some(end)) => Ok(url[..end].to_owned()),
        (Some(start), Some(end)) => {
            backward(url, start, end).map_or_else(|| Ok(url[start..end].to_owned()), Err)
        }
    })
    .map_err(|failure| failure.into_error(ruby))?
    .map_err(|message| Error::new(ruby.exception_range_error(), message))
}

/// The test hooks, private singleton methods of `Native` that only a build
/// with the `test-hooks` feature has (`Cargo.toml`), so a gem built without
/// the option has none, and `rbs:parity` needs no signature for them.
/// `Native::TEST_HOOKS` marks such a build, so the packaging check refuses
/// any package that has it.
#[cfg(feature = "test-hooks")]
fn define_test_hooks(native: RModule) -> Result<(), Error> {
    native.const_set("TEST_HOOKS", true)?;
    let hooks = native.singleton_class()?;
    hooks.define_private_method("gvl_releases", function!(gvl_releases, 0))?;
    hooks.define_private_method("gvl_fallbacks", function!(gvl_fallbacks, 0))?;
    hooks.define_private_method("gvl_hold_lookups", function!(gvl_hold_lookups, 1))?;
    hooks.define_private_method("gvl_refuse_threads", function!(gvl_refuse_threads, 1))?;
    Ok(())
}

pub fn define(native: RModule) -> Result<(), Error> {
    #[cfg(feature = "test-hooks")]
    define_test_hooks(native)?;
    native.define_singleton_method("url_parse", function!(url_parse, 1))?;
    native.define_singleton_method("url_parse_with_params", function!(url_parse_with_params, 2))?;
    native.define_singleton_method("url_options_parse", function!(url_options_parse, 4))?;
    native.define_singleton_method("url_join", function!(url_join, 2))?;
    native.define_singleton_method("url_make_relative", function!(url_make_relative, 2))?;
    native.define_singleton_method("url_clone", function!(url_clone, 1))?;
    native.define_singleton_method("url_as_str", function!(url_as_str, 1))?;
    native.define_singleton_method("url_debug", function!(url_debug, 1))?;
    native.define_singleton_method("url_origin", function!(url_origin, 1))?;
    native.define_singleton_method("url_str", function!(url_str, 2))?;
    native.define_singleton_method("url_option_str", function!(url_option_str, 2))?;
    native.define_singleton_method("url_bool", function!(url_bool, 2))?;
    native.define_singleton_method("url_port", function!(url_port, 2))?;
    native.define_singleton_method("url_host", function!(url_host, 1))?;
    native.define_singleton_method("url_path_segments", function!(url_path_segments, 1))?;
    native.define_singleton_method("url_query_pairs", function!(url_query_pairs, 1))?;
    native.define_singleton_method(
        "url_socket_addrs_asks_for_port",
        function!(url_socket_addrs_asks_for_port, 1),
    )?;
    native.define_singleton_method("url_socket_addrs", function!(url_socket_addrs, 2))?;
    native.define_singleton_method("url_set_option_str", function!(url_set_option_str, 3))?;
    native.define_singleton_method("url_set_path", function!(url_set_path, 2))?;
    native.define_singleton_method("url_set_port", function!(url_set_port, 2))?;
    native.define_singleton_method("url_set_host", function!(url_set_host, 2))?;
    native.define_singleton_method("url_set_ip_host", function!(url_set_ip_host, 3))?;
    native.define_singleton_method("url_set_password", function!(url_set_password, 2))?;
    native.define_singleton_method("url_set_str", function!(url_set_str, 3))?;
    native.define_singleton_method("url_path_segments_mut", function!(url_path_segments_mut, 2))?;
    native.define_singleton_method(
        "path_segments_mut_debug",
        function!(path_segments_mut_debug, 2),
    )?;
    native.define_singleton_method("url_query_pairs_mut", function!(url_query_pairs_mut, 3))?;
    native.define_singleton_method("url_from_path", function!(url_from_path, 2))?;
    native.define_singleton_method("url_to_file_path", function!(url_to_file_path, 1))?;
    native.define_singleton_method("url_slice", function!(url_slice, 3))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{backward, change_or_restore, guard_debug_panic, slice_panic, PathOperation};
    use url::{Position, Url};

    #[test]
    fn a_backward_slice_is_refused_with_the_panic_rusts_slicing_raises() {
        let url = Url::parse("https://example.com/a?b#c").expect("a URL");
        assert!(backward(&url, Position::BeforePath, Position::AfterQuery).is_none());
        // Without a password, both positions are the same byte.
        assert!(backward(&url, Position::AfterPassword, Position::BeforePassword).is_none());
        let message = backward(&url, Position::AfterPath, Position::BeforePath).expect("refused");
        assert_eq!(message, "byte range starts at 21 but ends at 19");
        let payload =
            std::panic::catch_unwind(|| url[Position::AfterPath..Position::BeforePath].len())
                .expect_err("Rust's slicing panics where the gem refuses");
        assert_eq!(crate::panic_of(&payload).0, message);
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the Debug text of url 2.5.8's PathSegmentsMut
    //   (src/path_segments.rs:41-47), which this test pins

    #[test]
    fn a_replayed_guard_debugs_as_the_long_lived_one() {
        let mut url = Url::parse("https://example.com/a").expect("a URL");
        let mut live = url.path_segments_mut().expect("a base");
        live.push("d");
        let expected = format!("{live:?}");
        drop(live);
        assert_eq!(
            expected,
            "PathSegmentsMut { url: Url { scheme: \"https\", cannot_be_a_base: false, username: \"\", \
             password: None, host: Some(Domain(\"example.com\")), port: None, path: \"/a/d\", query: None, \
             fragment: None }, after_first_slash: 20, after_path: \"\", old_after_path_position: 21 }"
        );
        let mut start = Url::parse("https://example.com/a").expect("a URL");
        let mut replayed = start.path_segments_mut().expect("a base");
        PathOperation::Push("d".to_owned()).apply(&mut replayed);
        assert_eq!(format!("{replayed:?}"), expected);
    }

    // SPDX-SnippetEnd

    /// The message `catch_unwind` takes from `operation`'s panic, or `None`.
    fn panic_text<T>(operation: impl FnOnce() -> T) -> Option<String> {
        std::panic::catch_unwind(std::panic::AssertUnwindSafe(operation))
            .err()
            .map(|payload| crate::panic_of(&payload).0)
    }

    #[test]
    fn slice_panic_words_stds_own_panic() {
        let cases: [(&str, usize, usize); 9] = [
            ("abcdef", 1, 4),
            ("abcdef", 6, 6),
            ("abcdef", 7, 9),
            ("abcdef", 2, 9),
            ("abcdef", 5, 3),
            ("a\u{e9}b", 2, 3),
            ("a\u{e9}b", 0, 2),
            ("a\u{1f600}", 3, 5),
            ("a\u{e9}", 9, 1),
        ];
        for (text, begin, end) in cases {
            assert_eq!(
                slice_panic(text, begin, end),
                panic_text(|| text[begin..end].len()),
                "{text:?}[{begin}..{end}]"
            );
            assert_eq!(
                slice_panic(text, begin, text.len()),
                panic_text(|| text[begin..].len()),
                "{text:?}[{begin}..]"
            );
        }
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2013-2025 The rust-url developers
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the Debug text of url 2.5.8's PathSegmentsMut
    //   (src/path_segments.rs:41-47) over a URL with a query or fragment,
    //   which this test pins

    /// Where url's `Debug` reads a field, so which `debug_assert!` a debug
    /// build trips before the release build's slice.
    #[derive(PartialEq, Eq)]
    enum Field {
        Path,
        QueryOrFragment,
        None,
    }

    #[test]
    fn guard_debug_panic_predicts_urls_own_debug() {
        let cases = [
            (
                "https://example.com/a?b",
                vec![],
                Field::QueryOrFragment,
                Some("start byte index 22 is out of bounds for string of length 21"),
            ),
            (
                "https://example.com/abc?q",
                vec![PathOperation::Pop],
                Field::Path,
                Some("end byte index 23 is out of bounds for string of length 20"),
            ),
            (
                "https://example.com/abc#f",
                vec![PathOperation::Clear],
                Field::Path,
                Some("end byte index 23 is out of bounds for string of length 20"),
            ),
            (
                "https://example.com/a#c",
                vec![],
                Field::QueryOrFragment,
                Some("start byte index 22 is out of bounds for string of length 21"),
            ),
            (
                "https://example.com/a?b#c",
                vec![PathOperation::Push("x".to_owned())],
                Field::QueryOrFragment,
                Some("start byte index 24 is out of bounds for string of length 23"),
            ),
            (
                "https://example.com/a?bcd#e",
                vec![PathOperation::Push("x".to_owned())],
                Field::QueryOrFragment,
                Some("end byte index 25 is out of bounds for string of length 23"),
            ),
            (
                "https://example.com/a?b",
                vec![PathOperation::Push("xyz".to_owned())],
                Field::QueryOrFragment,
                None,
            ),
            (
                "https://example.com/a",
                vec![PathOperation::Push("d".to_owned())],
                Field::None,
                None,
            ),
        ];
        for (input, operations, field, expected) in cases {
            let start = Url::parse(input).expect("a URL");
            let predicted = guard_debug_panic(&start, &operations);
            assert_eq!(predicted.as_deref(), expected, "{input}");
            let mut url = start.clone();
            let real = panic_text(|| {
                let mut path = url.path_segments_mut().expect("a base");
                for operation in &operations {
                    operation.apply(&mut path);
                }
                format!("{path:?}")
            });
            // url's `debug_assert!(self.byte_at(..) == ..)` in `query` and
            // `fragment` (src/lib.rs:1475-1479, :1547) panics before their
            // slice in a debug build, as `cargo test` builds; `path` has
            // none. So the release build's panic is compared wherever a
            // debug build reaches it, and everywhere under `--release`.
            if cfg!(debug_assertions) && field == Field::QueryOrFragment {
                assert!(
                    real.is_some(),
                    "{input}: a debug build trips url's debug_assert!"
                );
            } else {
                assert_eq!(real, predicted, "{input}");
            }
        }
    }

    // SPDX-SnippetEnd

    #[test]
    fn a_panic_mid_mutation_puts_the_url_back() {
        let mut url = Url::parse("https://example.com/").expect("a URL");
        let outcome = change_or_restore(&mut url, |url| {
            url.set_path("/changed");
            panic!("mid-change");
        });
        assert!(outcome.is_err());
        assert_eq!(url.as_str(), "https://example.com/");

        let changed = change_or_restore(&mut url, |url| url.set_path("/kept"));
        assert!(changed.is_ok());
        assert_eq!(url.as_str(), "https://example.com/kept");
    }
}
