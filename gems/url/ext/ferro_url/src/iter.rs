// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `form_urlencoded`'s iterators, `Parse` and `ByteSerialize`
//! (`form_urlencoded` 1.2.2 `src/lib.rs:31-172`), held by Ruby objects that
//! call `next` one item at a time (ADR 001, 2026-11-05: an iterator type is
//! a class with `next`, `each`, and `Enumerable`; plan 005, decision 9).
//!
//! Each iterator borrows the bytes it reads, and a Ruby object outlives the
//! call that made it, so the bytes travel with the iterator in `Owned`.
//! Each item is copied into an owned `String` before it leaves, so nothing
//! borrowed escapes.

use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use form_urlencoded::{ByteSerialize, Parse};
use magnus::{function, prelude::*, Error, RModule, RString, Ruby};
use url::Url;

use crate::{capture, error, panicked};

/// An iterator together with what it borrows from.
///
/// `iter` is declared first, so it is dropped before `owner`.
pub struct Owned<I> {
    iter: I,
    owner: Arc<dyn Send + Sync>,
}

impl<I> Owned<I> {
    /// The iterator `make` builds over `owner`, kept with `owner`.
    ///
    /// # Safety
    ///
    /// `make` is handed a `&'static O` that lives only as long as `Self`,
    /// so it must not let that borrow escape: it may only build the
    /// iterator, and must not store the reference, or anything borrowed
    /// from it, anywhere but in the `I` it returns. `I` must not hand the
    /// borrow out either, since `Self` keeps `I` private and returns only
    /// owned values. The iterators here, `Parse` and `ByteSerialize`, hold
    /// just the slice (`form_urlencoded` 1.2.2 `src/lib.rs:43-46`,
    /// `:126-129`).
    #[allow(unsafe_code)]
    pub unsafe fn new<O: Send + Sync + 'static>(
        owner: Arc<O>,
        make: impl FnOnce(&'static O) -> I,
    ) -> Self {
        // SAFETY: `Arc::as_ptr` points at the value inside the `Arc`'s
        // allocation, which neither moves nor is freed while a strong count
        // remains (std's `Arc::as_ptr` docs: "The pointer is valid as long
        // as there are strong counts"). `Self` keeps a strong count in
        // `owner` for as long as `iter` exists, and drops `iter` first,
        // since fields drop in declaration order. The value is never
        // changed: an `Arc` gives only shared access, and the owners here,
        // a `Vec<u8>` and a `Url`, have no interior mutability. The
        // `'static` borrow never leaves `Self`: the caller promises `make`
        // only builds the iterator (this function's `# Safety`), the fields
        // are private, and every method returns owned values.
        #[allow(unsafe_code)]
        let borrowed: &'static O = unsafe { &*Arc::as_ptr(&owner) };
        let iter = make(borrowed);
        Self { iter, owner }
    }
}

impl<I: Copy> Owned<I> {
    /// A copy that shares the bytes and starts where this one is, as a
    /// `Copy` iterator's copy does.
    fn copy(&self) -> Self {
        Self {
            iter: self.iter,
            owner: Arc::clone(&self.owner),
        }
    }
}

impl Owned<Parse<'static>> {
    /// The next pair, owned.
    fn next_pair(&mut self) -> Option<(String, String)> {
        self.iter
            .next()
            .map(|(name, value)| (name.into_owned(), value.into_owned()))
    }
}

impl Owned<ByteSerialize<'static>> {
    /// The next slice, owned.
    fn next_str(&mut self) -> Option<String> {
        self.iter.next().map(str::to_owned)
    }

    /// `ByteSerialize`'s `size_hint` (`src/lib.rs:165-171`).
    fn size_hint(&self) -> (usize, Option<usize>) {
        self.iter.size_hint()
    }

    /// `ByteSerialize`'s derived `Debug` (`src/lib.rs:126`).
    fn debug(&self) -> String {
        format!("{:?}", self.iter)
    }
}

