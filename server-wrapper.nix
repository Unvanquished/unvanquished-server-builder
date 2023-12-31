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

let killerWrapper = writeScript "killer-wrapper" ''
  #!${bash}/bin/bash
  /bin/sh -c "sleep 3d; kill $$" &
  exec "$@"
  '';

in writeScript "unvanquished-server" ''
  #!${bash}/bin/bash

  if [ -f "${srcs.unvanquished}/dist/configs/servername.txt" ]; then
      SERVERNAME="$(cat "${srcs.unvanquished}/dist/configs/servername.txt")"
  else
      SERVERNAME="^1Experimental ^3Development Server - ${servername}"
  fi

  # Grab server's config from the source code, if available.
  # We check the file exists first, because we need to omit the argument if
  # that path doesn't exist, or bwrap will refuse to start if it's missing.
  BWRAP_ARGS=""
  for src_path in game/layouts config game/maprotation.cfg; do
      if [ -e ${srcs.unvanquished}/dist/configs/$src_path ]; then
          BWRAP_ARGS="$BWRAP_ARGS --ro-bind ${srcs.unvanquished}/dist/configs/$src_path ${homepath}/$src_path"
      fi
  done

  exec tmux -L testing-server new-session -s ${tmux-session-name} -d \
      ${killerWrapper} \
          ${bubblewrap}/bin/bwrap \
              --unshare-all --share-net \
              --ro-bind /nix /nix \
              --ro-bind /etc/resolv.conf /etc/resolv.conf \
              --ro-bind ${pakpath} ${pakpath} \
              --ro-bind /var/www/dl.unvanquished.net/pkg /var/www/dl.unvanquished.net/pkg \
              --ro-bind /home/sweet/public_html/pkg /home/sweet/public_html/pkg \
              --bind ${homepath} ${homepath} \
              --ro-bind ~/unvanquished-server/homepath/game/admin.dat ${homepath}/game/admin.dat \
              --ro-bind ~/unv-testing-server/gdbinit.txt ~/unv-testing-server/gdbinit.txt \
              $BWRAP_ARGS \
              --tmpfs /tmp \
              --proc /proc \
              --dev /dev \
              --die-with-parent \
              --setenv PATH  "${bash}/bin" \
              --setenv SHELL "${bash}/bin/bash" \
              -- \
                  ${gdb}/bin/gdb -x $HOME/unv-testing-server/gdbinit.txt --args \
                      "${daemon}/bin/daemonded" \
                          -libpath ${unvanquished-vms} \
                          -homepath ${homepath} \
                          -set vm.sgame.type 3 \
                          -set net_port 27990 \
                          -pakpath ${pakpath} \
                          -pakpath /var/www/dl.unvanquished.net/pkg \
                          -pakpath /home/sweet/public_html/pkg \
                          -set fs_extrapaks exp/${servername}/${filename} \
                          +exec server.cfg \
                          +set sv_hostname "$SERVERNAME" \
                          +set g_motd "^2See the ${branchname} branch on GitHub." \
                          +set sv_allowdownload 1 \
                          +set sv_dl_maxRate 1000000 \
                          +set sv_wwwDownload 1 \
                          +set sv_wwwBaseURL "users.unvanquished.net/~afontain/pkg/nightly" \
                          +set sv_wwwFallbackURL "dl.unvanquished.net/pkg" \
                          +exec server-overrides.cfg \
                          "$@"
  ''
