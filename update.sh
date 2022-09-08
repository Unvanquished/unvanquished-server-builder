#!/usr/bin/env bash
set -e
set -u
set -o pipefail

##########################################################################################
# Config goes here


# This allows handling the base branches branches 0.53.0
testing_branch_suffix="/testing"
experimental_branch_suffix="/experimental"

testing_base_branch="master"
experimental_base_branch="master"

repos="DaemonEngine/Daemon Unvanquished/Unvanquished UnvanquishedAssets/unvanquished_src.dpkdir"

# the nightly pakpath
pakpath="$HOME/unvanquished-server/pakpath"
# the testing servers common paths
root="$HOME/unv-testing-server"
subpakpath="$root/pakpath"
binaries="$root/bins"
homepaths="$root/homepaths"

# only used by this script
datadir="$root/data"

# End of config
##########################################################################################

debug() {
	if [ -n "${DEBUG:-}" ]; then
		printf "$@" 1>&2
	fi
}

###
# GitHub API
###

fetch_branches() {
	mkdir -p "$datadir"
	local message
	for repo in $repos; do
		local reponame="${repo/\//-}"
		curl -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$repo/branches?per_page=100" --no-progress-meter > "$datadir/$reponame.new.json"
		if message=$(jq -r '.message' < "$datadir/$reponame.new.json" 2> /dev/null); then
			printf "Error: %s\n" "$message" 1>&2
			exit 1
		fi
		mv "$datadir/$reponame.new.json" -T "$datadir/$reponame.json"
		printf "Fetched %s\n" "$datadir/$reponame.json"
	done
}

get_branches() {
	local repo="$1"
	cat "$datadir/${repo/\//-}.json" \
		| jq "map(select(.name | endswith(\"$testing_branch_suffix\") or endswith(\"$experimental_branch_suffix\") or . == \"$testing_base_branch\" or . == \"$experimental_base_branch\"))"
}

get_branches_names() {
	# takes a list of branch like returned by $(get_branches DaemonEngine/Daemon)
	local json="$1"
	printf "%s" "$json" \
		| jq -r ".[] | .name"
}

get_branch_commit_sha() {
	local json="$1"
	local branch_name="$2"
	# takes a list of branch like get_branches_names, but will return only one result
	printf "%s" "$json" \
		| jq -r -e "map(select(.name == \"$branch_name\") | .commit.sha) | .[]"
}


###
# Data Processing
###

server_name() {
	local branch_name="$1"
	local branch_shortname="${branch_name%/*}"
	printf "%s" "${branch_shortname/\//-}"
}

tmux_session_name() {
	local server_name="$1"
	printf "serv-%s\n" "$server_name" | sed 's/\./-/g'
}

# outputs to 3 global variables
calculate_repo_info() {
	declare -Ag branches
	declare -Ag branches_names
	for repo in $repos; do
		local repo_shortname="${repo##*/}"
		repo_shortname="${repo_shortname/./-}"
		branches[$repo_shortname]="$(get_branches "$repo")"
		branches_names[$repo_shortname]="$(get_branches_names "${branches[$repo_shortname]}")"
	done

	declare -g branches_to_build
	branches_to_build=$( (for b in ${branches_names[@]}; do printf "%s\n" "$b"; done) | sort -u | grep -v '^master$' )
}

# outputs the build args to stdout
calculate_build_arguments() {
	local branch_name="$1"
	local server_name="$(server_name "$branch_name")"
	local homepath="$homepaths/$server_name"

	local base_branch
	if grep -q "$experimental_branch_suffix\$" <<<"$branch_name"; then
		base_branch="$experimental_base_branch"
	else
		base_branch="$testing_base_branch"
	fi

	printf "%s " --argstr pakpath "$pakpath"
	printf "%s " --argstr servername "$server_name"
	printf "%s " --argstr branchname "$branch_name"
	printf "%s " --argstr homepath "$homepath"
	printf "%s " --argstr tmux-session-name "$(tmux_session_name "$server_name")"
	for repo in $repos; do
		local repo_shortname="${repo##*/}"
		repo_shortname="${repo_shortname/./-}"
		local commit=""
		local branch="$branch_name"

		if ! commit=$(get_branch_commit_sha "${branches[$repo_shortname]}" "$branch_name"); then
			debug "there is no branch $branch_name in $repo_shortname, defaulting to $base_branch\n"
			commit="$(get_branch_commit_sha "${branches[$repo_shortname]}" "$base_branch")"
			branch="$base_branch"
		fi

		# maybe "https://github.com/$repo/archive/$commit.tar.gz"?
		printf "%s " --argstr $repo_shortname $branch
		printf "%s " --argstr $repo_shortname-commit $commit
	done
}

