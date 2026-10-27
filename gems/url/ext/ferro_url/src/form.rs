// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! `form_urlencoded` 1.2.2, which url re-exports as `url::form_urlencoded`
//! (url 2.5.8 `src/lib.rs:152`): `parse`, `byte_serialize`, and
//! `Serializer` over a String target (plan 005, decisions 8 and 9).
//!
//! A `Serializer` operation crosses as `[name, args...]`, and runs on a
//! fresh `form_urlencoded` `Serializer` each time, as the Ruby `Serializer`
//! holds its target, its start position, and its encoding override itself.

use std::borrow::Cow;
use std::cell::RefCell;
use std::collections::VecDeque;

use form_urlencoded::{Serializer, Target};
use magnus::{function, prelude::*, Error, RArray, RModule, RString, Ruby, Symbol};

use crate::{error, guarded};

/// One `Serializer` method (`form_urlencoded` `src/lib.rs:238-330`).
pub enum Operation {
    /// Nothing: `query_pairs_mut()` alone, which adds the `?` url writes
    /// when it makes the serializer (url `src/lib.rs:1701-1719`).
    None,
    Clear,
    AppendPair(String, String),
    AppendKeyOnly(String),
    ExtendPairs(Vec<(String, String)>),
    ExtendKeysOnly(Vec<String>),
}

impl Operation {
    /// The operation a Ruby `[name, args...]` names.
    pub fn from_ruby(ruby: &Ruby, operation: RArray) -> Result<Self, Error> {
        let name: Symbol = operation.entry(0)?;
        Ok(match name.name()?.as_ref() {
            "none" => Self::None,
            "clear" => Self::Clear,
            "append_pair" => Self::AppendPair(operation.entry(1)?, operation.entry(2)?),
            "append_key_only" => Self::AppendKeyOnly(operation.entry(1)?),
            "extend_pairs" => Self::ExtendPairs(operation.entry(1)?),
            "extend_keys_only" => Self::ExtendKeysOnly(operation.entry(1)?),
            other => {
                return Err(Error::new(
                    ruby.exception_arg_error(),
                    format!("no Serializer method {other}"),
                ))
            }
        })
    }

    /// Runs the operation on `serializer`, through `form_urlencoded`'s own
    /// method.
    pub fn apply<T: Target>(&self, serializer: &mut Serializer<'_, T>) {
        match self {
            Self::None => {}
            Self::Clear => {
                serializer.clear();
            }
            Self::AppendPair(name, value) => {
                serializer.append_pair(name, value);
            }
            Self::AppendKeyOnly(name) => {
                serializer.append_key_only(name);
            }
            Self::ExtendPairs(pairs) => {
                serializer.extend_pairs(pairs);
            }
            Self::ExtendKeysOnly(names) => {
                serializer.extend_keys_only::<_, String>(names);
            }
        }
    }
}

/// Makes `encode` an encoding override for every lifetime of its input,
/// as `form_urlencoded`'s `EncodingOverride` asks (`src/lib.rs:430`).
pub const fn encoder<F: for<'b> Fn(&'b str) -> Cow<'b, [u8]>>(encode: F) -> F {
    encode
}

/// The encodings a Ruby callable gave for an operation's names and values,
/// computed before `form_urlencoded` runs, in the order it encodes them
/// (plan 005, decision 10), so no Ruby code runs while a `Url` is locked.
pub struct Encodings {
    given: bool,
    queue: RefCell<VecDeque<(String, Vec<u8>)>>,
    mismatch: RefCell<Option<String>>,
}

impl Encodings {
    /// The encodings, as `[[input, bytes], ...]`, or `None` for no
    /// encoding override. Each entry is copied out of Ruby at once.
    pub fn from_ruby(encodings: Option<RArray>) -> Result<Self, Error> {
        let mut queue = VecDeque::new();
        if let Some(entries) = encodings {
            for entry in entries {
                let entry = RArray::try_convert(entry)?;
                let input: String = entry.entry(0)?;
                let bytes: RString = entry.entry(1)?;
                queue.push_back((input, bytes.to_bytes().to_vec()));
            }
        }
        Ok(Self {
            given: encodings.is_some(),
            queue: RefCell::new(queue),
            mismatch: RefCell::new(None),
        })
    }

    /// Whether there is an encoding override.
    pub const fn is_some(&self) -> bool {
        self.given
    }

