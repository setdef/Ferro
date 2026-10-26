// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT OR Apache-2.0

//! notify-rust's enums, as Ruby and the native layer pass them (plan 003,
//! decision 8).
//!
//! The Ruby classes (`lib/ferro/notify_rust`) own the public values. Across
//! the boundary each travels as a tag: a unit variant as its name, a
//! Symbol; a variant with data as an Array, `[:Category, "email"]`. The
//! functions on `Native` run notify-rust's own conversions
//! (`src/urgency.rs:37-75`, `src/timeout.rs:28-78`, `src/hints.rs:97-145`,
//! `src/response.rs:36-122`, `src/notification_id.rs:28-44`), so their
//! rules are the crate's.

use magnus::{
    value::ReprValue, Error, IntoValue, RArray, RString, Ruby, Symbol, TryConvert, Value,
};
use notify_rust::{
    ActionResponse, CloseReason, Hint, NotificationId, NotificationResponse, Timeout, Urgency,
};

use crate::{capture, error, settle};

fn symbol(ruby: &Ruby, name: &str) -> Value {
    ruby.to_symbol(name).as_value()
}

fn type_error(ruby: &Ruby, message: impl Into<String>) -> Error {
    Error::new(ruby.exception_type_error(), message.into())
}

/// The name of the variant a tag names.
fn tag_name(value: Value) -> Result<String, Error> {
    Ok(Symbol::try_convert(value)?.name()?.into_owned())
}

/// `Urgency` from its name (`src/urgency.rs:27-35`).
pub fn urgency_from_ruby(ruby: &Ruby, value: Value) -> Result<Urgency, Error> {
    match tag_name(value)?.as_str() {
        "Low" => Ok(Urgency::Low),
        "Normal" => Ok(Urgency::Normal),
        "Critical" => Ok(Urgency::Critical),
        other => Err(type_error(ruby, format!("{other} is not an Urgency"))),
    }
}

/// `urgency`'s name.
pub fn urgency_to_ruby(ruby: &Ruby, urgency: Urgency) -> Value {
    symbol(ruby, &format!("{urgency:?}"))
}

/// `Timeout` from `:Default`, `:Never`, or the milliseconds of
/// `Milliseconds` (`src/timeout.rs:13-26`). magnus raises `RangeError` for
/// an Integer outside `u32`.
pub fn timeout_from_ruby(ruby: &Ruby, value: Value) -> Result<Timeout, Error> {
    if let Some(name) = Symbol::from_value(value) {
        return match name.name()?.as_ref() {
            "Default" => Ok(Timeout::Default),
            "Never" => Ok(Timeout::Never),
            other => Err(type_error(ruby, format!("{other} is not a Timeout"))),
        };
    }
    Ok(Timeout::Milliseconds(u32::try_convert(value)?))
}

/// `timeout` as its tag.
pub fn timeout_to_ruby(ruby: &Ruby, timeout: Timeout) -> Value {
    match timeout {
        Timeout::Default => symbol(ruby, "Default"),
        Timeout::Never => symbol(ruby, "Never"),
        Timeout::Milliseconds(milliseconds) => milliseconds.into_value_with(ruby),
    }
}

/// `reason` as its tag: a name, or the raw code of `Other`.
pub fn close_reason_to_ruby(ruby: &Ruby, reason: CloseReason) -> Value {
    match reason {
        CloseReason::Expired => symbol(ruby, "Expired"),
        CloseReason::Dismissed => symbol(ruby, "Dismissed"),
        CloseReason::CloseAction => symbol(ruby, "CloseAction"),
        CloseReason::Other(raw) => raw.into_value_with(ruby),
    }
}

/// `response` as its tag (`src/response.rs:63-83`).
pub fn response_to_ruby(ruby: &Ruby, response: &NotificationResponse) -> RArray {
    match response {
        NotificationResponse::Default => ruby.ary_new_from_values(&[symbol(ruby, "Default")]),
        NotificationResponse::Action(key) => {
            ruby.ary_new_from_values(&[symbol(ruby, "Action"), ruby.str_new(key).as_value()])
        }
        NotificationResponse::Reply(text) => {
            ruby.ary_new_from_values(&[symbol(ruby, "Reply"), ruby.str_new(text).as_value()])
        }
        NotificationResponse::Closed(reason) => {
            ruby.ary_new_from_values(&[symbol(ruby, "Closed"), close_reason_to_ruby(ruby, *reason)])
        }
    }
}