###
# Compiling
###

compile_instance() {
	local branch_name="$1"
	local server_name="$(server_name "$branch_name")"
	local build_args

	printf "\nBuilding %s.\n" "$branch_name" 1>&2

	build_args=$(calculate_build_arguments "$branch_name")

	debug "Running:   nix-build $root $build_args -A server --no-out-link"
	                  nix-build $root $build_args -A server --no-out-link

	debug "Running:   nix-build $root $build_args -A unvanquished-dpk --no-out-link"
	                  nix-build $root $build_args -A unvanquished-dpk --no-out-link

	printf "built\n" 1>&2
}

compile_instances() {
	calculate_repo_info

	debug "Building these branches: %s\n\n" "$(printf "%s " $branches_to_build)"

	for branch_name in $branches_to_build; do
		compile_instance "$branch_name"
	done
}

###
# Running
###

deploy_instance() {
	local branch_name="$1"
	local server_name="$(server_name "$branch_name")"
	local build_args

	local homepath="$homepaths/$server_name"
	# note homepath may already exist
	mkdir -p $homepath

	printf "\nDeploying %s.\n" "$branch_name" 1>&2

	build_args=$(calculate_build_arguments "$branch_name")

	new_bin=$binaries/server-$server_name-new
	old_bin=$binaries/server-$server_name
	debug "Running:   nix-build $root $build_args -A server -o $new_bin"
	                  nix-build $root $build_args -A server -o $new_bin

	new_dpk=$subpakpath/$server_name-new
	old_dpk=$subpakpath/$server_name
	debug "Running:   nix-build $root $build_args -A unvanquished-dpk -o $new_dpk"
	                  nix-build $root $build_args -A unvanquished-dpk -o $new_dpk

	# Used by the status command
	mkdir -p $datadir/deployed_daemon
	mkdir -p $datadir/deployed_dpk
	mkdir -p $datadir/deployed_server

	nix-store --query $(nix-instantiate $root $build_args -A daemon           2>/dev/null) > $datadir/deployed_daemon/$server_name
	nix-store --query $(nix-instantiate $root $build_args -A unvanquished-dpk 2>/dev/null) > $datadir/deployed_dpk/$server_name
	nix-store --query $(nix-instantiate $root $build_args -A server           2>/dev/null) > $datadir/deployed_server/$server_name

	if [ ! -L "$old_bin" ] || [ ! -L "$old_dpk" ] || \
	   [ "$(readlink $new_bin)" != "$(readlink $old_bin)" ] || \
	   [ "$(readlink $new_dpk)" != "$(readlink $old_dpk)" ]; then
		local port="$(find_server_port "$server_name")"
		if [ -z "$port" ] || $root/can_restart_server.sh localhost:$port; then
			printf "deploying new version of %s.\n" "$branch_name" 1>&2
			mv $new_bin -T $old_bin
			mv $new_dpk -T $old_dpk

			deployed_instances+=("$server_name")

			restart_instance "$server_name" "$homepath"
		else
			printf "delaying update as a player is in a team.\n" "$branch_name" 1>&2
		fi
	else
		printf "no deploy needed.\n" 1>&2
		rm $new_bin
		rm $new_dpk
	fi

	if ! tmux -L testing-server has-session -t $(tmux_session_name "$server_name") &>/dev/null; then
		printf "instance %s crashed. attempting restart\n" "$server_name" 1>&2
		restart_instance "$server_name" "$homepath"
	fi
}

deploy_instances() {
	calculate_repo_info

	for branch_name in $branches_to_build; do
		deploy_instance "$branch_name"
	done

	rsync -r --links $subpakpath/ $pakpath/experimental/
}

restart_instance() {
	local server_name="$1"
	local homepath="$2"

	if tmux -L testing-server has-session -t $(tmux_session_name "$server_name") &>/dev/null; then
		printf "killing %s\n" "$server_name" 1>&2
		rm $homepath/lock-server -f  # useful for when daemon crashed
		tmux -L testing-server kill-session -t $(tmux_session_name "$server_name")
	fi

	# this will start the new server in tmux
	printf "starting %s\n" "$server_name" 1>&2
	$binaries/server-$server_name
}

