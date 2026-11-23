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

## The windowing stack

tao, wry, muda, tray-icon, and window-vibrancy share one gem with one
native library ([ADR 001](../adr/001.md)). wry builds its webview into
tao's window as a Rust value, muda and window-vibrancy follow the window's
pointers, tray-icon takes muda's menus as Rust values, and tao and
tray-icon crash as a second copy, so no split between gems is sound.

Inside the gem each crate has a module of its own, required by its own
path: `Ferro::Tao`, `Ferro::Wry`, `Ferro::Muda`, `Ferro::TrayIcon`, and
`Ferro::WindowVibrancy`. Each module answers to its crate alone, by every
rule a gem of its own would follow, and its files carry that crate's
license (tao is `Apache-2.0`; the others are `Apache-2.0 OR MIT`). The
gem's plan names the gem. The name must not be one a crate has, since
`ferro-<crate>` names that crate's gem.

The gem is not built yet. Until it is, Tokra's own extension is the one
native home of these crates. The two can never load in one process, so
Tokra moves from its extension to the gem whole, not a class at a time.

What the gem holds, and what it does not:

- **The crates' APIs,** at the versions Tauri's requirements admit
  ("Versions and releases"). What Tauri calls comes first; an item nothing
  calls yet may be deferred in the plan, with that reason.
- **The machinery any Ruby binding of these crates needs:** using and
  dropping each platform object on its own thread, waking the loop for
  Ruby's signals, keeping a Ruby exception out of the crates' frames, and
  handing the GVL to other Ruby threads while the loop waits
  ([translation.md](translation.md), "The error rule").
- **Calls from any Ractor,** where the crate's type allows them: tao's
  `EventLoopProxy` and wry's `RequestAsyncResponder` at the least, each
  with a test that starts a Ractor ([translation.md](translation.md),
  "Ractors").
- **None of Tauri's own behavior.** Tauri's runtime logic is Ruby in
  Tokra. Where Tauri's runtime is itself the function the platform calls
  (a window procedure, a GTK signal handler, a WebView2 event handler),
  that code is no crate's API, and no Ferro gem holds it as Tauri wrote
  it.

One question is open. Tokra's Ruby needs a way to be such a platform
callback. The gem needs a Ruby block called inside a platform callback in
any case, for wry's handlers that answer at once, such as
`with_navigation_handler` (wry 0.54.1, `src/lib.rs:1258`). Whether the
platform crates' own calls on the objects tao and wry hand out (`windows`,
`gtk`, `webview2-com`, `objc2-app-kit`) are then bound here one to one, by
need, with a block as the callback, or Tokra reaches the platform from
Ruby another way, waits for a spike of three things: a block called while
the platform holds no GVL, a block called inside tao's drain of its
events, and the cost of a block for each message.

## Layout

Ferro is one repository with one gem per folder under `gems/`. Submodules
would split the history without making a gem clonable on its own, since
each gem still needs the root tooling. Scoped Conventional Commits, such as
`fix(arboard): ...`, keep `git log -- gems/arboard` reading like the gem's
own history.

## Builds

Each gem is its own Cargo workspace with a committed `Cargo.lock`, built
with `--locked`. An installed source gem compiles from its packaged files alone,
so `workspace = true` inheritance and a root lockfile would not ship.
During development the root Rakefile points every gem at one shared target
directory through `RB_SYS_CARGO_TARGET_DIR`, which rb-sys's generated
Makefile honors, so a dependency compiles once. A root check
(`tasks/pin_check.rb`) fails the gate when two gems pin different magnus
or rb-sys versions.

A gem may also be built precompiled, for one platform and one Ruby, so it
installs with no Rust ([plan 015](../plan/015.md)). `PlatformGem`
(`tasks/platform_gem.rb`) builds it from the source gem, not from the
repository: it compiles the packaged extension as RubyGems would, with
`extconf.rb` given no options, so the test hooks stay off, and packs the
source gem's files with the extension added, no extension to compile,
and no `rb_sys` dependency. Each platform builds its own, natively. Its
platform names no darwin version and names glibc on Linux, and a gem
built on a Ruby preview requires exactly that preview, whose ABI Ruby
checks. A released version's precompiled gems are built from its tag's
sources by the tooling of the commit that runs the build. The Platform
gems workflow builds ferro-url's and keeps them as artifacts; it
publishes nothing.

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

A gem binds its crate's latest release. A gem Tokra builds on binds
instead the newest release inside the version requirement that the Tauri
component Tokra ports states for the crate, in that component's
`Cargo.toml`, and moves when Tokra moves to a newer Tauri. The requirement
is the measure, not Tauri's `Cargo.lock`: a Tauri application ships what
Cargo resolves inside the requirement when the application is built, and
Cargo does not pass a library's lock on to what depends on it
([Cargo's FAQ](https://doc.rust-lang.org/cargo/faq.html), "Why have
Cargo.lock in version control?"). Where the requirement admits the crate's
latest release, as `"2"` does for url, the two rules agree. Where it holds
the crate to one 0.x line, as Tauri holds tao to 0.34, they do not, and
Tauri's line wins, because Tokra's fidelity is to Tauri.

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
