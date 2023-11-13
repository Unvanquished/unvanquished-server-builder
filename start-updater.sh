#!/bin/sh

HERE="$(dirname "$(realpath $0)")"

if tmux -L testing-server has-session -t automated-upgrade; then
	exec tmux -L testing-server attach-session -t automated-upgrade
fi

exec tmux -L testing-server new-session \
       	-s automated-upgrade \
		-c "${HERE}" \
	"${HERE}"/updater.sh
