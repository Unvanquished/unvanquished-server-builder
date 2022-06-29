{ lib, stdenv, cmake, zlib, ncurses, python
, source
, daemon-source
, nacl-hacks-4
, nacl-hacks-5
, nacl-hacks-6
# Those are here only because cmake doesn't have options to build
# only the sgame dll
, libGL, geoip, lua5, pkg-config, meson
, nettle, curl, SDL2, freetype, glew, openal
, libopus, opusfile, libogg, libvorbis, libjpeg, libwebp, libpng
}:

#
# this is building the nacl gamelogic files
#

stdenv.mkDerivation {
  name = "unvanquished-nacl-vms";
  src = source;

  dontPatchELF = true;

  preConfigure = ''
    rm -r daemon
    cp -r ${daemon-source} daemon
    chmod +w daemon -R

    mkdir daemon/external_deps/linux64-${nacl-hacks-4.binary-deps-version}/
    mkdir daemon/external_deps/linux64-${nacl-hacks-5.binary-deps-version}/
    mkdir daemon/external_deps/linux64-${nacl-hacks-6.binary-deps-version}/
    cp ${nacl-hacks-4.unvanquished-binary-deps}/* daemon/external_deps/linux64-${nacl-hacks-4.binary-deps-version} -r
    cp ${nacl-hacks-5.unvanquished-binary-deps}/* daemon/external_deps/linux64-${nacl-hacks-5.binary-deps-version} -r
    cp ${nacl-hacks-6.unvanquished-binary-deps}/* daemon/external_deps/linux64-${nacl-hacks-6.binary-deps-version} -r
    chmod +w -R daemon/external_deps/linux64-${nacl-hacks-4.binary-deps-version}/
    chmod +w -R daemon/external_deps/linux64-${nacl-hacks-5.binary-deps-version}/
    chmod +w -R daemon/external_deps/linux64-${nacl-hacks-6.binary-deps-version}/

    #FIXME: remove as this is duplicated with nacl-hacks
    interpreter="$(< "$NIX_CC/nix-support/dynamic-linker")"
    for f in /build/source/daemon/external_deps/linux64-*/pnacl/bin/*; do
      if [ -f "$f" ] && [ -x "$f" ]; then
        echo "Patching $f"
        patchelf --set-interpreter "$interpreter" "$f" || true
      fi
    done
  '';

  nativeBuildInputs = [
    cmake
    nacl-hacks-4.unvanquished-binary-deps
    nacl-hacks-5.unvanquished-binary-deps
    nacl-hacks-6.unvanquished-binary-deps
    (python.withPackages (ppkgs: [ppkgs.jinja2 ppkgs.pyyaml]))
  ];
  buildInputs = [
    zlib
    ncurses
    libGL geoip lua5 pkg-config meson
    nettle curl SDL2 freetype glew openal
    libopus opusfile libogg libvorbis libjpeg libwebp libpng
  ];

  cmakeFlags = [
    "-DBUILD_CLIENT=NO"
    "-DBUILD_SERVER=NO"
    "-DBUILD_TTY_CLIENT=NO"
    "-DBUILD_CGAME=YES"
    "-DBUILD_SGAME=YES"
    "-DBUILD_GAME_NACL=YES"
    "-DBUILD_GAME_NATIVE_EXE=NO"
    "-DBUILD_GAME_NATIVE_DLL=YES"
    "-DUSE_LTO=TRUE"
  ];

  dontStrip = true;

  installPhase = ''
    install -Dm0644 sgame-x86_64-stripped.nexe $out/sgame-x86_64.nexe
    install -Dm0644 sgame-x86-stripped.nexe    $out/sgame-x86.nexe
    install -Dm0644 cgame-x86_64-stripped.nexe $out/cgame-x86_64.nexe
    install -Dm0644 cgame-x86-stripped.nexe    $out/cgame-x86.nexe

    install -Dm0755 sgame-native-dll.so $out/sgame-native-dll.so
    install -Dm0755 cgame-native-dll.so $out/cgame-native-dll.so
  '';
}