/// `response` as its tag (`src/response.rs:110-116`).
pub fn action_response_to_ruby(ruby: &Ruby, response: &ActionResponse<'_>) -> RArray {
    match response {
        ActionResponse::Custom(key) => {
            ruby.ary_new_from_values(&[symbol(ruby, "Custom"), ruby.str_new(key).as_value()])
        }
        ActionResponse::Closed(reason) => {
            ruby.ary_new_from_values(&[symbol(ruby, "Closed"), close_reason_to_ruby(ruby, *reason)])
        }
    }
}

/// Element `index` of a tag.
fn field<T: TryConvert>(tag: RArray, index: isize) -> Result<T, Error> {
    tag.entry(index)
}

/// `Hint` from its tag (`src/hints.rs:39-95`).
pub fn hint_from_ruby(ruby: &Ruby, tag: RArray) -> Result<Hint, Error> {
    let name = tag_name(tag.entry(0)?)?;
    Ok(match name.as_str() {
        "ActionIcons" => Hint::ActionIcons(field(tag, 1)?),
        "Category" => Hint::Category(field(tag, 1)?),
        "DesktopEntry" => Hint::DesktopEntry(field(tag, 1)?),
        #[cfg(all(unix, not(target_os = "macos")))]
        "ImageData" => {
            let image: &crate::platform::Image = field(tag, 1)?;
            Hint::ImageData(image.inner().clone())
        }
        "ImagePath" => Hint::ImagePath(field(tag, 1)?),
        "Resident" => Hint::Resident(field(tag, 1)?),
        "SoundFile" => Hint::SoundFile(field(tag, 1)?),
        "SoundName" => Hint::SoundName(field(tag, 1)?),
        "SuppressSound" => Hint::SuppressSound(field(tag, 1)?),
        "Transient" => Hint::Transient(field(tag, 1)?),
        "X" => Hint::X(field(tag, 1)?),
        "Y" => Hint::Y(field(tag, 1)?),
        "Urgency" => Hint::Urgency(urgency_from_ruby(ruby, tag.entry(1)?)?),
        "Custom" => Hint::Custom(field(tag, 1)?, field(tag, 2)?),
        "CustomInt" => Hint::CustomInt(field(tag, 1)?, field(tag, 2)?),
        "Invalid" => Hint::Invalid,
        other => return Err(type_error(ruby, format!("{other} is not a Hint"))),
    })
}

/// `hint` as its tag.
pub fn hint_to_ruby(ruby: &Ruby, hint: &Hint) -> RArray {
    let tag = |name: &str, values: Vec<Value>| {
        let mut all = vec![symbol(ruby, name)];
        all.extend(values);
        ruby.ary_new_from_values(&all)
    };
    let text = |value: &str| ruby.str_new(value).as_value();
    match hint {
        Hint::ActionIcons(value) => tag("ActionIcons", vec![value.into_value_with(ruby)]),
        Hint::Category(value) => tag("Category", vec![text(value)]),
        Hint::DesktopEntry(value) => tag("DesktopEntry", vec![text(value)]),
        #[cfg(all(unix, not(target_os = "macos")))]
        Hint::ImageData(image) => tag(
            "ImageData",
            vec![crate::platform::Image::new(image.clone()).into_value_with(ruby)],
        ),
        Hint::ImagePath(value) => tag("ImagePath", vec![text(value)]),
        Hint::Resident(value) => tag("Resident", vec![value.into_value_with(ruby)]),
        Hint::SoundFile(value) => tag("SoundFile", vec![text(value)]),
        Hint::SoundName(value) => tag("SoundName", vec![text(value)]),
        Hint::SuppressSound(value) => tag("SuppressSound", vec![value.into_value_with(ruby)]),
        Hint::Transient(value) => tag("Transient", vec![value.into_value_with(ruby)]),
        Hint::X(value) => tag("X", vec![value.into_value_with(ruby)]),
        Hint::Y(value) => tag("Y", vec![value.into_value_with(ruby)]),
        Hint::Urgency(value) => tag("Urgency", vec![urgency_to_ruby(ruby, *value)]),
        Hint::Custom(key, value) => tag("Custom", vec![text(key), text(value)]),
        Hint::CustomInt(key, value) => {
            tag("CustomInt", vec![text(key), value.into_value_with(ruby)])
        }
        Hint::Invalid => tag("Invalid", vec![]),
    }
}

/// `Native.urgency_try_from`: `TryFrom<&str> for Urgency`
/// (`src/urgency.rs:37-53`), raising `Error::Conversion`.
pub fn urgency_try_from(ruby: &Ruby, string: String) -> Result<Value, Error> {
    match settle(ruby, capture(move || Urgency::try_from(string.as_str())))? {
        Ok(urgency) => Ok(urgency_to_ruby(ruby, urgency)),
        Err(failure) => Err(error::notify_error(ruby, &failure)),
    }
}