restart_all() {
	calculate_repo_info

	for branch_name in $branches_to_build; do
		local server_name="$(server_name "$branch_name")"
		local homepath="$homepaths/$server_name"
		restart_instance "$server_name" "$homepath"
	done
}

# matches a server that has this homepath and this daemon engine version
find_server() {
	local server_name="$1"
	shift
	local daemon="$(cat "$datadir/deployed_daemon/$server_name")"
	local homepath="$homepaths/$server_name"
	pgrep "$daemon" --full --list-full "$@" | grep "^[[:digit:]]\+ $daemon" | grep "$homepath "
}

# outputs the port of a running server on stdout
find_server_port() {
	local server_name="$1"
	local process pid
	if process=$(find_server "$server_name" --runstates S); then
		if pid="$(cut -f1 -d' ' <<<"$process")"; then
			lsof -n -P -p "$pid" -a -iUDP | grep UDP | head -n1 | cut -f2 -d: | tr -d ' '
		else
			return 1
		fi
	else
		return 1
	fi
}

print_server_status() {
	local server_name="$1"
	local port
	if find_server "$server_name" --runstates t >/dev/null; then
		printf "GDB (trapped)\n"
	elif port=$(find_server_port "$server_name"); then
		printf "running, listening on port %s\n" "$port"
	elif find_server "$server_name" >/dev/null; then
		printf "process exists but status unknown\n"
	else
		printf "not running\n"
	fi
}

print_status() {
	calculate_repo_info

	echo "Existing servers"
	declare -a existing_servers
	for existing_server in $datadir/deployed_server/*; do
		local existing_server="$(basename "$existing_server")"
		existing_servers+=("$existing_server")

		printf "\t%s: " "$existing_server"
		print_server_status "$existing_server"
	done

	local none=y
	for branch_name in $branches_to_build; do
		local server_name="$(server_name "$branch_name")"
		local server_exists=
		for existing in "${existing_servers[@]}"; do
			if [ "$server_name" = "$existing" ]; then
				server_exists=y
			fi
		done

		if [ "$server_exists" != y ]; then
			[ "$none" = y ] && printf "\nBranch left to build:"
			none=
			printf " %s" "$branch_name"
		fi
	done
	[ "$none" != y ] && printf "\n"

	none=y
	for existing in "${existing_servers[@]}"; do
		local should_exist=
		for branch_name in $branches_to_build; do
			local server_name="$(server_name "$branch_name")"
			if [ "$server_name" = "$existing" ]; then
				should_exist=y
			fi
		done

		if [ "$should_exist" != y ]; then
			[ "$none" = y ] && printf "\nOld servers that should be deleted: "
			none=
			printf " %s" "$existing"
		fi
	done
	[ "$none" != y ] && printf "\n"
}

case "${1:-}" in
	fetch)
		fetch_branches
		;;
	compile)
		compile_instances
		;;
	deploy)
		deployed_instances=()
		deploy_instances
		first=1
		if [ "${#deployed_instances[@]}" -gt 0 ]; then
			message='\x0303Deployed\x0399 instances'
			for instance in "${deployed_instances[@]}"; do
				if [ -n "$first" ]; then
					message="$message $instance"
					first=""
				else
					message="$message, $instance"
				fi
			done
			sudo -u overmind /home/overmind/msg '#unvanquished-dev' "$message"
		fi
		;;
	restart_all)
		restart_all
		;;
	status)
		print_status
		;;
	*)
		printf "Invalid invocation\n\n\tusage: %s fetch|compile|deploy\n\n" "$0"
		printf "fetch:       Grab the GitHub JSON files for the API\n"
		printf "compile:     Download and compile the sources\n"
		printf "deploy:      Launch all the new instances.\n"
		printf "                 \`deploy\` will:\n"
		printf "                   * Stop the outdated instances that have been updated\n"
		printf "                   * Start the new ones\n"
		printf "                   * Copy the pakpath for the http server\n"
		printf "                 Note that it *won't* stop or remove a deleted instance\n"
		printf "restart_all: Stop and restart all servers.\n"
		printf "                 Note that it *won't* stop a deleted server\n"
		;;
esac
