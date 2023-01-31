#
# This builds the daemon engine
#

{ lib, stdenv
, cmake, gmp, libGL, zlib, ncurses, geoip, lua5
, nettle, curl, SDL2, freetype, glew, openal, libopus, opusfile, libogg
, libvorbis, libjpeg, libwebp, libpng, python
, source
, nacl-hacks-8
}:

stdenv.mkDerivation rec {
  name = "daemon";
  src = source;

  preConfigure = ''
    mkdir external_deps/linux-amd64-default_${nacl-hacks-8.binary-deps-version}/
    cp ${nacl-hacks-8.unvanquished-binary-deps}/* external_deps/linux-amd64-default_${nacl-hacks-8.binary-deps-version} -r
    chmod +w -R external_deps/linux-amd64-default_${nacl-hacks-8.binary-deps-version}/
  '';

  nativeBuildInputs = [
    cmake
    nacl-hacks-8.unvanquished-binary-deps
    (python.withPackages (ppkgs: [ppkgs.jinja2 ppkgs.pyyaml]))
  ];
  buildInputs = [
    gmp
    libGL
    zlib
    ncurses
    geoip
    lua5
    nettle
    curl
    SDL2
    freetype
    glew
    openal
    libopus
    opusfile
    libogg
    libvorbis
    libjpeg
    libwebp
    libpng
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
    "-DBUILD_TTY_CLIENT=FALSE"
    "-DBUILD_CLIENT=FALSE"
    "-DUSE_HARDENING=TRUE"
    "-DUSE_LTO=TRUE"
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    for f in nacl_loader nacl_helper_bootstrap; do
      install -Dm0755 -t $out/lib/ $f
    done
    install -Dm0644 -t $out/lib/ irt_core-amd64.nexe

    install -Dm0755 -t $out/bin/ daemonded

    runHook postInstall
  '';
}
