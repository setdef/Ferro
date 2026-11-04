<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Ferro

[![CI](https://github.com/setdef/Ferro/actions/workflows/ci.yml/badge.svg?branch=trunk)](https://github.com/setdef/Ferro/actions/workflows/ci.yml) [![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-a2c93e)](#license) [![Ruby](https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Fsetdef%2FFerro%2Ftrunk%2Fgems%2Furl%2Fferro-url.gemspec&search=spec%5C.required_ruby_version%20%3D%20%22(.*)%22&replace=%241&label=Ruby&logo=ruby&color=a2c93e)](#compatibility) [![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux-a2c93e)](#compatibility) [![Forum: Discussion](https://img.shields.io/badge/forum-discussion-5865F2.svg?logo=discourse)](https://forum.setdef.com/tags/c/ferro/discussion) [![Forum: Bug Reports](https://img.shields.io/badge/forum-bug_reports-4954d5.svg?logo=discourse)](https://forum.setdef.com/tags/c/ferro/bug) [![Forum: Announcements](https://img.shields.io/badge/forum-announcements-3b44ac.svg?logo=discourse)](https://forum.setdef.com/tags/c/ferro/announcement) [![Certified Shovelware](https://justin.searls.co/img/shovelware.svg)](https://justin.searls.co/shovelware/)

Ruby gems that bind Rust crates one to one: the clipboard, file dialogs,
notifications, global hotkeys, URLs, domain names, and dates.

Some jobs have a well-tested Rust crate and no Ruby equivalent. To read
the system clipboard on three operating systems, or parse a URL the way a
browser does, you would otherwise write and maintain native code
yourself. Each Ferro gem wraps one crate in a Rust extension and
keeps the crate's names, error messages, and behavior, so the crate's
documentation answers your questions about the gem too.

Ferro is for Ruby developers who need a crate's behavior in Ruby: a
desktop app, a command-line tool, or a service that has to agree with a
Rust program or a browser. It is also where [Tokra](https://github.com/setdef/Tokra),
a Ruby port of Tauri, gets its clipboard, dialogs, notifications, global
shortcuts, URLs, and dates.

Compared with what you may use now:

- **A binding you write.** [magnus](https://github.com/matsadler/magnus) and
  [rb-sys](https://github.com/oxidize-rb/rb-sys) make binding a crate
  possible, and Ferro is built on both. A Ferro gem adds the parts each
  binding repeats: every error variant as a Ruby exception class, RBS
  signatures, RDoc for every public method, and tests against the real
  crate on Linux, macOS, and Windows.
- **Ruby's standard library.** Ruby's `URI` follows RFC 3986, and browsers
  follow the [WHATWG URL Standard](https://url.spec.whatwg.org/), so `URI`
  rejects strings a browser accepts. ferro-url gives you the browser's
  answer, as the example below shows. Ruby's `Time` and `Date` keep
  working beside ferro-time, which parses and formats by the time crate's
  rules instead of Ruby's.

## Example

This script parses a URL a person might type, with a Unicode host and
backslashes for slashes:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-SnippetCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: MIT-0
-->
```ruby
require "ferro/url"

url = Ferro::Url::Url.parse("HTTPS://Bücher.example\\docs\\..\\index.html?q=café")
puts url.as_str
puts url.host_str
```
<!-- SPDX-SnippetEnd -->

It prints the URL as the WHATWG URL Standard serializes it: the scheme in
lowercase, the host in Punycode, backslashes read as slashes, and `..`
resolved:

```
https://xn--bcher-kva.example/index.html?q=caf%C3%A9
xn--bcher-kva.example
```

`URI.parse` raises `URI::InvalidURIError` on the same string.

## Gems

| Gem | Binds | For | Latest release |
|---|---|---|---|
| [ferro-arboard](gems/arboard/README.rdoc) | [arboard](https://docs.rs/arboard/3.7.0) 3.7.0 | The system clipboard: text, HTML, images, and file lists | `ferro-arboard/v0.1.0.pre.2` |
| [ferro-rfd](gems/rfd/README.rdoc) | [rfd](https://docs.rs/rfd/0.17.2) 0.17.2 | Native file and message dialogs | `ferro-rfd/v0.1.0.pre.3` |
| [ferro-notify-rust](gems/notify-rust/README.rdoc) | [notify-rust](https://docs.rs/notify-rust/4.18.2) 4.18.2 | Desktop notifications, with action buttons | `ferro-notify-rust/v0.1.0.pre.4` |
| [ferro-global-hotkey](gems/global-hotkey/README.rdoc) | [global-hotkey](https://docs.rs/global-hotkey/0.9.0) 0.9.0 | Keyboard shortcuts that work while another app has focus | `ferro-global-hotkey/v0.1.0.pre.1` |
| [ferro-url](gems/url/README.rdoc) | [url](https://docs.rs/url/2.5.8) 2.5.8 | URLs parsed by the WHATWG URL Standard, and form-encoded query strings | `ferro-url/v0.1.0.pre.1` |
| [ferro-idna](gems/idna/README.rdoc) | [idna](https://docs.rs/idna/1.1.0) 1.1.0 | Internationalized domain names, to and from Punycode | `ferro-idna/v0.1.0.pre.1` |
| [ferro-time](gems/time/README.rdoc) | [time](https://docs.rs/time/0.3.55) 0.3.55 | Dates, times, offsets, and durations, parsed and formatted as Rust does | `ferro-time/v0.1.0.pre.4` |

Every release so far is a prerelease, and the API of each gem can change
before 1.0. The [tags page](https://github.com/setdef/Ferro/tags) lists
every release.

## Compatibility

| | Linux | macOS | Windows |
|---|---|---|---|
| Ruby | 4.0 or newer | 4.0 or newer | 4.0 or newer, from RubyInstaller |
| Rust | 1.89 or newer | 1.89 or newer (1.99 or newer on macOS 27) | 1.89 or newer, with the `x86_64-pc-windows-gnu` toolchain |
| To build | libclang (`libclang-dev` on Debian and Ubuntu) | Xcode's command-line tools | LLVM's libclang |
| Tested in CI | X11 and Wayland | Yes | Yes |

CI runs every gem's tests on Ubuntu, macOS, and Windows, with Ruby 4.0.
On Linux it runs them twice, once under X11 and once under Wayland. Rust
1.89 covers every gem; some gems build with an older Rust, and their
READMEs name it.

Each gem compiles its Rust extension when you install it. The build runs
`cargo --locked`, so it compiles the exact dependency versions the gem was
tested with. On Windows, RubyInstaller's Ruby is a MinGW build, so Rust
needs its GNU toolchain rather than MSVC; the
[CI workflow](https://github.com/setdef/Ferro/blob/trunk/.github/workflows/ci.yml)
shows one working setup for libclang there.

Some gems need more from the system. Each gem's README gives the details:

- **ferro-rfd** on Linux needs `pkg-config` and libwayland's development
  files to build, and libdbus, an XDG desktop portal, and `zenity` to show
  dialogs.
- **ferro-notify-rust** on Linux needs a running notification server,
  which desktops include.
- **ferro-global-hotkey** on Linux works only through an X server, and
  under Wayland only with XWayland. On macOS and Windows it needs an event
  loop, as a windowed app has.
- **ferro-rfd** and **ferro-notify-rust** on macOS need the main thread's
  run loop for some calls: make them from the main thread, or run an event
  loop there, as a windowed app does.

## Installation

No Ferro gem is on RubyGems.org yet, so `gem install` and `bundle add`
will not find them. Bundler can install each gem from its release tag in
this repository. Add one line per gem to your Gemfile:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-SnippetCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: MIT-0
-->
```ruby
# Gemfile
gem "ferro-url", git: "https://github.com/setdef/Ferro", tag: "ferro-url/v0.1.0.pre.1",
  glob: "gems/url/*.gemspec"
```
<!-- SPDX-SnippetEnd -->

Then run:

```sh
bundle install
```

The `tag` names the release. Bundler needs the `glob` to find the gem:
by default it looks for gemspecs at most one folder deep, and each Ferro
gemspec sits two folders down, in `gems/<folder>/`. Name only that gem's
folder (`gems/rfd/*.gemspec` for ferro-rfd, and so on), so that each
`git:` line gives Bundler one gem, at the tag you chose for it.

## Usage

Require each gem by the crate's name, with underscores for hyphens, and
call the crate's API through the module of the same name:

| Gem | Require | Module |
|---|---|---|
| ferro-arboard | `require "ferro/arboard"` | `Ferro::Arboard` |
| ferro-rfd | `require "ferro/rfd"` | `Ferro::Rfd` |
| ferro-notify-rust | `require "ferro/notify_rust"` | `Ferro::NotifyRust` |
| ferro-global-hotkey | `require "ferro/global_hotkey"` | `Ferro::GlobalHotkey` |
| ferro-url | `require "ferro/url"` | `Ferro::Url` |
| ferro-idna | `require "ferro/idna"` | `Ferro::Idna` |
| ferro-time | `require "ferro/time"` | `Ferro::Time` |

Class and method names are the crate's, so the crate's documentation on
docs.rs applies. Where Rust has no Ruby meaning, every gem translates it
the same way:

- A `Result` returns its value or raises. Each error variant has an
  exception class, with the crate's message.
- An `Option` is the value or `nil`.
- A struct with public fields is a `Data` value. An enum's plain variants
  are constants, and its variants with data are `Data` classes.
- Byte buffers are binary Strings, and paths are Strings.
- A method that exists on one platform in Rust exists only there in Ruby,
  so `respond_to?` tells you whether you can call it.
- A panic inside the crate raises an exception instead of ending your
  Ruby process.

Here, ferro-arboard reads and writes the clipboard:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-SnippetCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: MIT-0
-->
```ruby
require "ferro/arboard"

clipboard = Ferro::Arboard::Clipboard.new
clipboard.set_text("Hello from Ruby")
clipboard.get_text # => "Hello from Ruby"

begin
  clipboard.clear
  clipboard.get_text
rescue Ferro::Arboard::Error::ContentNotAvailable => e
  puts e.message
end
```
<!-- SPDX-SnippetEnd -->

Each gem's README lists what differs from calling the crate from Rust,
such as which calls release Ruby's global VM lock, and which crate items
it leaves unbound and why.

### Upgrading

Each gem's version follows the gem's API, not the crate's version. A
release can bind a new crate version or change one gem's API with no
change to the other gems. To upgrade, read the gem's CHANGELOG,
change the `tag` in your Gemfile, and run `bundle install`. Before 1.0, a
prerelease can break the API, and its CHANGELOG says how.

### Using Ferro with Tokra

Tokra and its plugins depend on these Ferro gems:

| Tokra gem | Ferro gems |
|---|---|
| tokra | ferro-url |
| tokra-clipboard | ferro-arboard |
| tokra-dialog | ferro-rfd |
| tokra-notification | ferro-notify-rust, ferro-time, ferro-url |
| tokra-global-shortcut | ferro-global-hotkey |

Each Tokra gemspec pins an exact Ferro version, and Bundler does not read
Tokra's Gemfile when it installs your app. So your app's Gemfile needs a
`git:` line, as shown under Installation, for each Ferro gem the Tokra
gems you use depend on, at the tag of the version they pin.

## Documentation

- Each gem's README.rdoc, linked from the table under Gems, covers its
  installation needs, a worked example, and the differences from the
  crate.
- Each gem's CHANGELOG.md, beside its README, records every change a user
  of that gem can see.
- The crate's page on docs.rs, linked from the same table at the version
  each gem binds, documents the crate's API under the names the gem keeps.
- Every public Ruby method has RDoc in the gem's `lib/` and an RBS
  signature in its `sig/`.

## Reporting problems

Report a bug under
[Bug Reports](https://forum.setdef.com/tags/c/ferro/bug) on the setdef
forum, and ask questions under
[Discussion](https://forum.setdef.com/tags/c/ferro/discussion). Ferro's
GitHub repository has issues turned off. Name the gem and its version,
your operating system, `ruby -v` and `rustc -V`, the code you ran, and
its full output.

## Contributing

Ferro's rules for people and agents alike are in [AGENTS.md](AGENTS.md),
which also names the design records behind them. To build and check
every gem, install the toolchains that `mise.toml` pins with
[mise](https://mise.jdx.dev), and the [REUSE tool](https://reuse.software):

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-SnippetCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: MIT-0
-->
```sh
mise install
mise x -- pip install "reuse[charset-normalizer]==6.2.0"
bundle install
bundle exec rake                # every check, across every gem
bundle exec rake gate:arboard   # one gem's checks
```
<!-- SPDX-SnippetEnd -->

## License

Each gem is under the license of the crate it binds:

| Gem | License |
|---|---|
| ferro-arboard | MIT OR Apache-2.0 |
| ferro-rfd | MIT |
| ferro-notify-rust | MIT OR Apache-2.0 |
| ferro-global-hotkey | Apache-2.0 OR MIT |
| ferro-url | MIT OR Apache-2.0 |
| ferro-idna | MIT OR Apache-2.0 |
| ferro-time | MIT OR Apache-2.0 |

A gem's package holds only code under that license, plus its README
(CC-BY-SA-4.0), the README's code examples (MIT-0, so paste them freely),
and its lockfile (CC0-1.0). The Rust crates Cargo downloads to build the
extension are under their licenses; ferro-url's and ferro-idna's READMEs
name the Unicode-3.0 ones. The repository's tooling, which no gem ships,
is AGPL-3.0-or-later. Every file names its license, the
[REUSE tool](https://reuse.software) checks them, and the texts are in
[LICENSES](LICENSES).

## How Ferro is made

Ferro's maintainer describes the three ways code and prose come to exist
like this:

> I use three words for how code and prose comes to exist. Code or prose I wrote, I typed by hand, with nothing generated. Code or prose I wrought, an AI agent generated while I iterated with it, and I reviewed every change before committing it, so I take responsibility for every diff. Code or prose I requested, an agent built with little or no review from me, in the style of a "dark factory."

Ferro is requested. AI agents generated its code, tests, and
documentation, this README included, under the rules in AGENTS.md, and
commits name the model in their footer. The gate that CI runs stands in
for review: tests against the real crate on Linux, macOS, and Windows,
plus RuboCop, Steep, RBS, RDoc coverage, Clippy, REUSE, and a check that
loads each packaged gem outside the repository. On
[declare-ai.org](https://declare-ai.org/1.0.0/assess.html)'s scale, the
assistance is [creative](https://declare-ai.org/1.0.0/creative.html),
because the agents made design and wording choices under the
maintainer's direction.
