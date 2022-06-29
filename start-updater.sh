#!/bin/sh

if tmux -L testing-server has-session -t automated-upgrade; then
	exec tmux -L testing-server attach-session -t automated-upgrade
fi

exec tmux -L testing-server new-session \
       	-s automated-upgrade \
       	-c ~/unv-testing-server \
	'
	last_status=0
	while true; do
		~/unv-testing-server/update.sh fetch && \
		~/unv-testing-server/update.sh compile && \
		~/unv-testing-server/update.sh deploy

		if [ $? -ne 0 ]; then
			printf "\nDeployment FAILED\n"
			[ $last_status = 0 ] && sudo -u overmind /home/overmind/msg "#unvanquished-dev" "Testing servers update \x0308failed"
			last_status=1
		else
			last_status=0
		fi

		sleep 5
		~/unv-testing-server/update.sh status

		printf "\n"
		for time in $(seq $((60*3)) -1 1); do
			printf "\rRunning update script again in %i seconds  " $time
			sleep 1
		done
		printf "\n\n"
	done'
