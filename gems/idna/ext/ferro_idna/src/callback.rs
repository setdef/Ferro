// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! The `output_as_unicode` callback idna's `to_user_interface` and
//! `process` take, run as a Ruby callable (plan 006, decision 13).
//!
//! idna calls it inside its processing, on the calling thread with the GVL
//! held, so Ruby code may run there. magnus calls Ruby under `rb_protect`,
//! so an exception comes back as an `Err` rather than unwinding through
//! idna's frames. The first one is kept, every later call answers `false`
//! without running Ruby, and the caller raises it once idna returns.

use magnus::{prelude::*, Error, Ruby, Value};

/// A Ruby callable standing in for idna's `FnMut(&[char], &[char], bool)
/// -> bool`, and the first exception it raised.
pub struct OutputAsUnicode<'r> {
    ruby: &'r Ruby,
    callable: Value,
    failure: Option<Error>,
}

impl<'r> OutputAsUnicode<'r> {
    pub const fn new(ruby: &'r Ruby, callable: Value) -> Self {
        Self {
            ruby,
            callable,
            failure: None,
        }
    }

    /// Calls the callable with the label, the TLD, and the bidi flag, and
    /// answers whether its result is truthy. After a failure it answers
    /// `false`, Punycode, without calling it again.
    pub fn decide(&mut self, label: &[char], tld: &[char], is_bidi: bool) -> bool {
        if self.failure.is_some() {
            return false;
        }
        let label: String = label.iter().collect();
        let tld: String = tld.iter().collect();
        match self.callable.funcall::<_, _, Value>(
            "call",
            (self.ruby.str_new(&label), self.ruby.str_new(&tld), is_bidi),
        ) {
            Ok(answer) => answer.to_bool(),
            Err(error) => {
                self.failure = Some(error);
                false
            }
        }
    }

    /// The exception the callable raised, if any.
    pub fn finish(self) -> Result<(), Error> {
        self.failure.map_or(Ok(()), Err)
    }
}
