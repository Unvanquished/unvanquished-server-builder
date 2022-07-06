#
# A large wrapper that brings the server together from its pieces.
#

{ writeScript, bubblewrap, bash, gdb
, srcs
, servername
, branchname
, filename
, tmux-session-name
, daemon
, unvanquished-vms
, pakpath
, homepath
}:

writeScript "unvanquished-server" ''
  #!/bin/sh

  GDB=""
  if [ -z "$NO_GDB" ]; then
      GDB="${gdb}/bin/gdb -x $HOME/unv-testing-server/gdbinit.txt --args"
  fi

  exec tmux -L testing-server new-session -s ${tmux-session-name} -d \
      ${bubblewrap}/bin/bwrap \
          --unshare-all --share-net \
          --ro-bind /nix /nix \
          --ro-bind /etc/resolv.conf /etc/resolv.conf \
          --ro-bind ${pakpath} ${pakpath} \
          --ro-bind /var/www/cdn.unvanquished.net/unvanquished_0.52.1/pkg /var/www/cdn.unvanquished.net/unvanquished_0.52.1/pkg \
          --bind ${homepath} ${homepath} \
          --ro-bind ~/unvanquished-server/homepath/game/admin.dat ${homepath}/game/admin.dat \
          --ro-bind ${srcs.unvanquished}/dist/configs/config ${homepath}/config \
          --ro-bind ${srcs.unvanquished}/dist/configs/game/maprotation.cfg ${homepath}/game/maprotation.cfg \
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
                      -set net_port 27990 \
                      -pakpath ${pakpath} \
                      -pakpath /var/www/cdn.unvanquished.net/unvanquished_0.52.1/pkg \
                      -set fs_extrapaks experimental/${servername}/${filename} \
                      +exec server.cfg \
                      +set server.private 1 \
                      +set sv_hostname "^1Experimental ^3Development Server - ${servername}" \
                      +set g_motd "^2See the ${branchname} branch on GitHub." \
                      +set sv_allowdownload 1 \
                      +set sv_dl_maxRate 1000000 \
                      +set sv_wwwDownload 1 \
                      +set sv_wwwBaseURL "users.unvanquished.net/~afontain/pkg/nightly" \
                      +set sv_wwwFallbackURL "dl.unvanquished.net/pkg" \
                      "$@"
  ''
