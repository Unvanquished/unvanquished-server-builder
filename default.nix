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
}:

with pkgs;

let
  filename = "unv";

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
  };

  nacl-hacks-9 = pkgs.callPackage ./nacl-hacks.nix {
    binary-deps-version = "9";
    binary-deps-sha = "sha256-5n8gRvTuke4e7EaZ/5G+dtCG6qmnawhtA1IXIFQPkzA=";
  };


  ######
  # Part 2: outputs
  ######

  daemon = pkgs.callPackage ./daemon.nix {
    source = srcs.daemon;
    inherit nacl-hacks-9;
  };

  unvanquished-vms = pkgs.callPackage ./unvanquished.nix {
    source = srcs.unvanquished;
    daemon-source = srcs.daemon;
    inherit nacl-hacks-9;
  };

  unvanquished-dpk = pkgs.callPackage ./unv-dpk.nix {
    source = srcs.unvanquished;
    inherit unvanquished-vms;
    inherit filename;
  };

  server = pkgs.callPackage ./server-wrapper.nix {
    inherit srcs servername branchname filename tmux-session-name
            daemon unvanquished-vms pakpath homepath;
  };
}
