class GnomeFoundry < Formula
  desc "Command-line IDE tooling and library extracted from GNOME Builder"
  homepage "https://gitlab.gnome.org/GNOME/foundry"
  url "https://download.gnome.org/sources/foundry/1.1/foundry-1.1.1.tar.xz"
  sha256 "46db0d64436c313611cafdfb4ca0d5cec2b97be7d7a5f1be7ee8d0150d4f25c8"
  license "LGPL-2.1-or-later"
  head "https://gitlab.gnome.org/GNOME/foundry.git", branch: "main"

  # An explicit regex is required: the :gnome strategy's default one applies the
  # pre-GNOME-40 "odd minor means unstable" rule to anything below 40, which
  # would discard foundry's stable 1.1.x line. Requiring `.t` after the numeric
  # version still excludes prereleases such as 1.2.beta.
  livecheck do
    url "https://download.gnome.org/sources/foundry/cache.json"
    regex(/foundry[._-]v?(\d+(?:\.\d+)+)\.t/i)
    strategy :gnome
  end

  depends_on "gettext" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build

  depends_on "editorconfig"
  depends_on "glib"
  depends_on "gom"
  depends_on "json-glib"
  depends_on "libgit2"
  depends_on "libsecret"
  depends_on "libsoup"
  depends_on "libssh2"
  depends_on "libxml2"
  # libfoundry uses gio-unix and sysprof-capture; upstream targets Linux.
  depends_on :linux
  depends_on "template-glib"

  # foundry 1.1 requires libdex >= 1.1.alpha, but homebrew-core is still on
  # libdex 1.0.0. Build a private copy into libexec until core catches up.
  resource "libdex" do
    url "https://download.gnome.org/sources/libdex/1.1/libdex-1.1.0.tar.xz"
    sha256 "a9e04c8abee01c9a7cf1148c5b7aa66ba377efe6af6d83801d4fd1aa55219aaa"
  end

  # Only the static libsysprof-capture is needed. Depending on homebrew-core's
  # sysprof would drag in the whole Sysprof GUI stack (gtk4, mesa, llvm,
  # polkit) for a CLI that never displays a window.
  resource "sysprof" do
    url "https://download.gnome.org/sources/sysprof/50/sysprof-50.0.tar.xz"
    sha256 "aace44e90e90f6c34bb2fbec8ccb47b8f81103080978d65759287843c329d53a"
  end

  # foundry's plugins are all C, so only libpeas' built-in C loader is needed.
  # homebrew-core's libpeas enables the GJS, Python and Lua loaders, which pull
  # in gjs, spidermonkey (1GB), pygobject3 and gtk+3.
  resource "libpeas" do
    url "https://download.gnome.org/sources/libpeas/2.2/libpeas-2.2.1.tar.xz"
    sha256 "589eca89b437006edf3755478df037c740a2a84cfa5d202dbad6095e828e2488"
  end

  def install
    resource("libdex").stage do
      system "meson", "setup", "build",
             "--prefix=#{libexec}",
             "--libdir=lib",
             "--buildtype=release",
             "--wrap-mode=nofallback",
             "-Ddocs=false",
             "-Dexamples=false",
             "-Dintrospection=disabled",
             "-Dpygobject=false",
             "-Dtests=false",
             "-Dvapi=false"
      system "meson", "compile", "-C", "build", "--verbose"
      system "meson", "install", "-C", "build"
    end

    resource("sysprof").stage do
      system "meson", "setup", "build",
             "--prefix=#{libexec}",
             "--libdir=lib",
             "--buildtype=release",
             "--wrap-mode=nofallback",
             "-Ddebuginfod=disabled",
             "-Ddocs=false",
             "-Dexamples=false",
             "-Dgtk=false",
             "-Dhelp=false",
             "-Dinstall-static=true",
             "-Dintrospection=disabled",
             "-Dlibsysprof=false",
             "-Dpolkit-agent=disabled",
             "-Dsysprofd=none",
             "-Dtests=false",
             "-Dtools=false"
      system "meson", "compile", "-C", "build", "--verbose"
      system "meson", "install", "-C", "build"
    end

    resource("libpeas").stage do
      system "meson", "setup", "build",
             "--prefix=#{libexec}",
             "--libdir=lib",
             "--buildtype=release",
             "--wrap-mode=nofallback",
             "-Dgjs=false",
             "-Dgtk_doc=false",
             "-Dintrospection=false",
             "-Dlua51=false",
             "-Dpython3=false",
             "-Dvapi=false"
      system "meson", "compile", "-C", "build", "--verbose"
      system "meson", "install", "-C", "build"
    end

    ENV.prepend_path "PKG_CONFIG_PATH", libexec/"lib/pkgconfig"

    args = [
      # The CLI and libfoundry itself need no toolkit; the GTK/libadwaita
      # libraries would pull in gtk4, gtksourceview5, vte and webkit.
      "-Dadwaita=false",
      "-Dgtk=false",
      "-Ddocs=false",
      "-Dintrospection=disabled",
      # libflatpak is not packaged for Homebrew.
      "-Dfeature-flatpak=false",
      # Link against the private libdex above.
      "-Dc_link_args=-Wl,-rpath,#{libexec}/lib",
    ]

    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"

    # meson's post-install hook compiles the schema cache inside the keg, which
    # would collide on link. post_install_steps rebuilds it prefix-wide.
    rm(share/"glib-2.0/schemas/gschemas.compiled")
  end

  post_install_steps do
    compile_gsettings_schemas
  end

  def caveats
    <<~EOS
      This build omits the libfoundry-gtk and libfoundry-adw libraries, GObject
      introspection data, and Flatpak SDK support. The `foundry` CLI, libfoundry
      and all non-GUI plugins (build systems, language servers, VCS, LLM,
      podman/jhbuild SDKs) are included.

      Get started in a project checkout:
        foundry init
        foundry build
    EOS
  end

  test do
    # foundry has no --version; --help lists the compiled-in command tree.
    help = shell_output("#{bin}/foundry --help")
    assert_match "init", help
    assert_match "build", help

    system "git", "init", testpath/"proj"
    (testpath/"proj/meson.build").write <<~MESON
      project('proj', 'c', version: '0.1.0')
    MESON

    system bin/"foundry", "init", "--directory=#{testpath}/proj"
    assert_predicate testpath/"proj/.foundry", :directory?
  end
end
