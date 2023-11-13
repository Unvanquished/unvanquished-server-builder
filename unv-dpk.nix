#
# This makes a dpk (zip) containing the VM files and the rest of
# unvanquished_src.dpkdir
#

{ lib, stdenv, p7zip
, source
, unvanquished-vms
, filename
}:

stdenv.mkDerivation rec {
  name = "unvanquished-dpk";
  version = "0";

  buildInputs = [
    p7zip
  ];

  unpackPhase = ''
    cp -v -r --no-preserve=mode ${source}/pkg/unvanquished_src.dpkdir unvanquished_src.dpkdir
  '';

  buildPhase = ''
    cd unvanquished_src.dpkdir
    cp -v --no-preserve=mode ${unvanquished-vms}/* .
    rm *.so
    rm .git* -r
    [ -d .pakinfo ] && rm .pakinfo -r
    [ -d .urcheon ] && rm .urcheon -r
    7z -tzip -mx=9 a ../${filename}_${version}.dpk .
    cd ..
  '';
  installPhase = ''
    mkdir -p $out
    cp ${filename}_${version}.dpk $out/
  '';
}
