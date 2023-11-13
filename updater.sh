last_status=0
HERE="$(dirname "$(realpath $0)")"

while true; do
	"${HERE}"/update.sh fetch && \
	"${HERE}"/update.sh compile && \
	"${HERE}"/update.sh deploy

	if [ $? -ne 0 ]; then
		printf "\nDeployment FAILED\n"
		last_status=1
	else
		last_status=0
	fi

	sleep 5
	"${HERE}"/update.sh status

	printf "\n"
	for time in $(seq $((60*3)) -1 1); do
		printf "\rRunning update script again in %i seconds  " $time
		sleep 1
	done
	printf "\n\n"
done
