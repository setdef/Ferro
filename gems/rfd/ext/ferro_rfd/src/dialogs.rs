// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT

//! rfd's four builders, replayed from the settings a Ruby builder kept
//! (plan 002, decision 1), and their terminal calls.
//!
//! A file dialog's settings arrive as `[filters, directory, file_name,
//! title, parent, can_create_directories]`, and a message dialog's as
//! `[level, title, description, buttons, parent]`, each `nil` where the
//! Ruby builder's setter never ran, so rfd's default stays.

use std::path::PathBuf;

use magnus::{prelude::*, Error, RArray, Ruby, Symbol, Value};
use rfd::{
    AsyncFileDialog, AsyncMessageDialog, FileDialog, MessageButtons, MessageDialog,
    MessageDialogResult, MessageLevel,
};

use crate::future::{Future, Output};
use crate::handles::{self, Parent};
use crate::{capture, gvl, path_from_ruby, path_to_ruby, platform, rfd_error, settle, Panic};

type ParentPair = (Option<RArray>, Option<RArray>);

/// A file dialog's settings as the Ruby builder passes them.
type FileArgs = (
    Vec<(String, Vec<String>)>,
    Option<Value>,
    Option<String>,
    Option<String>,
    Option<ParentPair>,
    Option<bool>,
);

/// A message dialog's settings as the Ruby builder passes them.
type MessageArgs = (
    Symbol,
    Option<String>,
    Option<String>,
    RArray,
    Option<ParentPair>,
);

/// What Ruby raises for a NUL byte in a string a C API would get: its own
/// `ArgumentError` text (`rb_string_value_cstr`, `string.c:2930-2941` at
/// Ruby v4.0.9).
const NUL_BYTE: &str = "string contains null byte";

/// A file dialog's settings, converted to Rust values.
struct FileSettings {
    filters: Vec<(String, Vec<String>)>,
    directory: Option<PathBuf>,
    file_name: Option<String>,
    title: Option<String>,
    parent: Option<Parent>,
    can_create_directories: Option<bool>,
}

/// Whether a filter has a NUL byte, which rfd's portal backend unwraps
/// into a panic (rfd `src/backend/xdg_desktop_portal.rs:47-65`). It is
/// refused on every platform, so code tested elsewhere does not crash on
/// Linux (plan 002, decision 9).
fn has_nul(filter: &(String, Vec<String>)) -> bool {
    filter.0.contains('\0') || filter.1.iter().any(|extension| extension.contains('\0'))
}

fn file_settings(ruby: &Ruby, args: FileArgs) -> Result<FileSettings, Error> {
    let (filters, directory, file_name, title, parent, can_create_directories) = args;
    if filters.iter().any(has_nul) {
        return Err(Error::new(ruby.exception_arg_error(), NUL_BYTE));
    }
    Ok(FileSettings {
        filters,
        directory: directory.map(path_from_ruby).transpose()?,
        file_name,
        title,
        parent: parent.map(|pair| handles::parent(ruby, pair)).transpose()?,
        can_create_directories,
    })
}

/// rfd's `FileDialog` with these settings, set through rfd's own setters
/// (rfd `src/file_dialog.rs:35-111`).
fn file_dialog_of(settings: &FileSettings) -> FileDialog {
    let mut dialog = FileDialog::new();
    for (name, extensions) in &settings.filters {
        dialog = dialog.add_filter(name, extensions);
    }
    if let Some(directory) = &settings.directory {
        dialog = dialog.set_directory(directory);
    }
    if let Some(file_name) = &settings.file_name {
        dialog = dialog.set_file_name(file_name);
    }
    if let Some(title) = &settings.title {
        dialog = dialog.set_title(title);
    }
    if let Some(parent) = &settings.parent {
        dialog = dialog.set_parent(parent);
    }
    if let Some(can) = settings.can_create_directories {
        dialog = dialog.set_can_create_directories(can);
    }
    dialog
}

/// rfd's `AsyncFileDialog` with these settings (rfd
/// `src/file_dialog.rs:187-255`).
fn async_file_dialog_of(settings: &FileSettings) -> AsyncFileDialog {
    let mut dialog = AsyncFileDialog::new();
    for (name, extensions) in &settings.filters {
        dialog = dialog.add_filter(name, extensions);
    }
    if let Some(directory) = &settings.directory {
        dialog = dialog.set_directory(directory);
    }
    if let Some(file_name) = &settings.file_name {
        dialog = dialog.set_file_name(file_name);
    }
    if let Some(title) = &settings.title {
        dialog = dialog.set_title(title);
    }
    if let Some(parent) = &settings.parent {
        dialog = dialog.set_parent(parent);
    }
    if let Some(can) = settings.can_create_directories {
        dialog = dialog.set_can_create_directories(can);
    }
    dialog
}

