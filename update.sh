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
experimental_base_branch="0.53.0/sync"

repos="DaemonEngine/Daemon Unvanquished/Unvanquished UnvanquishedAssets/unvanquished_src.dpkdir"

pakpath="$HOME/unvanquished-server/pakpath"
root="$HOME/unv-testing-server"
subpakpath="$root/pakpath"
binaries="$root/bins"
homepaths="$root/homepaths"

# End of config
##########################################################################################

###
# JSON handling
###
get_branches() {
	local repo="$1"
	#cat ${repo/\//-}.json \
	curl -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/"$repo"/branches?per_page=100" --no-progress-meter \
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

fetch_repo_info() {
	declare -Ag branches
	declare -Ag branches_names
	for repo in $repos; do
		local shortname="${repo##*/}"
		shortname="${shortname/./-}"
		branches[$shortname]="$(get_branches "$repo")"
		branches_names[$shortname]="$(get_branches_names "${branches[$shortname]}")"
	done

	declare -g branches_to_build
	branches_to_build=$( (for b in ${branches_names[@]}; do printf "%s\n" "$b"; done) | sort -u | grep -v '^master$' | grep -v '^0.53.0/sync$' )
}

build_instance() {
	local branch_name="$1"
	local branch_shortname="${branch_name%/*}"
	local server_name="${branch_shortname/\//-}"
	echo "# Building $branch_name."

	local homepath="$homepaths/$server_name"
	mkdir -p $homepath

	if grep -q "$experimental_branch_suffix\$" <<<"$branch_name"; then
		base_branch="$experimental_base_branch"
	else
		base_branch="$testing_base_branch"
	fi

	local build_args="--argstr pakpath $pakpath"
	build_args="$build_args --argstr servername $server_name"
	build_args="$build_args --argstr branchname $branch_name"
	build_args="$build_args --argstr homepath $homepath"
	for repo in $repos; do
		local shortname="${repo##*/}"
		shortname="${shortname/./-}"
		local commit=""
		local branch="$branch_name"

		if ! commit=$(get_branch_commit_sha "${branches[$shortname]}" "$branch_name"); then
			echo "there is no branch $branch_name in $shortname, taking default"
			commit="$(get_branch_commit_sha "${branches[$shortname]}" "$base_branch")"
			branch="$base_branch"
		fi

		#echo "https://github.com/$repo/archive/$commit.tar.gz"
		build_args="$build_args --argstr $shortname $branch"
		build_args="$build_args --argstr $shortname-commit $commit"
	done

	echo "Running:   nix-build $root $build_args -A server -o $binaries/server-$server_name"
	                 nix-build $root $build_args -A server -o $binaries/server-$server_name

	echo "Running:   nix-build $root $build_args -A unvanquished-dpk -o $subpakpath/$server_name"
	                 nix-build $root $build_args -A unvanquished-dpk -o $subpakpath/$server_name
}

build_instances() {
	echo "Building these branches:" $branches_to_build
	# TODO: atomic updates and all
	[ -d $subpakpath ] && rm -rf $subpakpath || :
	mkdir -p $subpakpath
	[ -d $binaries ] && rm -rf $binaries || :
	mkdir -p $binaries
	for branch_name in $branches_to_build; do
		build_instance "$branch_name"
	done
	rsync -r --links $subpakpath/ $pakpath/experimental/
}

main() {
	fetch_repo_info
	build_instances
}

main "$@"
