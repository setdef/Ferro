<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Cargo Features

A Rust crate's Cargo features are optional parts chosen at compile time.
A Rust app developer picks them in their own `Cargo.toml`. A Ferro gem
compiles on the app developer's machine at install, so the same choice can
be theirs. This document says how each gem sorts its crate's features, and
how an app developer chooses one at install. The maintainer accepted this
design on 2026-11-05, when plan 011 asked how features should work; the
draft's open questions were settled as its author recommended, each open
to the maintainer's later word.

The sorting is built: every gem's `Cargo.toml` follows it. Choosing at
install is designed and not built yet. No gem's `extconf.rb` reads
`--features`, no gem defines `FEATURES`, and every gem builds its crate's
defaults plus its built-in features. Plan 011 lists the work.

## Built in, dropped, or offered

Every feature is one of three kinds.

| Kind | Rule | Today |
|---|---|---|
| **built in** | adds something Ruby code reaches, or the gem's native layer uses, and excludes nothing | every feature not listed below |
| **dropped** | reaches only Rust: another crate's traits, a Rust runtime or logger, a target Ruby lacks, a crate's own test harness | time's `rand`, `rand08`, `rand09`, `rand010`, `quickcheck`, `wasm-bindgen`; notify-rust's `tokio`, `z-with-tokio`, `env_logger`, `debug_namespace`; url's `debugger_visualizer`; url's and global-hotkey's `serde`, global-hotkey's `tracing`, and time's `serde-human-readable` and `serde-well-known` |
| **offered** | changes or replaces behavior, excludes another feature, or needs a library or environment not every machine has | below |

A dropped feature is translated away, like a lifetime: no flag reaches it.
An offered feature keeps the crate's own default. The gem's default build
is the crate's default features plus every built-in one, so `gem install`
gives what a Rust program depending on the crate gets.

The reasons fall into the three kinds. Some features reach only Rust.
time's `rand08`, `rand09`, `rand010`, and `quickcheck` implement other
crates' traits; notify-rust's `tokio` and `z-with-tokio` need a tokio
runtime around every call, which Ruby code never runs inside; its
`env_logger` is an optional dependency that `src/` never names
(notify-rust 4.18.2 `Cargo.toml:119-121`); its `debug_namespace` renames
the bus for the crate's own tests (`src/xdg/mod.rs:41-48`); time's
`wasm-bindgen` compiles only for WebAssembly; url's `debugger_visualizer`
cannot build from the published crate ([plan 005](../plan/005.md),
decision 2).

Some features change or replace behavior, so one build cannot hold both
sides. rfd's `gtk3` and `xdg-portal` exclude each other: its build script
panics with both, and with neither (rfd 0.17.2 `build.rs:10-17`). time's
`large-dates` widens years to ±999,999 and changes `Display` and RFC 2822
([plan 007](../plan/007.md), decision 2). notify-rust's `preview-macos-un`
replaces the macOS backend and its API (`src/lib.rs:172-193`), and works
only inside a signed app bundle.

Some features need what not every machine has. rfd's `gtk3` needs GTK's
headers; `common-controls-v6` makes the extension fail to load under a
`ruby.exe` whose manifest does not select ComCtl32 v6
([plan 002](../plan/002.md), decision 7); notify-rust's `d` links
`libdbus-1`, and `d_vendored` builds it from source
([plan 003](../plan/003.md), decision 2).

A default feature that needs a system library may be left out at install
where the crate allows it, through `--no-default-features` and the
features wanted; rfd's `wayland` is the first such case.

## Offered features

| Gem | Option | What it does | With the defaults |
|---|---|---|---|
| ferro-rfd | `--no-default-features --features=gtk3` | GTK dialogs on Linux and the BSDs, as Tauri's dialog plugin builds; needs GTK's headers | excludes `xdg-portal`, so it replaces the defaults; `wayland` serves only the portal (`src/backend/xdg_desktop_portal/window_identifier/mod.rs:8`) |
| ferro-time | `--features=large-dates` | years to ±999,999; `+` before five-digit years; RFC 2822 refuses them | coexists, and changes behavior |
| ferro-notify-rust | `--features=preview-macos-un` | macOS UserNotifications, for a signed app bundle | coexists, and replaces the macOS API |

Each gem's plan binds the items its offered feature compiles, such as
notify-rust's `check_bundle` and `request_auth` (plan 003, rows 11, 18,
24, and 59). notify-rust's option is offered once those are bound; until
then two features are offered, rfd's `gtk3` and time's `large-dates`.