    /// The override `form_urlencoded` calls: the next encoding, checked
    /// against the text `form_urlencoded` asks for.
    pub fn encoder(&self) -> impl for<'b> Fn(&'b str) -> Cow<'b, [u8]> + '_ {
        encoder(move |text| {
            let next = self.queue.borrow_mut().pop_front();
            match next {
                Some((input, bytes)) if input == text => Cow::Owned(bytes),
                other => {
                    self.mismatch.borrow_mut().get_or_insert_with(|| {
                        format!(
                            "form_urlencoded encoded {text:?} where ferro-url expected {:?}",
                            other.map(|(input, _)| input)
                        )
                    });
                    Cow::Borrowed(text.as_bytes())
                }
            }
        })
    }

    /// `Ok`, unless `form_urlencoded` asked for other texts than the ones
    /// encoded for it, which would mean a `form_urlencoded` this gem does not
    /// know: then the message for `Error`. Rust values only, as it runs
    /// under a `Url`'s lock.
    pub fn finish(&self) -> Result<(), String> {
        let mismatch = self.mismatch.borrow_mut().take().or_else(|| {
            self.queue
                .borrow()
                .front()
                .map(|(input, _)| format!("form_urlencoded never encoded {input:?}"))
        });
        mismatch.map_or(Ok(()), Err)
    }
}

// SPDX-SnippetBegin
// SPDX-SnippetCopyrightText: 2013-2016 The rust-url developers
// SPDX-License-Identifier: MIT OR Apache-2.0
// SPDX-SnippetComment: the panic message of form_urlencoded 1.2.2's
//   Serializer::for_suffix (src/lib.rs:222-229)

/// What `Serializer::for_suffix` panics with for a start past the end of
/// its target (`src/lib.rs:223-229`), or `None`.
pub fn suffix_refusal(target_len: usize, start_position: usize) -> Option<String> {
    (target_len < start_position)
        .then(|| format!("invalid length {start_position} for target of length {target_len}"))
}

// SPDX-SnippetEnd

/// Why `start_position` cannot start a suffix of `target`: past its end,
/// as `for_suffix` panics on, or inside a character, where `clear`'s
/// `String::truncate` panics (`src/lib.rs:241-244`). The second is the
/// gem's own text, since the panic is std's.
pub fn start_refusal(target: &str, start_position: usize) -> Option<String> {
    suffix_refusal(target.len(), start_position).or_else(|| {
        (!target.is_char_boundary(start_position))
            .then(|| format!("start position {start_position} is inside a character of the target"))
    })
}

/// Refuses a start position `Serializer::for_suffix` would panic on, with
/// `ArgumentError` and its message (plan 005, decision 8).
fn form_check_suffix(ruby: &Ruby, target: RString, start_position: usize) -> Result<(), Error> {
    let target = target.to_string()?;
    start_refusal(&target, start_position).map_or(Ok(()), |message| {
        Err(Error::new(ruby.exception_arg_error(), message))
    })
}

/// One `Serializer::for_suffix(&mut target, start_position)` operation
/// (`src/lib.rs:208-350`): the target's text afterwards.
fn form_serialize(
    ruby: &Ruby,
    target: String,
    start_position: usize,
    operation: RArray,
    encodings: Option<RArray>,
) -> Result<String, Error> {
    if let Some(message) = start_refusal(&target, start_position) {
        return Err(Error::new(ruby.exception_arg_error(), message));
    }
    let operation = Operation::from_ruby(ruby, operation)?;
    let encodings = Encodings::from_ruby(encodings)?;
    guarded(ruby, move || {
        let mut target = target;
        {
            let encode = encodings.encoder();
            let mut serializer = Serializer::for_suffix(&mut target, start_position);
            if encodings.is_some() {
                serializer.encoding_override(Some(&encode));
            }
            operation.apply(&mut serializer);
        }
        encodings.finish().map_err(|message| error(ruby, message))?;
        Ok(target)
    })
}

/// `form_urlencoded::parse(input)` (`src/lib.rs:31-115`), collected.
fn form_parse(ruby: &Ruby, input: RString) -> Result<Vec<(String, String)>, Error> {
    let input = input.to_bytes().to_vec();
    guarded(ruby, move || {
        Ok(form_urlencoded::parse(&input)
            .into_owned()
            .collect::<Vec<_>>())
    })
}

/// `form_urlencoded::byte_serialize(input)` (`src/lib.rs:117-172`),
/// collected.
fn form_byte_serialize(ruby: &Ruby, input: RString) -> Result<Vec<String>, Error> {
    let input = input.to_bytes().to_vec();
    guarded(ruby, move || {
        Ok(form_urlencoded::byte_serialize(&input)
            .map(str::to_owned)
            .collect::<Vec<_>>())
    })
}

