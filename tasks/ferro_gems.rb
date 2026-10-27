# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "open3"
require "rbconfig"
require_relative "package_check"

# One gem under gems/, and what the root tasks need to know about it.
#
# Every gem is a plain folder with its own gemspec, Cargo workspace, and
# tests (ADR 001, section 4). The root Rakefile builds, tests, lints, and
# packages each one from this description, so adding a gem means adding an
# entry to FERRO_GEMS rather than another Rakefile.
#
# [short_name] The name in task names and commit scopes: +arboard+ for
#   <tt>rake test:arboard</tt> and <tt>feat(arboard): ...</tt>.
# [name] The gem's name, such as <tt>ferro-arboard</tt>.
# [crate] The native crate's directory, relative to the gem.
# [extension] The compiled extension's path inside the gem, without its
#   file extension.
# [packaged] The paths the gemspec ships, relative to the gem.
# [native_namespace] The module the native extension defines.
# [platform_sigs] Signature files that describe one platform's API, by the
#   platform name the extension reports: a path, or an Array of them, and a
#   file may serve several platforms; rbs:parity skips the others.
# [platform_probe] Ruby source that prints the extension's platform name.
# [smoke] Ruby source the packaging check runs against the built gem.
# [rbs_libraries] The standard libraries whose types the gem's signatures
#   name, such as +ipaddr+ for ferro-url's IPAddr; none by default.
class FerroGem < Data.define(:short_name, :name, :crate, :extension, :packaged, :native_namespace,
  :platform_sigs, :platform_probe, :smoke, :rbs_libraries)
  # Creates the description, with no standard libraries unless given.
  def initialize(rbs_libraries: [], **fields)
    super
  end

  # The arguments of <tt>rbs validate</tt> for +gems+: every standard
  # library their signatures name, then each gem's signature directory.
  def self.rbs_validate_arguments(gems)
    libraries = gems.flat_map(&:rbs_libraries).uniq.flat_map { |library| ["-r", library] }
    [*libraries, *gems.flat_map { |gem| ["-I", File.join(gem.dir, "sig")] }, "validate"]
  end

  # The gem's directory, relative to the repository.
  def dir
    File.join("gems", short_name)
  end

  # The file that defines the gem's VERSION, relative to the gem, beside
  # the extension: <tt>lib/ferro/arboard/version.rb</tt> for ferro-arboard,
  # and <tt>lib/ferro/notify_rust/version.rb</tt> for ferro-notify-rust,
  # whose require path follows the crate's Rust name (plan 003).
  def version_file
    File.join(File.dirname(extension), "version.rb")
  end

  # The gem's changelog, relative to the gem.
  def changelog
    "CHANGELOG.md"
  end

  # What comes before the version in the gem's release tags:
  # <tt>ferro-arboard/v</tt> (ADR 001, section 5).
  def tag_prefix
    "#{name}/v"
  end

  # The gemspec's path, relative to the repository.
  def gemspec_path
    File.join(dir, "#{name}.gemspec")
  end

  # The loaded gemspec.
  def spec
    Gem::Specification.load(gemspec_path)
  end

  # The native extension's name, as rake-compiler and rb_sys know it.
  def extension_name
    File.basename(crate)
  end

  # The directory the compiled extension lands in, relative to the
  # repository.
  def extension_dir
    File.join(dir, File.dirname(extension))
  end

  # The compiled extension's path, relative to the repository.
  def extension_file
    File.join(dir, "#{extension}.#{RbConfig::CONFIG['DLEXT']}")
  end

  # The gem as the packaging check describes it.
  def package_target
    PackageCheck::Target.new(name:, dir:, packaged:, generated: [], crate:, extension:, smoke:, reuse: true)
  end

  # The platform the compiled extension was built for, read from the
  # extension itself so it always agrees with the crate's cfg.
  def platform
    output, status = Open3.capture2(RbConfig.ruby, "-I", File.join(dir, "lib"), "-e", platform_probe)
    raise "#{name}: could not read the extension's platform (compile first)" unless status.success?

    output.strip
  end

  # The signature files that belong to other platforms than +platform+,
  # and not to +platform+ itself.
  def foreign_sigs(platform)
    own = Array(platform_sigs[platform])
    (platform_sigs.reject { |name, _| name == platform }.values.flat_map { |paths| Array(paths) } - own).uniq
      .map { |path| File.join(dir, path) }
  end
end

