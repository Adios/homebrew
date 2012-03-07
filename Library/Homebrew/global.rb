require 'extend/pathname'
require 'extend/ARGV'
require 'extend/string'
require 'utils'
require 'exceptions'

ARGV.extend(HomebrewArgvExtension)

HOMEBREW_VERSION = '0.8.1'
HOMEBREW_WWW = 'http://mxcl.github.com/homebrew/'

def cache
  if ENV['HOMEBREW_CACHE']
    Pathname.new(ENV['HOMEBREW_CACHE'])
  else
    root_library = Pathname.new("/Library/Caches/Homebrew")
    if Process.uid == 0
      root_library
    else
      home_library = Pathname.new("~/Library/Caches/Homebrew").expand_path
      if not home_library.writable?
        root_library
      else
        home_library
      end
    end
  end
end

HOMEBREW_CACHE = cache
undef cache

# Where brews installed via URL are cached
HOMEBREW_CACHE_FORMULA = HOMEBREW_CACHE+"Formula"

# Where bottles are cached
HOMEBREW_CACHE_BOTTLES = HOMEBREW_CACHE+"Bottles"

if not defined? HOMEBREW_BREW_FILE
  HOMEBREW_BREW_FILE = ENV['HOMEBREW_BREW_FILE'] || `which brew`.chomp
end

HOMEBREW_PREFIX = Pathname.new(HOMEBREW_BREW_FILE).dirname.parent # Where we link under
HOMEBREW_REPOSITORY = Pathname.new(HOMEBREW_BREW_FILE).realpath.dirname.parent # Where .git is found

# Where we store built products; /usr/local/Cellar if it exists,
# otherwise a Cellar relative to the Repository.
HOMEBREW_CELLAR = if (HOMEBREW_PREFIX+"Cellar").exist?
  HOMEBREW_PREFIX+"Cellar"
else
  HOMEBREW_REPOSITORY+"Cellar"
end

MACOS_FULL_VERSION = `/usr/bin/sw_vers -productVersion`.chomp
MACOS_VERSION = /(10\.\d+)(\.\d+)?/.match(MACOS_FULL_VERSION).captures.first.to_f

def _get_patchlevel
  begin; RUBY_PATCHLEVEL; rescue; 0; end
end

HOMEBREW_CURL_ARGS = '-qf#LA'
HOMEBREW_USER_AGENT = "Homebrew #{HOMEBREW_VERSION} (Ruby #{RUBY_VERSION}-#{RUBY_PATCHLEVEL}; Mac OS X #{MACOS_FULL_VERSION})"

# Ruby 1.8.2 on 10.4 is missing the Object method instance_variable_defined?,
# so we need to define one for later use by formula.rb code.
if RUBY_VERSION == '1.8.2'
  if not Object.method_defined?(:instance_variable_defined?)
    class Object
      def instance_variable_defined?(variable)
        instance_variables.include?(variable.to_s)
      end
    end
  end
end

RECOMMENDED_LLVM = 2326
RECOMMENDED_GCC_40 = (MACOS_VERSION >= 10.6) ? 5494 : 5493
RECOMMENDED_GCC_42 = (MACOS_VERSION >= 10.6) ? 5664 : 5577

require 'fileutils'
module Homebrew extend self
  include FileUtils
end

FORMULA_META_FILES = %w[README README.md ChangeLog CHANGES COPYING LICENSE LICENCE COPYRIGHT AUTHORS]
ISSUES_URL = "https://github.com/mxcl/homebrew/wiki/checklist-before-filing-a-new-issue"

unless ARGV.include? "--no-compat" or ENV['HOMEBREW_NO_COMPAT']
  $:.unshift(File.expand_path("#{__FILE__}/../compat"))
  require 'compatibility'
end
