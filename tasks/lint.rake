# frozen_string_literal: true

#--
# SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#++

require "rdoc/task"
require "rubocop/rake_task"

# rubocop, rubocop:autocorrect, and rubocop:autocorrect_all.
RuboCop::RakeTask.new

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = ENV["RDOC_OUTPUT"] || "tmp/rdoc"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", *FERRO_GEMS.flat_map { |gem| ["#{gem.dir}/README.rdoc", "#{gem.dir}/lib/**/*.rb"] })
end

namespace :rdoc do
  # rdoc:coverage exits the process when anything is undocumented, so it
  # runs in a child process that can fail the gate without ending rake.
  desc "Fail unless every public class, module, method, and constant is documented"
  task :check do
    sh "bundle exec rake rdoc:coverage"
  end
end

namespace :reuse do
  desc "Check licensing with the REUSE tool"
  task :lint do
    sh "reuse lint"
  end
end