# The gems this repository publishes, in dependency order.
FERRO_GEMS = [
  FerroGem.new(
    short_name: "arboard",
    name: "ferro-arboard",
    crate: "ext/ferro_arboard",
    extension: "lib/ferro/arboard/ferro_arboard",
    packaged: %w[lib sig ext Cargo.toml Cargo.lock Cargo.lock.license README.rdoc CHANGELOG.md LICENSES],
    native_namespace: "Ferro::Arboard",
    platform_sigs: {
      "linux" => "sig/ferro/arboard/linux.rbs",
      "macos" => "sig/ferro/arboard/apple.rbs",
      "windows" => "sig/ferro/arboard/windows.rbs",
    },
    platform_probe: %(require "ferro/arboard"; print Ferro::Arboard.const_get(:PLATFORM)),
    smoke: <<~RUBY),
      require "ferro/arboard"
      %i[get_text set_text set_html get_image set_image clear clear_with get set].each do |name|
        abort "Clipboard lacks \#{name}" unless Ferro::Arboard::Clipboard.method_defined?(name)
      end
      # A machine without a clipboard (a headless CI runner) still proves the
      # extension loads by raising arboard's error from Clipboard.new.
      clipboard = begin
        Ferro::Arboard::Clipboard.new
      rescue Ferro::Arboard::Error => e
        e
      end
      if clipboard.is_a?(Ferro::Arboard::Clipboard)
        begin
          clipboard.set_image(Ferro::Arboard::ImageData.new(width: 0, height: 0, bytes: ""))
          abort "an empty image reached arboard"
        rescue Ferro::Arboard::Error::ConversionFailure
        end
      end
      puts "ferro-arboard \#{Ferro::Arboard::VERSION} loads its extension (\#{clipboard.class})"
    RUBY
  FerroGem.new(
    short_name: "rfd",
    name: "ferro-rfd",
    crate: "ext/ferro_rfd",
    extension: "lib/ferro/rfd/ferro_rfd",
    packaged: %w[lib sig ext Cargo.toml Cargo.lock Cargo.lock.license README.rdoc CHANGELOG.md LICENSES],
    native_namespace: "Ferro::Rfd",
    platform_sigs: {
      "macos" => "sig/ferro/rfd/apple.rbs",
    },
    platform_probe: %(require "ferro/rfd"; print Ferro::Rfd.const_get(:PLATFORM)),
    smoke: <<~RUBY),
      require "ferro/rfd"
      # Every dialog waits for a person, so the smoke test shows none. It
      # replays a builder through rfd (its Debug text), which proves the
      # extension loads and reaches the crate, and refuses a filter rfd's
      # portal backend would panic on.
      dialog = Ferro::Rfd::FileDialog.new.add_filter("Text", ["txt"]).set_title("Smoke")
      abort "rfd did not see the builder: \#{dialog.inspect}" unless dialog.inspect.include?('title: Some("Smoke")')
      begin
        Ferro::Rfd::FileDialog.new.add_filter("bad\\0name", ["txt"])
        abort "a NUL byte reached rfd"
      rescue ArgumentError
      end
      puts "ferro-rfd \#{Ferro::Rfd::VERSION} loads its extension (\#{dialog.class})"
    RUBY
  FerroGem.new(
    short_name: "notify-rust",
    name: "ferro-notify-rust",
    crate: "ext/ferro_notify_rust",
    extension: "lib/ferro/notify_rust/ferro_notify_rust",
    packaged: %w[lib sig ext Cargo.toml Cargo.lock Cargo.lock.license README.rdoc CHANGELOG.md LICENSES],
    native_namespace: "Ferro::NotifyRust",
    platform_sigs: {
      "linux" => %w[sig/ferro/notify_rust/linux.rbs sig/ferro/notify_rust/deref.rbs],
      "macos" => "sig/ferro/notify_rust/apple.rbs",
      "windows" => %w[sig/ferro/notify_rust/windows.rbs sig/ferro/notify_rust/deref.rbs],
    },
    platform_probe: %(require "ferro/notify_rust"; print Ferro::NotifyRust.const_get(:PLATFORM)),
    smoke: <<~RUBY),
      require "ferro/notify_rust"
      # Showing a notification needs a desktop, so the smoke test shows
      # none. It builds one through notify-rust and reads a field back, and
      # converts a value through notify-rust's own rules, which proves the
      # extension loads and reaches the crate.
      notification = Ferro::NotifyRust::Notification.new.summary("Smoke").action("ok", "OK")
      abort "notify-rust did not see the summary: \#{notification.inspect}" unless notification.summary == "Smoke"
      abort "notify-rust did not parse an urgency" unless Ferro::NotifyRust::Urgency.try_from("High") == Ferro::NotifyRust::Urgency::Critical
      puts "ferro-notify-rust \#{Ferro::NotifyRust::VERSION} loads its extension (\#{notification.class})"
    RUBY
  FerroGem.new(
    short_name: "global-hotkey",
    name: "ferro-global-hotkey",
    crate: "ext/ferro_global_hotkey",
    extension: "lib/ferro/global_hotkey/ferro_global_hotkey",
    packaged: %w[lib sig ext Cargo.toml Cargo.lock Cargo.lock.license README.rdoc CHANGELOG.md LICENSES],
    native_namespace: "Ferro::GlobalHotkey",
    platform_sigs: {},
    platform_probe: %(require "ferro/global_hotkey"; print Ferro::GlobalHotkey.const_get(:PLATFORM)),
    smoke: <<~RUBY),
      require "ferro/global_hotkey"
      # Registering a hotkey takes it from every other program, so the
      # smoke test registers none. It parses a hotkey and writes it back
      # through global-hotkey, and reads the event channel without
      # waiting, which proves the extension loads and reaches the crate.
      hotkey = Ferro::GlobalHotkey::Hotkey::HotKey.from_str("shift+alt+KeyQ")
      abort "global-hotkey did not write the hotkey back: \#{hotkey}" unless hotkey.to_s == "shift+alt+KeyQ"
      begin
        Ferro::GlobalHotkey::GlobalHotKeyEvent.receiver.try_recv
        abort "an event arrived with no hotkey registered"
      rescue Ferro::GlobalHotkey::GlobalHotKeyEventReceiver::TryRecvError::Empty
      end
      puts "ferro-global-hotkey \#{Ferro::GlobalHotkey::VERSION} loads its extension (\#{hotkey.class})"
    RUBY
  FerroGem.new(
    short_name: "idna",
    name: "ferro-idna",
    crate: "ext/ferro_idna",
    extension: "lib/ferro/idna/ferro_idna",
    packaged: %w[lib sig ext Cargo.toml Cargo.lock Cargo.lock.license README.rdoc CHANGELOG.md LICENSES],
    native_namespace: "Ferro::Idna",
    platform_sigs: {},
    platform_probe: %(require "ferro/idna"; print "any"),
    smoke: <<~RUBY),
      require "ferro/idna"
      # idna is pure computation over Unicode tables compiled into the
      # extension, so the smoke test runs it: UTS 46 to ASCII and back, and
      # a deny list idna would panic on, refused first.
      ascii = Ferro::Idna.domain_to_ascii_cow("B\u00FCcher.example", Ferro::Idna::AsciiDenyList::URL)
      abort "idna did not encode the domain: \#{ascii}" unless ascii == "xn--bcher-kva.example"
      abort "idna did not decode the domain" unless Ferro::Idna.domain_to_unicode(ascii) == ["b\u00FCcher.example", nil]
      begin
        Ferro::Idna::AsciiDenyList.new(false, "a")
        abort "a letter reached idna's deny list"
      rescue ArgumentError
      end
      puts "ferro-idna \#{Ferro::Idna::VERSION} loads its extension (\#{ascii})"
    RUBY
  FerroGem.new(
    short_name: "url",
    name: "ferro-url",
    crate: "ext/ferro_url",
    extension: "lib/ferro/url/ferro_url",
    packaged: %w[lib sig ext Cargo.toml Cargo.lock Cargo.lock.license README.rdoc CHANGELOG.md LICENSES],
    native_namespace: "Ferro::Url",
    platform_sigs: {},
    rbs_libraries: %w[ipaddr socket],
    platform_probe: %(require "ferro/url"; print "any"),
    smoke: <<~RUBY),
      require "ferro/url"
      # url is pure computation, so the smoke test runs it: a parse, a
      # join, url's own error, and a slice the gem refuses before Rust's
      # slicing would panic.
      url = Ferro::Url::Url.parse("https://B\u00FCcher.example/a/b?q=1#top")
      abort "url did not parse the URL: \#{url}" unless url.host_str == "xn--bcher-kva.example"
      abort "url did not join" unless url.join("../c").as_str == "https://xn--bcher-kva.example/c"
      begin
        Ferro::Url::Url.parse("../main.css")
        abort "a relative URL parsed without a base"
      rescue Ferro::Url::ParseError::RelativeUrlWithoutBase
      end
      begin
        url[Ferro::Url::Position::AfterPath...Ferro::Url::Position::BeforePath]
        abort "a backward slice reached Rust"
      rescue Ferro::Url::Error
      end
      puts "ferro-url \#{Ferro::Url::VERSION} loads its extension (\#{url})"
    RUBY
].freeze