Three more stay unoffered until someone asks, each for a reason: rfd's
`common-controls-v6`, whose load failure is unverified on Windows; and
notify-rust's `d` and `d_vendored`, which add a second transport Ruby sees
only through `DBUSRS` and which the crate means to make exclusive with `z`
(`src/xdg/mod.rs:390-392`). Offering one later is a `Cargo.toml` line, a
test job, and a CHANGELOG entry.

Each offered set costs a CI job, which is why only these are offered.

## Choosing at install

Options are Cargo's `--features` and `--no-default-features`, with the
crate's feature names verbatim:

```sh
gem install ferro-time -- --features=large-dates
bundle config set --local build.ferro-rfd "--no-default-features --features=gtk3"
```

The second writes `BUNDLE_BUILD__FERRO___RFD` to the app's
`.bundle/config`; commit it, or set that variable where the app builds.

Cargo's own flags keep the crate's vocabulary. Ruby's idiom,
`--enable-gtk3` through `enable_config`, would be a second vocabulary for
Cargo's, with no way to say "without the defaults", and it shares
`$configure_args` with Ruby's own build flags. A gem per combination, such
as `ferro-rfd-gtk3`, multiplies releases, and an app with two of them loads
two copies of a crate, which notify-rust must not have
([repository.md](repository.md), "Which crates, in which gem"). A Ferro
environment variable, or rb_sys's `RB_SYS_CARGO_FEATURES`, is not stored
per app by Bundler and is forgotten by `gem pristine`, and rb_sys's
applies to every rb_sys gem and only once a feature is already passed.
Cargo features exist only at compile time, so there is no choice at run
time.

Each gem's `Cargo.toml` names the crate's defaults and offered features in
its own `[features]` table, each forwarding to the crate's
(`gtk3 = ["rfd/gtk3"]`), with `default` listing the crate's defaults and
the dependency taking `default-features = false`. Built-in features stay
on the dependency line, so `--no-default-features` cannot remove them.
`extconf.rb` reads `arg_config("--features")` and
`arg_config("--no-default-features")` and hands them to rb_sys as
`r.features` and `r.extra_cargo_args`, beside `--locked`. A gem with no
offered feature declares no `[features]` of its crate's, so any
`--features` it is given meets Cargo's refusal.

The `test-hooks` feature some gems declare is not an option an app
chooses: only the repository's own build turns it on (the `bind-crate`
skill, "Test hooks").

### Bad choices fail at install, in the crate's words

Every refusal comes before the gem loads, as `Gem::Ext::BuildError`:

- A name the gem does not offer, dropped ones included, gets Cargo's
  `the package 'ferro_rfd' does not contain this feature: rand08`.
- An exclusive pair gets the crate's own check, so it cannot drift from
  the crate (plan 011, question 5): rfd's
  ``You can't enable both `gtk3` and `xdg-portal` features at once`` and
  ``You need to choose at least one backend: `gtk3` or `xdg-portal` ...``.
  Where an exclusion lives only in a crate's docs, `extconf.rb` refuses
  before Cargo runs, naming both features. None does today.
- `--features` without `=` and a list, which mkmf reads as `true`, gets
  `extconf.rb`'s own message: `--features takes a comma-separated list, as
  Cargo's does: --features=gtk3`.

### The extension says how it was built

A gem with offered features defines `FEATURES`, a frozen Array of the
feature names in its `[features]` table that its extension was compiled
with, read with `cfg!(feature = ...)`, as `Ferro::Rfd::PLATFORM` reports
the platform. An item a feature gates is defined only when that feature
is built, as the platform row of [translation.md](translation.md) has it,
so `respond_to?` answers. The process holds one copy of each gem, so the
choice is the app's. A library that needs a feature checks `FEATURES` when
required and raises, as Tokra will for `large-dates`, which Tauri parity
needs off.

### Precompiled gems carry the defaults

A platform gem runs no `extconf.rb`, so it ignores build options and
carries the default build. Ferro never ships one per option set. An app
that wants an option asks for the source gem as well:

```ruby
gem "ferro-rfd", force_ruby_platform: true
```

`FEATURES` shows which build loaded. Fledge, which compiles an app's gems
for its bundle, passes the bundle's `build.<gem>` settings through; how is
Fledge's to design, asked of it when Ferro ships a precompiled gem.

### Bundler's caveats

