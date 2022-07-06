#
# This files brings together all the parts managed by nix. That's the one
# called by the `nix` commands. It handles the build of the engine, game and
# dpk.
#

{ pkgs ? import <nixpkgs> {}
, servername
, branchname
, pakpath
, homepath
, tmux-session-name
# source info
, Daemon
, Daemon-commit
, Unvanquished
, Unvanquished-commit
, unvanquished_src-dpkdir
, unvanquished_src-dpkdir-commit
}:

with pkgs;

let
  filename = "unv-${servername}";

in rec {
  ######
  # Part 1: sources
  ######

  srcs = {
    # engine
    daemon = builtins.fetchGit {
      url = "https://github.com/DaemonEngine/Daemon.git";
      rev = Daemon-commit;
      ref = Daemon;
      submodules = true;
    };

    # game code
    unvanquished = builtins.fetchGit {
      url = "https://github.com/Unvanquished/Unvanquished.git";
      rev = Unvanquished-commit;
      ref = Unvanquished;
      submodules = true;
    };

    # assets
    unvanquished_dpk = builtins.fetchGit {
      url = "https://github.com/UnvanquishedAssets/unvanquished_src.dpkdir.git";
      rev = unvanquished_src-dpkdir-commit;
      ref = unvanquished_src-dpkdir;
    };
  };

  nacl-hacks-4 = pkgs.callPackage ./nacl-hacks.nix {
    binary-deps-version = "4";
    binary-deps-sha = "sha256-N/zkUhPFnU15QSe4NGmVLmhU7UslYrzz9ZUWuLbydyE=";
  };
  nacl-hacks-5 = pkgs.callPackage ./nacl-hacks.nix {
    binary-deps-version = "5";
    binary-deps-sha = "sha256-N/zkUhPFnU15QSe4NGmVLmhU7UslYrzz9ZUWuLbydyE=";
  };
  nacl-hacks-6 = pkgs.callPackage ./nacl-hacks.nix {
    binary-deps-version = "6";
    binary-deps-sha = "sha256-ERfg89oTf9JTtv/qRnTRIzFP+zMpHT8W4WAIxqogy9E=";
  };


  ######
  # Part 2: outputs
  ######

  daemon = pkgs.callPackage ./daemon.nix {
    source = srcs.daemon;
    inherit nacl-hacks-4 nacl-hacks-5 nacl-hacks-6;
  };

  unvanquished-vms = pkgs.callPackage ./unvanquished.nix {
    source = srcs.unvanquished;
    daemon-source = srcs.daemon;
    inherit nacl-hacks-4 nacl-hacks-5 nacl-hacks-6;
  };

  unvanquished-dpk = pkgs.callPackage ./dpk.nix {
    source = srcs.unvanquished_dpk;
    inherit unvanquished-vms;
    inherit filename;
  };

  server = pkgs.callPackage ./server-wrapper.nix {
    inherit srcs servername branchname filename tmux-session-name
            daemon unvanquished-vms pakpath homepath;
  };
}