/// `Native.file_dialog_debug`: rfd's `Debug` of the `FileDialog`
/// (plan 002, decision 2).
pub fn file_dialog_debug(ruby: &Ruby, args: FileArgs) -> Result<String, Error> {
    let settings = file_settings(ruby, args)?;
    settle(ruby, capture(|| format!("{:?}", file_dialog_of(&settings))))
}

/// `Native.async_file_dialog_debug`: rfd's `Debug` of the
/// `AsyncFileDialog`.
pub fn async_file_dialog_debug(ruby: &Ruby, args: FileArgs) -> Result<String, Error> {
    let settings = file_settings(ruby, args)?;
    settle(
        ruby,
        capture(|| format!("{:?}", async_file_dialog_of(&settings))),
    )
}

/// A terminal call of a file dialog.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FileOp {
    PickFile,
    PickFiles,
    PickFolder,
    PickFolders,
    SaveFile,
    #[cfg(target_os = "macos")]
    PickFileOrFolder,
    #[cfg(target_os = "macos")]
    PickFilesOrFolders,
}

impl FileOp {
    /// The call `name` names, or the `ArgumentError` for one this
    /// platform's rfd lacks (`pick_file_or_folder` and
    /// `pick_files_or_folders` exist only on macOS, rfd
    /// `src/file_dialog.rs:141-155`).
    fn parse(ruby: &Ruby, name: Symbol) -> Result<Self, Error> {
        let name = name.name()?;
        match name.as_ref() {
            "pick_file" => Ok(Self::PickFile),
            "pick_files" => Ok(Self::PickFiles),
            "pick_folder" => Ok(Self::PickFolder),
            "pick_folders" => Ok(Self::PickFolders),
            "save_file" => Ok(Self::SaveFile),
            #[cfg(target_os = "macos")]
            "pick_file_or_folder" => Ok(Self::PickFileOrFolder),
            #[cfg(target_os = "macos")]
            "pick_files_or_folders" => Ok(Self::PickFilesOrFolders),
            #[cfg(not(target_os = "macos"))]
            "pick_file_or_folder" | "pick_files_or_folders" => Err(Error::new(
                ruby.exception_arg_error(),
                format!("{name} is not available on this platform"),
            )),
            other => Err(Error::new(
                ruby.exception_arg_error(),
                format!("unknown file dialog call {other}"),
            )),
        }
    }
}

/// What a sync file dialog returned.
enum Picked {
    One(Option<PathBuf>),
    Many(Option<Vec<PathBuf>>),
}

impl Picked {
    /// Runs `op` on `dialog` (rfd `src/file_dialog.rs:120-175`).
    fn run(op: FileOp, dialog: FileDialog) -> Self {
        match op {
            FileOp::PickFile => Self::One(dialog.pick_file()),
            FileOp::PickFiles => Self::Many(dialog.pick_files()),
            FileOp::PickFolder => Self::One(dialog.pick_folder()),
            FileOp::PickFolders => Self::Many(dialog.pick_folders()),
            FileOp::SaveFile => Self::One(dialog.save_file()),
            #[cfg(target_os = "macos")]
            FileOp::PickFileOrFolder => Self::One(dialog.pick_file_or_folder()),
            #[cfg(target_os = "macos")]
            FileOp::PickFilesOrFolders => Self::Many(dialog.pick_files_or_folders()),
        }
    }

    fn into_ruby(self, ruby: &Ruby) -> Value {
        match self {
            Self::One(path) => path.map_or_else(
                || ruby.qnil().as_value(),
                |path| path_to_ruby(ruby, &path).as_value(),
            ),
            Self::Many(paths) => paths.map_or_else(
                || ruby.qnil().as_value(),
                |paths| {
                    ruby.ary_from_iter(paths.iter().map(|path| path_to_ruby(ruby, path)))
                        .as_value()
                },
            ),
        }
    }
}

/// The `Ferro::Rfd::Error` for a call rfd would panic on here, if any.
fn refuse(ruby: &Ruby, refusal: Option<&'static str>) -> Result<(), Error> {
    refusal.map_or(Ok(()), |message| Err(rfd_error(ruby, message)))
}

/// Runs a sync dialog with the GVL released (plan 002, decision 4).
fn show<T>(ruby: &Ruby, dialog: impl FnOnce() -> T) -> Result<T, Error> {
    refuse(ruby, platform::refuse_sync())?;
    let outcome = gvl::without_gvl(ruby, |_| capture(dialog))?;
    settle(
        ruby,
        outcome.unwrap_or_else(|payload| Err(crate::panic_of(&payload))),
    )
}

