{ stdenv
, fetchurl
, fetchpatch
, substituteAll
, meson
, ninja
, python3
, pkg-config
, glib
, itstool
, libxml2
, xorg
, accountsservice
, libX11
, gnome3
, systemd
, dconf
, gtk3
, libcanberra-gtk3
, pam
, libselinux
, keyutils
, audit
, gobject-introspection
, plymouth
, librsvg
, coreutils
, xwayland
, dbus
, nixos-icons
}:

let

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/4f041870efa1a6f0799ef4b32bb7be2cafee7a74/logo/nixos.svg";
    sha256 = "0b0dj408c1wxmzy6k0pjwc4bzwq286f1334s3cqqwdwjshxskshk";
  };

  override = substituteAll {
    src = ./org.gnome.login-screen.gschema.override;
    inherit icon;
  };

in

stdenv.mkDerivation rec {
  pname = "gdm";
  version = "3.38.0";

  outputs = [ "out" "dev" ];

  src = fetchurl {
    url = "mirror://gnome/sources/gdm/${stdenv.lib.versions.majorMinor version}/${pname}-${version}.tar.xz";
    sha256 = "1fimhklb204rflz8k345756jikgbw8113hms3zlcwk6975f43m26";
  };

  mesonFlags = [
    "-Dgdm-xsession=true"
    # TODO: Setup a default-path? https://gitlab.gnome.org/GNOME/gdm/-/blob/6fc40ac6aa37c8ad87c32f0b1a5d813d34bf7770/meson_options.txt#L6
    "-Dinitial-vt=${passthru.initialVT}"
    "-Dudev-dir=${placeholder "out"}/lib/udev/rules.d"
    "-Dsystemdsystemunitdir=${placeholder "out"}/lib/systemd/system"
    "-Dsystemduserunitdir=${placeholder "out"}/lib/systemd/user"
    "-Dsysconfsubdir=${placeholder "out"}/etc"
  ];

  nativeBuildInputs = [
    dconf
    glib # for glib-compile-schemas
    itstool
    meson
    ninja
    pkg-config
    python3
  ];

  buildInputs = [
    accountsservice
    audit
    glib
    gobject-introspection
    gtk3
    keyutils
    libX11
    libcanberra-gtk3
    libselinux
    pam
    plymouth
    systemd
    xorg.libXdmcp
  ];

  patches = [
    # https://gitlab.gnome.org/GNOME/gdm/-/merge_requests/112
    (fetchpatch {
      url = "https://gitlab.gnome.org/GNOME/gdm/-/commit/1d28d4b3568381b8590d2235737b924aefd1746c.patch";
      sha256 = "ZUXKZS4T0o0hzrApxaqcR0txCRv5zBgqeQ9K9fLNX1o=";
    })

    # Change hardcoded paths to nix store paths.
    (substituteAll {
      src = ./fix-paths.patch;
      inherit coreutils plymouth xwayland dbus;
    })

    # The following patches implement certain environment variables in GDM which are set by
    # the gdm configuration module (nixos/modules/services/x11/display-managers/gdm.nix).

    ./gdm-x-session_extra_args.patch

    # Allow specifying a wrapper for running the session command.
    ./gdm-x-session_session-wrapper.patch

    # Forwards certain environment variables to the gdm-x-session child process
    # to ensure that the above two patches actually work.
    ./gdm-session-worker_forward-vars.patch

    # Set up the environment properly when launching sessions
    # https://github.com/NixOS/nixpkgs/issues/48255
    ./reset-environment.patch
  ];

  postPatch = ''
    patchShebangs build-aux/meson_post_install.py

    # Upstream checks some common paths to find an `X` binary. We already know it.
    echo #!/bin/sh > build-aux/find-x-server.sh
    echo "echo ${stdenv.lib.getBin xorg.xorgserver}/bin/X" >> build-aux/find-x-server.sh
    patchShebangs build-aux/find-x-server.sh
  '';

  preInstall = ''
    install -D ${override} $out/share/glib-2.0/schemas/org.gnome.login-screen.gschema.override
  '';

  passthru = {
    updateScript = gnome3.updateScript {
      packageName = "gdm";
      attrPath = "gnome3.gdm";
    };

    # Used in GDM NixOS module
    # Don't remove.
    initialVT = "7";
  };

  meta = with stdenv.lib; {
    description = "A program that manages graphical display servers and handles graphical user logins";
    homepage = "https://wiki.gnome.org/Projects/GDM";
    license = licenses.gpl2Plus;
    maintainers = teams.gnome.members;
    platforms = platforms.linux;
  };
}
