require 'formula'

class Macvim < Formula
  homepage 'http://code.google.com/p/macvim/'
  url 'https://github.com/b4winckler/macvim/tarball/snapshot-64'
  version '7.3-64'
  md5 '5bdc0bc618b3179130f846f8d0f81283'

  head 'https://github.com/b4winckler/macvim.git', :branch => 'master'

  def options
  [
    ["--custom-icons", "Try to generate custom document icons."],
    ["--with-cscope", "Build with Cscope support."],
    ["--override-system-vim", "Override system vim."],
    ["--with-lua", "Build with Lua scripting support."]
  ]
  end

  depends_on 'cscope' if ARGV.include? '--with-cscope'
  depends_on 'lua' if ARGV.include? '--with-lua'

  def install
    # MacVim's Xcode project gets confused by $CC, so remove it
    ENV['CC'] = nil
    ENV['CFLAGS'] = nil
    ENV['CXX'] = nil
    ENV['CXXFLAGS'] = nil

    # Set ARCHFLAGS so the Python app (with C extension) that is
    # used to create the custom icons will work correctly with
    # PPC systems.
    arch ='ppc'
    ENV['ARCHFLAGS'] = "-arch ppc"

    args = ["--with-features=huge",
            "--with-tlib=ncurses",
            "--enable-multibyte",
            "--with-macarchs=#{arch}",
            "--enable-perlinterp",
            "--enable-pythoninterp",
            "--enable-rubyinterp",
            "--enable-tclinterp"]

    args << "--enable-cscope" if ARGV.include? "--with-cscope"

    if ARGV.include? "--with-lua"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    system "./configure", *args

    # Building custom icons fails for many users, so off by default.
    unless ARGV.include? "--custom-icons"
      inreplace "src/MacVim/icons/Makefile", "$(MAKE) -C makeicns", ""
      inreplace "src/MacVim/icons/make_icons.py", "dont_create = False", "dont_create = True"
    end

    # Reference: https://github.com/b4winckler/macvim/wiki/building
    cd 'src/MacVim/icons' do
      system "make getenvy"
    end

    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    inreplace "src/MacVim/mvim", /^# VIM_APP_DIR=\/Applications$/,
              "VIM_APP_DIR=#{prefix}"
    bin.install "src/MacVim/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    executables = %w[mvimdiff mview mvimex]
    executables += %w[vi vim vimdiff view vimex] if ARGV.include? "--override-system-vim"
    executables.each {|f| ln_s bin+'mvim', bin+f}
  end

  def caveats; <<-EOS.undent
    MacVim.app installed to:
      #{prefix}

    To link the application to a normal Mac OS X location:
        brew linkapps
    or:
        ln -s #{prefix}/MacVim.app /Applications
    EOS
  end
end
