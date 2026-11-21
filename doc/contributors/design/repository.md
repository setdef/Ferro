<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# The Repository and Its Gems

Ferro binds Rust crates to Ruby, one gem per crate
([ADR 001](../adr/001.md)). This document says which crates it binds and
in which gem, and how the repository builds, versions, releases, and
licenses those gems. These rules came with ADR 001 on 2026-10-24, from
Tokra's ADR 011. AGENTS.md has the commands that carry them out.

## Which crates, in which gem

Ferro binds crates that add something Ruby lacks. It skips crates that
duplicate the standard library or a popular gem, such as `serde_json`.

Two technical limits decide what can be split between gems.

1. **A Rust value cannot enter another gem's Rust API.** magnus checks every
   wrapped object against its own gem's type record, so handing one gem's
   wrapped object to another gem's method raises `TypeError` (magnus
   `r_typed_data.rs:380-400`). Plain Ruby values and byte strings cross
   freely, and so do raw window handles passed as Integers, which several
   crates take by design (wry and rfd take any `HasWindowHandle`; muda takes
   an `isize` HWND or a GTK window). A raw handle is unsafe, though: nothing
   tracks the window's lifetime, and it works only on the thread that owns
   the window.
2. **Some crates keep process-wide state.** Each extension keeps its Rust
   symbols private (rustc exports only `Init_*` and `ruby_abi_version`), so
   two copies of a crate never share code. The danger is state the
   operating system keeps once per process:

   | Crate | A second copy in the process |
   |---|---|
   | tao, every version | crashes: fixed Objective-C class names, and NSApp's one delegate |
   | tray-icon, every version | crashes: the fixed `TaoTrayTarget` class |
   | wry before 0.54.3 | crashes: fixed class names |
   | muda, with objc2 0.6.3 in either lockfile | crashes; on Windows, menu IDs also clash on a shared window |
   | global-hotkey | misroutes: on macOS the last copy swallows every hotkey |
   | notify-rust (macOS) | misroutes: each copy undoes the other's bundle hook and steals its delegate |
   | crossterm | misroutes: two copies race on stdin and terminal mode |

   arboard, rfd, open, os_info, sys-locale, auto-launch, keyring, image,
   dirs, url, idna, and time keep no such state. A second copy of them,
   even at another version, is harmless.

Tokra's native layer design (`doc/contributors/design/native.md`, "Where
each crate lives") gives the sources for this table: objc2 0.6.3 and 0.6.5
(`define_class.rs`), tao 0.37.2, wry 0.54.1 and 0.57.1 (commit 40a7032,
"fix(macOS): panic when loading multiple dylibs"), muda 0.21.2, tray-icon
0.26.1, global-hotkey 0.9.0, mac-notification-sys 0.6.15, and crossterm
0.29.0.

A crate in the table gets exactly one native home: no two gems that one
app might load link it. Those crates are tao, tray-icon, wry, muda,
global-hotkey, notify-rust, and crossterm. global-hotkey and notify-rust
have theirs in Ferro, because nothing else links them.

Two pairs only work together: tray-icon takes muda's menu objects, and
ratatui takes crossterm's backend and shares its terminal state. So
tray-icon and muda would share one gem, as would ratatui and crossterm.
RatatuiRuby links both today, so a Ferro gem for them waits until
RatatuiRuby can build on it instead. muda's keyboard accelerators on
Windows also need the loop that owns the window to call
`TranslateAcceleratorW`.

tao and wry stay in Tokra's own extension, and muda and tray-icon wait
with them, until a later decision settles where the windowing stack lives.
Any option that splits those crates across gems first needs Tokra on wry
0.54.3 or later and objc2 0.6.4 or later, the releases that stopped
panicking on a second copy.

## Layout

Ferro is one repository with one gem per folder under `gems/`. Submodules
would split the history without making a gem clonable on its own, since
each gem still needs the root tooling. Scoped Conventional Commits, such as
`fix(arboard): ...`, keep `git log -- gems/arboard` reading like the gem's
own history.

## Builds

Each gem is its own Cargo workspace with a committed `Cargo.lock`, built
with `--locked`. An installed gem compiles from its packaged files alone,
so `workspace = true` inheritance and a root lockfile would not ship.
During development the root Rakefile points every gem at one shared target
directory through `RB_SYS_CARGO_TARGET_DIR`, which rb-sys's generated
Makefile honors, so a dependency compiles once. A root check
(`tasks/pin_check.rb`) fails the gate when two gems pin different magnus
or rb-sys versions.

Ruby owns each gem's public API, with RDoc and RBS; the native layer
defines the wrapped types and private methods that reach the crate, since
Steep and RDoc read Ruby, not Rust.

## Versions and releases

A gem's version answers to its own API, not the crate's, and the crate
version it binds appears in its README and gemspec metadata. Release tags
carry the gem name: `ferro-arboard/v0.1.0`. A root release task replaces
`bundler/gem_tasks`, whose `v0.1.0` tags would collide between gems.
Publishing to RubyGems.org stays a human step; AGENTS.md says who runs
each release task.

Tokra's plugins depend only on released Ferro versions, a published gem or
a pushed release tag, so Ferro work comes first when a plugin needs a
binding.

## Licenses

A gem's Ruby and Rust code takes the license of the crate it binds:
`ferro-arboard` is `MIT OR Apache-2.0` because arboard is. That keeps a
binding as reusable as the code it binds.

Code that belongs to no crate follows RatatuiRuby's split. Shared code that
apps link at runtime is `LGPL-3.0-or-later`, so an app may use it without
taking on copyleft; Ferro has none yet. Tooling that apps never link, such
as the root Rakefile, the gate's tasks, and any devtools gem, is
`AGPL-3.0-or-later`. Docs are `CC-BY-SA-4.0`, code snippets in docs are
`MIT-0` so readers can paste them freely, and lockfiles are `CC0-1.0`.

Tokra stays `AGPL-3.0-or-later` and depends on Ferro gems the way it
depends on any permissively licensed library.

## Ruby versions

Ferro gems require Ruby 4.0 or later, and CI runs on each supported
release. When a new Ruby ships, Ferro adds it and keeps the older ones
until they reach end of life. Only then does the floor rise. No gem is
known to need a feature new in Ruby 4.0, so the floor could drop to 3.x
later; dropping it never breaks anyone, while raising it does.