/// The Ruby `Ferro::Url::Native::Parse`, which
/// `Ferro::Url::FormUrlencoded::Parse` holds.
#[magnus::wrap(class = "Ferro::Url::Native::Parse", free_immediately, size)]
pub struct NativeParse(Mutex<Owned<Parse<'static>>>);

impl NativeParse {
    fn lock(&self) -> MutexGuard<'_, Owned<Parse<'static>>> {
        self.0.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

/// The Ruby `Ferro::Url::Native::ByteSerialize`, which
/// `Ferro::Url::FormUrlencoded::ByteSerialize` holds.
#[magnus::wrap(class = "Ferro::Url::Native::ByteSerialize", free_immediately, size)]
pub struct NativeByteSerialize(Mutex<Owned<ByteSerialize<'static>>>);

impl NativeByteSerialize {
    fn lock(&self) -> MutexGuard<'_, Owned<ByteSerialize<'static>>> {
        self.0.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

/// `form_urlencoded::parse(input)` (`src/lib.rs:31-41`) over a copy of
/// `input`'s bytes.
fn form_parse(input: RString) -> NativeParse {
    let bytes = Arc::new(input.to_bytes().to_vec());
    // SAFETY: the closure only builds `form_urlencoded::parse`'s `Parse`,
    // which keeps the slice in itself and nowhere else (form_urlencoded
    // 1.2.2 `src/lib.rs:31-46`), as `Owned::new` requires.
    #[allow(unsafe_code)]
    let pairs = unsafe { Owned::new(bytes, |bytes| form_urlencoded::parse(bytes)) };
    NativeParse(Mutex::new(pairs))
}

/// `Url::query_pairs` (url 2.5.8 `src/lib.rs:1485-1511`) of `url`, a copy
/// taken under its lock, so later changes to the `Url` do not reach it.
pub fn query_pairs(url: Url) -> NativeParse {
    // SAFETY: `Url::query_pairs` only builds a `Parse` over the URL's
    // query, which keeps the slice in itself and nowhere else (url 2.5.8
    // `src/lib.rs:1508-1511`, form_urlencoded 1.2.2 `src/lib.rs:31-46`), as
    // `Owned::new` requires.
    #[allow(unsafe_code)]
    let pairs = unsafe { Owned::new(Arc::new(url), Url::query_pairs) };
    NativeParse(Mutex::new(pairs))
}

/// `Parse::next` (`src/lib.rs:48-71`): the next pair, or `nil`.
fn parse_next(ruby: &Ruby, parse: &NativeParse) -> Result<Option<(String, String)>, Error> {
    let mut parse = parse.lock();
    capture(|| parse.next_pair()).map_err(|panic| error(ruby, panicked(&panic)))
}

/// `Parse`'s `Copy` (`src/lib.rs:43`): a copy where `parse` is.
fn parse_copy(parse: &NativeParse) -> NativeParse {
    NativeParse(Mutex::new(parse.lock().copy()))
}

/// `form_urlencoded::byte_serialize(input)` (`src/lib.rs:117-124`) over a
/// copy of `input`'s bytes.
fn form_byte_serialize(input: RString) -> NativeByteSerialize {
    let bytes = Arc::new(input.to_bytes().to_vec());
    // SAFETY: the closure only builds `form_urlencoded::byte_serialize`'s
    // `ByteSerialize`, which keeps the slice in itself and nowhere else
    // (form_urlencoded 1.2.2 `src/lib.rs:117-129`), as `Owned::new`
    // requires.
    #[allow(unsafe_code)]
    let chunks = unsafe { Owned::new(bytes, |bytes| form_urlencoded::byte_serialize(bytes)) };
    NativeByteSerialize(Mutex::new(chunks))
}

/// `ByteSerialize::next` (`src/lib.rs:138-163`): the next slice, or `nil`.
fn byte_serialize_next(ruby: &Ruby, bytes: &NativeByteSerialize) -> Result<Option<String>, Error> {
    let mut bytes = bytes.lock();
    capture(|| bytes.next_str()).map_err(|panic| error(ruby, panicked(&panic)))
}

/// `ByteSerialize::size_hint` (`src/lib.rs:165-171`).
fn byte_serialize_size_hint(bytes: &NativeByteSerialize) -> (usize, Option<usize>) {
    bytes.lock().size_hint()
}

/// `ByteSerialize`'s `Debug` (`src/lib.rs:126`), formatted by Rust.
fn byte_serialize_debug(bytes: &NativeByteSerialize) -> String {
    bytes.lock().debug()
}

pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("form_parse", function!(form_parse, 1))?;
    native.define_singleton_method("parse_next", function!(parse_next, 1))?;
    native.define_singleton_method("parse_copy", function!(parse_copy, 1))?;
    native.define_singleton_method("form_byte_serialize", function!(form_byte_serialize, 1))?;
    native.define_singleton_method("byte_serialize_next", function!(byte_serialize_next, 1))?;
    native.define_singleton_method(
        "byte_serialize_size_hint",
        function!(byte_serialize_size_hint, 1),
    )?;
    native.define_singleton_method("byte_serialize_debug", function!(byte_serialize_debug, 1))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::Owned;
    use std::sync::Arc;
    use url::Url;

    #[test]
    fn a_parse_outlives_the_caller_and_its_copy_keeps_its_place() {
        // SAFETY: the closure only builds a `Parse`, as `Owned::new` requires.
        #[allow(unsafe_code)]
        let mut pairs = unsafe {
            Owned::new(Arc::new(b"a=1&&b=2&c".to_vec()), |bytes| {
                form_urlencoded::parse(bytes)
            })
        };
        assert_eq!(pairs.next_pair(), Some(("a".to_owned(), "1".to_owned())));
        let mut copy = pairs.copy();
        assert_eq!(pairs.next_pair(), Some(("b".to_owned(), "2".to_owned())));
        assert_eq!(pairs.next_pair(), Some(("c".to_owned(), String::new())));
        assert_eq!(pairs.next_pair(), None);
        drop(pairs);
        assert_eq!(copy.next_pair(), Some(("b".to_owned(), "2".to_owned())));
    }

    #[test]
    fn query_pairs_read_the_urls_own_iterator() {
        let url = Url::parse("https://example.com/?x=1&y=two+words#f").expect("a URL");
        let expected: Vec<(String, String)> = url
            .query_pairs()
            .map(|(name, value)| (name.into_owned(), value.into_owned()))
            .collect();
        // SAFETY: `Url::query_pairs` only builds a `Parse`, as `Owned::new`
        // requires.
        #[allow(unsafe_code)]
        let mut pairs = unsafe { Owned::new(Arc::new(url), Url::query_pairs) };
        let read: Vec<_> = std::iter::from_fn(|| pairs.next_pair()).collect();
        assert_eq!(read, expected);
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2013-2016 The rust-url developers
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the Debug text and size_hint of form_urlencoded
    //   1.2.2's ByteSerialize (src/lib.rs:126-171), which these tests pin

    #[test]
    fn byte_serialize_answers_its_debug_text_and_size_hint_as_it_goes() {
        // SAFETY: the closure only builds a `ByteSerialize`, as
        // `Owned::new` requires.
        #[allow(unsafe_code)]
        let mut chunks = unsafe {
            Owned::new(Arc::new(b"a b".to_vec()), |bytes| {
                form_urlencoded::byte_serialize(bytes)
            })
        };
        assert_eq!(chunks.debug(), "ByteSerialize { bytes: [97, 32, 98] }");
        assert_eq!(chunks.size_hint(), (1, Some(3)));
        assert_eq!(chunks.next_str().as_deref(), Some("a"));
        assert_eq!(chunks.debug(), "ByteSerialize { bytes: [32, 98] }");
        assert_eq!(chunks.size_hint(), (1, Some(2)));
        assert_eq!(chunks.next_str().as_deref(), Some("+"));
        assert_eq!(chunks.next_str().as_deref(), Some("b"));
        assert_eq!(chunks.next_str(), None);
        assert_eq!(chunks.debug(), "ByteSerialize { bytes: [] }");
        assert_eq!(chunks.size_hint(), (0, Some(0)));
        let rust = form_urlencoded::byte_serialize(b"a b");
        assert_eq!(format!("{rust:?}"), "ByteSerialize { bytes: [97, 32, 98] }");
    }

    // SPDX-SnippetEnd
}
