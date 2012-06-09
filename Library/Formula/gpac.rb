require 'formula'

#
# Installs a relatively minimalist version of the GPAC tools. The
# most commonly used tool in this package is the MP4Box metadata
# interleaver, which has relatively few dependencies.
#
# The challenge with building everything is that Gpac depends on
# a much older version of FFMpeg and WxWidgets than the version
# that Brew installs
#

class Gpac < Formula
  homepage 'http://gpac.sourceforge.net/index.php'
  url 'http://downloads.sourceforge.net/gpac/gpac-0.5.0.tar.gz'
  sha1 '48ba16272bfa153abb281ff8ed31b5dddf60cf20'

  head 'https://gpac.svn.sourceforge.net/svnroot/gpac/trunk/gpac', :using => :svn

  depends_on 'a52dec' => :optional
  depends_on 'jpeg' => :optional
  depends_on 'faad2' => :optional
  depends_on 'libogg' => :optional
  depends_on 'libvorbis' => :optional
  depends_on 'mad' => :optional
  depends_on 'sdl' => :optional
  depends_on 'theora' => :optional
  depends_on 'ffmpeg' => :optional
  depends_on 'openjpeg' => :optional

  def patches
    DATA
  end

  def options
    [['--with-lowercase', 'Install binaries with lowercase names']]
  end

  def install
    ENV.deparallelize

    args = ["--disable-wx",
            "--prefix=#{prefix}",
            "--mandir=#{man}",
            # gpac build system is barely functional
            "--extra-cflags=-I/usr/X11/include",
            # Force detection of X libs on 64-bit kernel
            "--extra-ldflags=-L/usr/X11/lib"]

    system "chmod +x configure"
    system "./configure", *args
    system "make"
    system "make install"
  end
end

__END__
--- a/src/Makefile
+++ b/src/Makefile
@@ -181,7 +181,7 @@
 
 LD_SONAME="-Wl,-soname,$(LIB)"
 ifeq ($(CONFIG_DARWIN), yes)
-LD_SONAME=""
+LD_SONAME=
 endif
 
 