Bundler treats an installed gem as done (`source/rubygems.rb:165-169`),
so changing `build.<gem>` rebuilds nothing until
`bundle pristine ferro-rfd`, which reads the setting again. Bundler's
`global_gem_cache` keys built extensions by platform, Ruby, source, and
gem version, not build options (`source.rb:81-88`), so with it on, one
app can receive another's build. Each offering gem's README says both,
and `FEATURES` exposes either. `CONFIGURE_ARGS` reaches every extension
in an install, Ferro's and others', so the READMEs name `build.<gem>`
instead.

## Tests and CI build every offered option

`tasks/ferro_gems.rb` lists each gem's option sets as build arguments.

- **The gate** runs Clippy once more per option set (`cargo clippy
  --locked --all-targets` plus the set), on every platform, so code a
  feature gates still compiles warning-free.
- **CI** adds one job per option set, on the platform where the feature
  changes code and the newest Ruby: the compile task passes the set as
  rake-compiler's config options (rake-compiler 1.3.2
  `extensiontask.rb:100-107`), then the gem's tests run. Tests branch on
  `FEATURES`, so each build fails when its own side of a gated behavior is
  wrong, and the default build fails when an option leaks into it.
- **The package check's full mode** installs each set from the built
  `.gem` with `gem install --local <gem> -- <set>`, proving the arguments
  reach Cargo and `--locked` holds from packaged files alone.

Since Cargo locks every declared feature, the committed `Cargo.lock`
holds each option's crates, they pass the license review with the rest,
and an install builds any option offline.

## What the tools do with a build option

- **RubyGems** passes everything after `--` in `gem install ferro-x -- ...`
  to `extconf.rb` as arguments (RubyGems 4.0.20,
  `rubygems/ext/ext_conf_builder.rb:24-27`), records them in
  `build_info/<gem>.info` (`rubygems/installer.rb:902-918`), and
  `gem pristine` reuses them (`rubygems/commands/pristine_command.rb:205`).
- **Bundler** reads `build.<gem>` from its settings, splits it like a
  shell, and passes it as those same arguments (Bundler 4.0.4,
  `installer/gem_installer.rb:44-60`). Inside an app,
  `bundle config set` writes the app's `.bundle/config` unless told
  `--global` (`cli/config.rb:178-191`, `settings.rb:130-134`), under the key
  `BUNDLE_BUILD__FERRO___RFD`, which the environment can also set
  (`settings.rb:522-530`). Gemfile options have no build key
  (`dsl.rb:19-20`), and `Gemfile.lock` records none.
- **mkmf** merges Ruby's own `configure_args`, the `CONFIGURE_ARGS`
  environment variable, and `ARGV` into one table, `$configure_args`,
  folding `_` to `-` in each flag's name (Ruby 4.0.9 `mkmf.rb:110-127`).
  `arg_config`, `with_config`, and `enable_config` read that table
  (`:1741-1814`). A flag given with a space, `--features gtk3`, stores
  `true` and drops the next word (`:117-126`). A Ruby's table holds the
  flags of its own build, such as `--enable-yjit` and
  `--enable-load-relative`.
- **rb_sys** 0.9.130 builds `--features` from `r.features` only when the
  list is non-empty (`cargo_builder.rb:77`) and writes the list into the
  Makefile as `RB_SYS_CARGO_FEATURES ?= ...` (`mkmf.rb:73`, `:219`,
  `:336-344`), so an environment variable of that name replaces it, for
  every rb_sys gem in that install, and only when `extconf.rb` passed a
  feature. rb_sys forwards none of `extconf.rb`'s arguments to Cargo: its
  `ARGV` copy tests an empty array and never runs (`mkmf.rb:171-172`), and
  `Gem::Command.build_args` (`cargo_builder.rb:80`) is empty in
  `extconf.rb`'s own process. Each gem's `extconf.rb` passes only
  `--locked`, and `--enable-test-hooks` where the gem has test hooks.
- **Cargo** resolves `Cargo.lock` over every feature a workspace declares,
  so declaring a forwarding feature adds its crates to the lockfile even
  while it is off. Asked for a feature the package lacks, Cargo stops with
  `the package 'ferro_time' does not contain this feature: nope`.
- **Precompiled gems** carry no `extconf.rb`, so RubyGems builds nothing
  and ignores build arguments without a word
  (`rubygems/ext/builder.rb:257-258`). Bundler can refuse a gem's
  platform build with `force_ruby_platform: true` in the Gemfile.