pub fn define(native: RModule) -> Result<(), Error> {
    native.define_singleton_method("form_check_suffix", function!(form_check_suffix, 2))?;
    native.define_singleton_method("form_serialize", function!(form_serialize, 4))?;
    native.define_singleton_method("form_parse", function!(form_parse, 1))?;
    native.define_singleton_method("form_byte_serialize", function!(form_byte_serialize, 1))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{start_refusal, suffix_refusal, Encodings, Operation};
    use form_urlencoded::Serializer;
    use std::cell::RefCell;

    fn encodings(pairs: &[(&str, &[u8])]) -> Encodings {
        Encodings {
            given: true,
            queue: RefCell::new(
                pairs
                    .iter()
                    .map(|(input, bytes)| ((*input).to_owned(), bytes.to_vec()))
                    .collect(),
            ),
            mismatch: RefCell::new(None),
        }
    }

    fn serialize(operation: &Operation, encodings: &Encodings) -> String {
        let mut target = String::new();
        {
            let encode = encodings.encoder();
            let mut serializer = Serializer::new(&mut target);
            serializer.encoding_override(Some(&encode));
            operation.apply(&mut serializer);
        }
        target
    }

    #[test]
    fn replayed_encodings_reach_form_urlencoded_in_its_order() {
        let replay = encodings(&[("a", b"A"), ("b", b"B"), ("c", b"C"), ("d", b"D")]);
        let operation = Operation::ExtendPairs(vec![
            ("a".to_owned(), "b".to_owned()),
            ("c".to_owned(), "d".to_owned()),
        ]);
        assert_eq!(serialize(&operation, &replay), "A=B&C=D");
        assert!(replay.mismatch.borrow().is_none());
        assert!(replay.queue.borrow().is_empty());
    }

    #[test]
    fn an_encoding_for_other_text_is_a_mismatch() {
        let replay = encodings(&[("x", b"X")]);
        let operation = Operation::AppendKeyOnly("a".to_owned());
        assert_eq!(serialize(&operation, &replay), "a");
        assert_eq!(
            replay.mismatch.borrow().as_deref(),
            Some("form_urlencoded encoded \"a\" where ferro-url expected Some(\"x\")")
        );
    }

    #[test]
    fn an_encoding_never_asked_for_is_a_failure() {
        let replay = encodings(&[("a", b"A"), ("b", b"B")]);
        let operation = Operation::AppendKeyOnly("a".to_owned());
        assert_eq!(serialize(&operation, &replay), "A");
        assert_eq!(
            replay.finish(),
            Err("form_urlencoded never encoded \"b\"".to_owned())
        );
        let exact = encodings(&[("a", b"A")]);
        serialize(&operation, &exact);
        assert_eq!(exact.finish(), Ok(()));
    }

    #[test]
    fn a_start_inside_a_character_is_refused_before_clear_panics() {
        assert_eq!(start_refusal("é", 0), None);
        assert_eq!(start_refusal("é", 2), None);
        assert_eq!(
            start_refusal("é", 1).as_deref(),
            Some("start position 1 is inside a character of the target")
        );
        assert_eq!(
            start_refusal("é", 3).as_deref(),
            Some("invalid length 3 for target of length 2")
        );
        let panicked = std::panic::catch_unwind(|| {
            let mut target = "é".to_owned();
            Serializer::for_suffix(&mut target, 1).clear();
        });
        assert!(
            panicked.is_err(),
            "form_urlencoded panics where the gem refuses"
        );
    }

    #[test]
    fn the_suffix_refusal_is_form_urlencodeds_own_panic() {
        assert_eq!(suffix_refusal(3, 3), None);
        let message = suffix_refusal(2, 3).expect("refused");
        let payload = std::panic::catch_unwind(|| {
            let mut target = "ab".to_owned();
            let _serializer = Serializer::for_suffix(&mut target, 3);
        })
        .expect_err("form_urlencoded panics");
        assert_eq!(crate::panic_of(&payload).0, message);
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2013-2016 The rust-url developers
    // SPDX-License-Identifier: MIT OR Apache-2.0
    // SPDX-SnippetComment: the panic messages of form_urlencoded 1.2.2's
    //   finished Serializer (src/lib.rs:343-363), which Ruby's Serializer
    //   copies

    #[test]
    fn a_finished_serializer_panics_with_the_texts_ruby_copies() {
        let double = std::panic::catch_unwind(|| {
            let mut serializer = Serializer::new(String::new());
            serializer.finish();
            serializer.finish();
        })
        .expect_err("a second finish panics");
        assert_eq!(
            crate::panic_of(&double).0,
            "url::form_urlencoded::Serializer double finish"
        );
        let after = std::panic::catch_unwind(|| {
            let mut serializer = Serializer::new(String::new());
            serializer.finish();
            serializer.append_pair("a", "b");
        })
        .expect_err("an append after finish panics");
        assert_eq!(
            crate::panic_of(&after).0,
            "url::form_urlencoded::Serializer finished"
        );
    }

    // SPDX-SnippetEnd
}