/// `Native.file_dialog`: a sync file dialog's terminal call, returning a
/// path String, an Array of them, or `nil` when the user cancels.
pub fn file_dialog(ruby: &Ruby, op: Symbol, args: FileArgs) -> Result<Value, Error> {
    let op = FileOp::parse(ruby, op)?;
    let settings = file_settings(ruby, args)?;
    let dialog = file_dialog_of(&settings);
    Ok(show(ruby, move || Picked::run(op, dialog))?.into_ruby(ruby))
}

/// Starts rfd's future for `op` (rfd `src/file_dialog.rs:266-331`). The
/// call to rfd happens here, not when the future is first polled, since
/// on macOS that call opens the dialog (plan 002, decision 3).
fn start(op: FileOp, dialog: AsyncFileDialog) -> crate::future::Pending {
    match op {
        FileOp::PickFile => Output::handle(dialog.pick_file()),
        FileOp::PickFiles => Output::handles(dialog.pick_files()),
        FileOp::PickFolder => Output::handle(dialog.pick_folder()),
        FileOp::PickFolders => Output::handles(dialog.pick_folders()),
        FileOp::SaveFile => Output::handle(dialog.save_file()),
        #[cfg(target_os = "macos")]
        FileOp::PickFileOrFolder => Output::handle(dialog.pick_file_or_folder()),
        #[cfg(target_os = "macos")]
        FileOp::PickFilesOrFolders => Output::handles(dialog.pick_files_or_folders()),
    }
}

/// Makes a future, with the GVL released where making it can block.
fn make(
    ruby: &Ruby,
    starter: impl FnOnce() -> crate::future::Pending,
) -> Result<crate::future::Pending, Error> {
    let pending: Result<_, Panic> = if platform::CREATION_BLOCKS {
        gvl::without_gvl(ruby, |_| capture(starter))?
            .unwrap_or_else(|payload| Err(crate::panic_of(&payload)))
    } else {
        capture(starter)
    };
    settle(ruby, pending)
}

/// `Native.async_file_dialog`: an async file dialog's terminal call,
/// returning a `Ferro::Rfd::Future`.
pub fn async_file_dialog(ruby: &Ruby, op: Symbol, args: FileArgs) -> Result<Future, Error> {
    let op = FileOp::parse(ruby, op)?;
    let settings = file_settings(ruby, args)?;
    let dialog = async_file_dialog_of(&settings);
    refuse(ruby, platform::refuse_async(true))?;
    let pending = make(ruby, move || start(op, dialog))?;
    Ok(Future::new(pending, platform::needs_main_loop(true)))
}

/// A message dialog's settings, converted to Rust values.
struct MessageSettings {
    level: MessageLevel,
    title: Option<String>,
    description: Option<String>,
    buttons: MessageButtons,
    parent: Option<Parent>,
}

fn level(ruby: &Ruby, name: Symbol) -> Result<MessageLevel, Error> {
    match name.name()?.as_ref() {
        "Info" => Ok(MessageLevel::Info),
        "Warning" => Ok(MessageLevel::Warning),
        "Error" => Ok(MessageLevel::Error),
        other => Err(Error::new(
            ruby.exception_arg_error(),
            format!("unknown MessageLevel {other}"),
        )),
    }
}

/// The buttons a tagged Array names: `[:Ok]`, or `[:OkCustom, ok_text]`
/// and the like (rfd `src/message_dialog.rs:161-177`).
fn buttons(ruby: &Ruby, tuple: RArray) -> Result<MessageButtons, Error> {
    let tag: Symbol = tuple.entry(0)?;
    let text = |index| tuple.entry::<String>(index);
    match tag.name()?.as_ref() {
        "Ok" => Ok(MessageButtons::Ok),
        "OkCancel" => Ok(MessageButtons::OkCancel),
        "YesNo" => Ok(MessageButtons::YesNo),
        "YesNoCancel" => Ok(MessageButtons::YesNoCancel),
        "OkCustom" => Ok(MessageButtons::OkCustom(text(1)?)),
        "OkCancelCustom" => Ok(MessageButtons::OkCancelCustom(text(1)?, text(2)?)),
        "YesNoCancelCustom" => Ok(MessageButtons::YesNoCancelCustom(
            text(1)?,
            text(2)?,
            text(3)?,
        )),
        other => Err(Error::new(
            ruby.exception_arg_error(),
            format!("unknown MessageButtons {other}"),
        )),
    }
}

fn message_settings(ruby: &Ruby, args: MessageArgs) -> Result<MessageSettings, Error> {
    let (level_name, title, description, buttons_tuple, parent) = args;
    Ok(MessageSettings {
        level: level(ruby, level_name)?,
        title,
        description,
        buttons: buttons(ruby, buttons_tuple)?,
        parent: parent.map(|pair| handles::parent(ruby, pair)).transpose()?,
    })
}

