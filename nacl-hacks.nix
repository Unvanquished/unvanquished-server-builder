{ lib, stdenv, fetchzip, buildFHSUserEnv, gcc
, binary-deps-version
, binary-deps-sha
}:

#
# Collection of hacks, they really are here because of NaCl
#

rec {
  inherit binary-deps-version;

  # this one is here because of the custom toolchain NaCl uses
  unvanquished-binary-deps = fetchzip {
    url = "https://dl.unvanquished.net/deps/linux-amd64-default_${binary-deps-version}.tar.xz";
    sha256 = binary-deps-sha;
  };
}
