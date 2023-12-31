#
# Builds the gamelogic files, both as a nacl binary and a dll file
#

{ lib, stdenv, cmake, zlib, ncurses, python
, source
, daemon-source
, nacl-hacks-8
# Those are here only because cmake doesn't have options to build
# only the sgame dll
, libGL, geoip, lua5, pkg-config, meson
, nettle, curl, SDL2, freetype, glew, openal
, libopus, opusfile, libogg, libvorbis, libjpeg, libwebp, libpng
}:

stdenv.mkDerivation {
  name = "unvanquished-nacl-vms";
  src = source;

  dontPatchELF = true;

  preConfigure = ''
    rm -r daemon
    cp -r ${daemon-source} daemon
    chmod +w daemon -R

    mkdir daemon/external_deps/linux-amd64-default_${nacl-hacks-8.binary-deps-version}/
    cp ${nacl-hacks-8.unvanquished-binary-deps}/* daemon/external_deps/linux-amd64-default_${nacl-hacks-8.binary-deps-version} -r
    chmod +w -R daemon/external_deps/linux-amd64-default_${nacl-hacks-8.binary-deps-version}/

    #FIXME: remove as this is duplicated with nacl-hacks
    interpreter="$(< "$NIX_CC/nix-support/dynamic-linker")"
    for f in /build/source/daemon/external_deps/linux-*/pnacl/bin/*; do
      if [ -f "$f" ] && [ -x "$f" ]; then
        echo "Patching $f"
        patchelf --set-interpreter "$interpreter" "$f" || true
      fi
    done
  '';

  nativeBuildInputs = [
    cmake
    nacl-hacks-8.unvanquished-binary-deps
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
    "-DCMAKE_BUILD_TYPE=Debug"
    "-DBUILD_CLIENT=NO"
    "-DBUILD_SERVER=NO"
    "-DBUILD_TTY_CLIENT=NO"
    "-DBUILD_CGAME=YES"
    "-DBUILD_SGAME=YES"
    "-DBUILD_GAME_NACL=YES"
    "-DBUILD_GAME_NATIVE_EXE=NO"
    "-DBUILD_GAME_NATIVE_DLL=YES"
    "-DUSE_LTO=FALSE"
  ];

  dontStrip = true;

  installPhase = ''
    install -Dm0644 sgame-armhf-stripped.nexe $out/sgame-armhf.nexe
    install -Dm0644 sgame-amd64-stripped.nexe $out/sgame-amd64.nexe
    install -Dm0644 sgame-i686-stripped.nexe  $out/sgame-i686.nexe

    install -Dm0644 cgame-armhf-stripped.nexe $out/cgame-armhf.nexe
    install -Dm0644 cgame-amd64-stripped.nexe $out/cgame-amd64.nexe
    install -Dm0644 cgame-i686-stripped.nexe  $out/cgame-i686.nexe

    install -Dm0755 sgame-native-dll.so $out/sgame-native-dll.so
    install -Dm0755 cgame-native-dll.so $out/cgame-native-dll.so
  '';
}