/// `Native.urgency_from`: `From<u64>`, or `From<Option<u64>>` for `nil`
/// (`src/urgency.rs:55-75`).
pub fn urgency_from(ruby: &Ruby, value: Option<u64>) -> Value {
    let urgency = value.map_or_else(|| Urgency::from(None), Urgency::from);
    urgency_to_ruby(ruby, urgency)
}

/// `Native.timeout_from_i32`: `From<i32> for Timeout` (`src/timeout.rs:35-44`).
pub fn timeout_from_i32(ruby: &Ruby, milliseconds: i32) -> Value {
    timeout_to_ruby(ruby, Timeout::from(milliseconds))
}

/// `Native.timeout_from_str`: `FromStr for Timeout` (`src/timeout.rs:68-78`),
/// raising `ArgumentError` with Rust's `ParseIntError` text (plan 003,
/// decision 9).
pub fn timeout_from_str(ruby: &Ruby, string: RString) -> Result<Value, Error> {
    match string.to_string()?.parse::<Timeout>() {
        Ok(timeout) => Ok(timeout_to_ruby(ruby, timeout)),
        Err(failure) => Err(Error::new(ruby.exception_arg_error(), failure.to_string())),
    }
}

/// `Native.timeout_to_i32`: `From<Timeout> for i32` (`src/timeout.rs:58-66`).
pub fn timeout_to_i32(ruby: &Ruby, tag: Value) -> Result<i32, Error> {
    Ok(i32::from(timeout_from_ruby(ruby, tag)?))
}

/// `Native.close_reason_from`: `From<u32> for CloseReason`
/// (`src/response.rs:36-45`).
pub fn close_reason_from(ruby: &Ruby, raw: u32) -> Value {
    close_reason_to_ruby(ruby, CloseReason::from(raw))
}

/// `Native.notification_response_from`: `From<String>` for
/// `NotificationResponse` (`src/response.rs:92-96`).
pub fn notification_response_from(ruby: &Ruby, key: String) -> RArray {
    response_to_ruby(ruby, &NotificationResponse::from(key))
}

/// `Native.action_response_from`: `From<&str>` for `ActionResponse`
/// (`src/response.rs:118-122`).
pub fn action_response_from(ruby: &Ruby, key: RString) -> Result<RArray, Error> {
    let key = key.to_string()?;
    Ok(action_response_to_ruby(
        ruby,
        &ActionResponse::from(key.as_str()),
    ))
}

/// `Native.notification_id_from`: `From<u32>` for an Integer, `From<&str>`
/// for a String (`src/notification_id.rs:28-44`).
pub fn notification_id_from(ruby: &Ruby, value: Value) -> Result<RArray, Error> {
    let id = if let Some(text) = RString::from_value(value) {
        NotificationId::from(text.to_string()?)
    } else {
        NotificationId::from(u32::try_convert(value)?)
    };
    Ok(match id {
        NotificationId::Xdg(number) => {
            ruby.ary_new_from_values(&[symbol(ruby, "Xdg"), number.into_value_with(ruby)])
        }
        NotificationId::Mac(text) => {
            ruby.ary_new_from_values(&[symbol(ruby, "Mac"), ruby.str_new(&text).as_value()])
        }
    })
}

/// `Native.hint_from_key_val`: `Hint::from_key_val` (`src/hints.rs:128-144`),
/// raising `ArgumentError` with its `String` error (plan 003, decision 9).
pub fn hint_from_key_val(ruby: &Ruby, name: RString, value: RString) -> Result<RArray, Error> {
    match Hint::from_key_val(&name.to_string()?, &value.to_string()?) {
        Ok(hint) => Ok(hint_to_ruby(ruby, &hint)),
        Err(failure) => Err(Error::new(ruby.exception_arg_error(), failure)),
    }
}

/// `Native.hint_as_bool`: `Hint::as_bool` (`src/hints.rs:97-107`).
pub fn hint_as_bool(ruby: &Ruby, tag: RArray) -> Result<Option<bool>, Error> {
    Ok(hint_from_ruby(ruby, tag)?.as_bool())
}

/// `Native.hint_as_i32`: `Hint::as_i32` (`src/hints.rs:109-115`).
pub fn hint_as_i32(ruby: &Ruby, tag: RArray) -> Result<Option<i32>, Error> {
    Ok(hint_from_ruby(ruby, tag)?.as_i32())
}

/// `Native.hint_as_str`: `Hint::as_str` (`src/hints.rs:117-126`).
pub fn hint_as_str(ruby: &Ruby, tag: RArray) -> Result<Option<String>, Error> {
    Ok(hint_from_ruby(ruby, tag)?.as_str().map(str::to_owned))
}
