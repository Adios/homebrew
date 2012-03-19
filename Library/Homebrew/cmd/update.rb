require 'cmd/tap'
require 'cmd/untap'

module Homebrew extend self

  def update
    abort "Please `brew install git' first." unless which_s "git"

    # ensure GIT_CONFIG is unset as we need to operate on .git/config
    ENV.delete('GIT_CONFIG')

    cd HOMEBREW_REPOSITORY
    git_init_if_necessary

    report = Report.new
    master_updater = Updater.new
    master_updater.pull!
    report.merge!(master_updater.report)

    new_files = []
    Dir["Library/Taps/*"].each do |tapd|
      cd tapd do
        updater = Updater.new
        updater.pull!
        report.merge!(updater.report) do |key, oldval, newval|
          oldval.concat(newval)
        end
      end
    end

    # we unlink first in case the formula has moved to another tap
    Homebrew.unlink_tap_formula(report.removed_tapped_formula)
    Homebrew.link_tap_formula(report.new_tapped_formula)

    if report.empty?
      puts "Already up-to-date."
    else
      puts "Updated Homebrew from #{master_updater.initial_revision[0,8]} to #{master_updater.current_revision[0,8]}."
      report.dump
    end
  end

  private

  def git_init_if_necessary
    if Dir['.git/*'].empty?
      safe_system "git init"
      safe_system "git config core.autocrlf false"
      safe_system "git remote add origin http://github.com/sceaga/homebrew.git"
      safe_system "git fetch origin powerpc"
      safe_system "git branch master FETCH_HEAD"
      safe_system "git reset --hard master"
    end
  rescue Exception
    FileUtils.rm_rf ".git"
    raise
  end

end

class Updater
  attr_reader :initial_revision, :current_revision

  def pull!
    safe_system "git checkout -q master"

    @initial_revision = read_current_revision

    # ensure we don't munge line endings on checkout
    safe_system "git config core.autocrlf false"

    args = ["pull"]
    args << "--rebase" if ARGV.include? "--rebase"
    args << "-q" unless ARGV.verbose?
    args << "origin"
    # the refspec ensures that 'origin/powerpc' gets updated
    args << "refs/heads/powerpc:refs/remotes/origin/master"

    safe_system "git", *args

    @current_revision = read_current_revision
  end

  def report
    map = Hash.new{ |h,k| h[k] = [] }

    if initial_revision && initial_revision != current_revision
      changes = `git diff-tree -r --name-status -z #{initial_revision} #{current_revision}`.split("\0")
      changes.each_slice(2) do |status, file|
        file = Pathname.pwd.join(file).relative_path_from(HOMEBREW_REPOSITORY)
        map[status.to_sym] << file.to_s
      end
    end

    map
  end

  private

  def read_current_revision
    `git rev-parse HEAD`.chomp
  end

  def `(cmd)
    out = Kernel.`(cmd) #`
    if $? && !$?.success?
      $stderr.puts out
      raise ErrorDuringExecution, "Failure while executing: #{cmd}"
    end
    ohai(cmd, out) if ARGV.verbose?
    out
  end
end


class Report < Hash

  def dump
    # Key Legend: Added (A), Copied (C), Deleted (D), Modified (M), Renamed (R)

    dump_formula_report :A, "New Formula"
    dump_formula_report :M, "Updated Formula"
    dump_formula_report :D, "Deleted Formula"
    dump_formula_report :R, "Renamed Formula"
#    dump_new_commands
#    dump_deleted_commands
  end

  def tapped_formula_for key
    fetch(key, []).map do |path|
      case path when %r{^Library/Taps/(\w+-\w+/.*)}
        Pathname.new($1)
      end
    end.compact
  end

  def new_tapped_formula
    tapped_formula_for :A
  end

  def removed_tapped_formula
    tapped_formula_for :D
  end

  def select_formula key
    fetch(key, []).map do |path|
      case path when %r{^Library/Formula}
        File.basename(path, ".rb")
      when %r{^Library/Taps/(\w+)-(\w+)/(.*)\.rb}
        "#$1/#$2/#{File.basename(path, '.rb')}"
      end
    end.compact.sort
  end

  def dump_formula_report key, title
    formula = select_formula(key)
    unless formula.empty?
      ohai title
      puts_columns formula
    end
  end

end
