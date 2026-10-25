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
#   platform name the extension reports; rbs:parity skips the others.
# [platform_probe] Ruby source that prints the extension's platform name.
# [smoke] Ruby source the packaging check runs against the built gem.
class FerroGem < Data.define(:short_name, :name, :crate, :extension, :packaged, :native_namespace,
  :platform_sigs, :platform_probe, :smoke)
  # The gem's directory, relative to the repository.
  def dir
    File.join("gems", short_name)
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

  # The signature files that belong to other platforms than +platform+.
  def foreign_sigs(platform)
    platform_sigs.reject { |name, _| name == platform }.values.map { |path| File.join(dir, path) }
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
].freeze
