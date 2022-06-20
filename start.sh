#!/bin/sh

if tmux -L testing-server has-session -t automated-upgrade; then
	exec tmux -L testing-server attach-session -t automated-upgrade
fi

exec tmux -L testing-server new-session \
       	-s automated-upgrade \
       	-c ~/unv-testing-server \
	'while true; do
		~/unv-testing-server/update.sh fetch && \
		~/unv-testing-server/update.sh compile && \
		~/unv-testing-server/update.sh deploy

		printf "\n"
		for time in $(seq $((60*3)) -1 1); do
			printf "\rRunning update script in %i seconds  " $time
			sleep 1
		done
		printf "\n\n"
	done'
