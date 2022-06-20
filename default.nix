#
# This files brings together all the parts managed by nix. That's the one
# called by the `nix` commands. It includes dev tools and handles the build of
# the engine and game.
#
{ pkgs ? import <nixpkgs> {}
, servername
, branchname
, pakpath
, homepath
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


  ######
  # Part 2: outputs
  ######

  daemon = pkgs.callPackage ./daemon.nix {
    source = srcs.daemon;
    inherit nacl-hacks-4;
    inherit nacl-hacks-5;
  };

  unvanquished-vms = pkgs.callPackage ./unvanquished.nix {
    source = srcs.unvanquished;
    daemon-source = srcs.daemon;
    inherit nacl-hacks-4;
    inherit nacl-hacks-5;
  };

  unvanquished-dpk = pkgs.callPackage ./dpk.nix {
    source = srcs.unvanquished_dpk;
    inherit unvanquished-vms;
    inherit filename;
  };


  # This is a huge-ass wrapper
  server = writeScript "unvanquished-server" ''
    #!/bin/sh

    GDB=""
    if [ -z "$NO_GDB" ]; then
        GDB="${gdb}/bin/gdb -x $HOME/unv-testing-server/gdbinit.txt --args"
    fi

    # set a default value for $@ if there is no arguments to this script
    if [ $# -eq 0 ]; then
        set -- +devmap chasm +bot fill 4
    fi

    exec tmux -L testing-server new-session -s serv-${servername} -d \
        ${bubblewrap}/bin/bwrap \
            --unshare-all --share-net \
            --ro-bind /nix /nix \
            --ro-bind ${pakpath} ${pakpath} \
            --ro-bind /var/www/cdn.unvanquished.net/unvanquished_0.52.1/pkg /var/www/cdn.unvanquished.net/unvanquished_0.52.1/pkg \
            --bind ${homepath} ${homepath} \
            --ro-bind ~/unvanquished-server/homepath/game/admin.dat ${homepath}/game/admin.dat \
            --ro-bind ~/unv-testing-server/gdbinit.txt ~/unv-testing-server/gdbinit.txt \
            --tmpfs /tmp \
            --proc /proc \
            --dev /dev \
            --die-with-parent \
            --setenv PATH  "${bash}/bin" \
            --setenv SHELL "${bash}/bin/bash" \
            -- \
                $GDB \
                    "${daemon}/bin/daemonded" \
                        -libpath ${unvanquished-vms} \
                        -homepath ${homepath} \
                        -set vm.sgame.type 3 \
                        -set server.private 1 \
                        -set sv_hostname "^1Experimental ^3Development Server - ${servername}" \
                        -set g_motd "^2See the ${branchname} branch on GitHub." \
                        -set sv_allowdownload 1 \
                        -set sv_dl_maxRate 1000000 \
                        -set sv_wwwDownload 1 \
                        -set sv_wwwBaseURL "users.unvanquished.net/~afontain/pkg/nightly" \
                        -set sv_wwwFallbackURL "dl.unvanquished.net/pkg" \
                        -set net_port 27990 \
                        -pakpath ${pakpath} \
                        -pakpath /var/www/cdn.unvanquished.net/unvanquished_0.52.1/pkg \
                        -set fs_extrapaks experimental/${servername}/${filename} \
                        "$@"
    '';
}
