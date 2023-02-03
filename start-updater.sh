#!/bin/sh

if tmux -L testing-server has-session -t automated-upgrade; then
	exec tmux -L testing-server attach-session -t automated-upgrade
fi

exec tmux -L testing-server new-session \
       	-s automated-upgrade \
		-c ~/unv-testing-server \
	~/unv-testing-server/updater.sh