/// rfd's `MessageDialog` with these settings (rfd
/// `src/message_dialog.rs:28-80`).
fn message_dialog_of(settings: &MessageSettings) -> MessageDialog {
    let mut dialog = MessageDialog::new()
        .set_level(settings.level)
        .set_buttons(settings.buttons.clone());
    if let Some(title) = &settings.title {
        dialog = dialog.set_title(title);
    }
    if let Some(description) = &settings.description {
        dialog = dialog.set_description(description);
    }
    if let Some(parent) = &settings.parent {
        dialog = dialog.set_parent(parent);
    }
    dialog
}

/// rfd's `AsyncMessageDialog` with these settings (rfd
/// `src/message_dialog.rs:95-145`).
fn async_message_dialog_of(settings: &MessageSettings) -> AsyncMessageDialog {
    let mut dialog = AsyncMessageDialog::new()
        .set_level(settings.level)
        .set_buttons(settings.buttons.clone());
    if let Some(title) = &settings.title {
        dialog = dialog.set_title(title);
    }
    if let Some(description) = &settings.description {
        dialog = dialog.set_description(description);
    }
    if let Some(parent) = &settings.parent {
        dialog = dialog.set_parent(parent);
    }
    dialog
}

/// `Native.message_dialog_debug`: rfd's `Debug` of the `MessageDialog`.
pub fn message_dialog_debug(ruby: &Ruby, args: MessageArgs) -> Result<String, Error> {
    let settings = message_settings(ruby, args)?;
    settle(
        ruby,
        capture(|| format!("{:?}", message_dialog_of(&settings))),
    )
}

/// `Native.async_message_dialog_debug`: rfd's `Debug` of the
/// `AsyncMessageDialog`.
pub fn async_message_dialog_debug(ruby: &Ruby, args: MessageArgs) -> Result<String, Error> {
    let settings = message_settings(ruby, args)?;
    settle(
        ruby,
        capture(|| format!("{:?}", async_message_dialog_of(&settings))),
    )
}

/// A result as Ruby rebuilds it: `[:Yes]`, or `[:Custom, text]` (rfd
/// `src/message_dialog.rs:179-187`).
pub fn result_to_ruby(ruby: &Ruby, result: MessageDialogResult) -> RArray {
    let tag = |name: &str| ruby.to_symbol(name).as_value();
    match result {
        MessageDialogResult::Yes => ruby.ary_new_from_values(&[tag("Yes")]),
        MessageDialogResult::No => ruby.ary_new_from_values(&[tag("No")]),
        MessageDialogResult::Ok => ruby.ary_new_from_values(&[tag("Ok")]),
        MessageDialogResult::Cancel => ruby.ary_new_from_values(&[tag("Cancel")]),
        MessageDialogResult::Custom(text) => {
            ruby.ary_new_from_values(&[tag("Custom"), ruby.str_new(&text).as_value()])
        }
    }
}

/// `Native.message_dialog`: shows a sync message dialog and returns the
/// button pressed (rfd `src/message_dialog.rs:81-84`).
pub fn message_dialog(ruby: &Ruby, args: MessageArgs) -> Result<RArray, Error> {
    let settings = message_settings(ruby, args)?;
    let dialog = message_dialog_of(&settings);
    let result = show(ruby, move || dialog.show())?;
    Ok(result_to_ruby(ruby, result))
}

/// `Native.async_message_dialog`: an async message dialog's `show`,
/// returning a `Ferro::Rfd::Future` (rfd `src/message_dialog.rs:147-150`).
/// On macOS a message without a parent runs on a thread of its own, from
/// any thread (rfd `src/backend/macos/message_dialog.rs:172-183`).
pub fn async_message_dialog(ruby: &Ruby, args: MessageArgs) -> Result<Future, Error> {
    let settings = message_settings(ruby, args)?;
    let attaches = settings.parent.is_some();
    let dialog = async_message_dialog_of(&settings);
    refuse(ruby, platform::refuse_async(attaches))?;
    let pending = make(ruby, move || Output::result(dialog.show()))?;
    Ok(Future::new(pending, platform::needs_main_loop(attaches)))
}

#[cfg(test)]
mod tests {
    use super::has_nul;

    #[test]
    fn a_nul_byte_in_a_filter_name_or_extension_is_found() {
        let filter = |name: &str, extensions: &[&str]| {
            (
                name.to_owned(),
                extensions.iter().map(|&e| e.to_owned()).collect::<Vec<_>>(),
            )
        };
        assert!(!has_nul(&filter("Text", &["txt", "md"])));
        assert!(has_nul(&filter("Te\0xt", &["txt"])));
        assert!(has_nul(&filter("Text", &["txt", "m\0d"])));
    }

    /// The portal backend panics on what `has_nul` finds, which is why it
    /// is refused (rfd `src/backend/xdg_desktop_portal.rs:49`).
    #[test]
    fn a_nul_byte_is_what_cstring_refuses() {
        assert!(std::ffi::CString::new("Te\0xt").is_err());
    }
}
