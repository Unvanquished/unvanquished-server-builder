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
    cp -v -r --no-preserve=mode ${source} unvanquished_src.dpkdir
  '';

  buildPhase = ''
    cd unvanquished_src.dpkdir
    cp -v --no-preserve=mode ${unvanquished-vms}/* .
    rm *.so
    rm .git* -r
    rm .pakinfo -r
    7z -tzip -mx=9 a ../${filename}_${version}.dpk .
    cd ..
  '';
  installPhase = ''
    mkdir -p $out
    cp ${filename}_${version}.dpk $out/
  '';
}
