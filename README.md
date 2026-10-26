<!--
SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Ferro

[![Certified Shovelware](https://justin.searls.co/img/shovelware.svg)](https://justin.searls.co/shovelware/)
[![CI](https://github.com/setdef/Ferro/actions/workflows/ci.yml/badge.svg?branch=trunk)](https://github.com/setdef/Ferro/actions)

Ruby gems that bind Rust crates one to one.

Rust has well-tested crates for jobs Ruby's standard library leaves alone:
the system clipboard, native file dialogs, desktop notifications, global
hotkeys. Binding one yourself means writing and maintaining native code, and
a binding that invents its own API leaves you translating between its docs
and the crate's.

Each Ferro gem binds one crate and mirrors it: the crate's names, errors,
and behavior, translated only where Rust has no Ruby meaning. The crate's
own documentation stays your guide. Ferro spun out of
[Tokra](https://github.com/setdef/Tokra), whose plugins build on these gems.

## Gems

| Gem | Crate | Status |
|---|---|---|
| [ferro-arboard](gems/arboard/README.rdoc) | [arboard](https://github.com/1Password/arboard) 3.7.0, the system clipboard | 0.1.0.pre.1, unreleased |
| [ferro-rfd](gems/rfd/README.rdoc) | [rfd](https://github.com/PolyMeilex/rfd) 0.17.2, native file and message dialogs | 0.1.0.pre.1, unreleased |

## Using a gem

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
```
<!-- SPDX-SnippetEnd -->

Each gem compiles a Rust extension when it installs, so you need Rust and
Cargo. Its README names the versions.

Nothing is on RubyGems.org yet. Each release is a tag, such as
`ferro-arboard/v0.1.0`, so take a gem from its tag:

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-SnippetCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: MIT-0
-->
```ruby
# Gemfile
gem "ferro-arboard", git: "https://github.com/setdef/Ferro", tag: "ferro-arboard/v0.1.0", glob: "gems/*/*.gemspec"
```
<!-- SPDX-SnippetEnd -->

## Contributing

Ferro needs Ruby 4.0 and Rust; [mise](https://mise.jdx.dev) installs both
from `mise.toml`, along with the [REUSE tool](https://reuse.software) the
gate uses.

<!-- SPDX-SnippetBegin -->
<!--
  SPDX-SnippetCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: MIT-0
-->
```sh
mise install
mise x -- pip install "reuse[charset-normalizer]==6.2.0"
bundle install
bundle exec rake            # the gate: every check, across every gem
bundle exec rake gate:arboard   # one gem's checks, while you work on it
```
<!-- SPDX-SnippetEnd -->

Each gem releases on its own, through rake tasks: `rake bump:arboard:patch`
commits a release, and `rake release:arboard:tag` tags it and pushes the
tag. [AGENTS.md](AGENTS.md) says who may run which.

Start with [AGENTS.md](AGENTS.md), which holds the rules for people and
agents alike, and [ADR 001](doc/contributors/adr/001.md), which explains how
a crate becomes a gem.

## License

Each gem takes its crate's license: ferro-arboard is MIT OR Apache-2.0, as
arboard is, and ferro-rfd is MIT, as rfd is. The repository's tooling is
AGPL-3.0-or-later. Documentation is CC-BY-SA-4.0, code snippets in it are
MIT-0, and lockfiles are CC0-1.0. Every file says which applies;
[REUSE](https://reuse.software) checks it, and the texts are in
[LICENSES](LICENSES).
