#!/usr/bin/env bash
set -e
set -u

QSTAT=quakestat

if [ -z "${1:-}" ]
then
	echo 'ERROR: missing server address' >&2
	exit 1
fi

data="$($QSTAT -raw $'\n' -R -tremulous "$1" | egrep '^B=|^P=')"
player_count="$(echo "$data" | egrep '^P=' | cut -c3- | sed -e 's/-//g;s/0//g' | wc -c)"
bot_count="$(echo "$data" | egrep '^B=' | cut -c3- | sed -e 's/-//g' | wc -c)"

if [ "$(($player_count - $bot_count))" -ne 0 ]; then
	exit 1
fi

true
