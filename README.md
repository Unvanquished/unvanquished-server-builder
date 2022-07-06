# Unvanquished Server Builder

This is what powers the CD behind unvanquished testing servers. It is supposed
to replace nightly too, eventually. It may be extended to run other, public
servers in the future.

## What is built

There is an instance deployed on unvanquished.net that query the availables
branches in this official repos:

* https://github.com/Unvanquished/Unvanquished/
* https://github.com/UnvanquishedAssets/unvanquished\_src.dpkdir/
* https://github.com/DaemonEngine/Daemon/

And builds a server for every branch that is named either `\*/experimental`,
`\*/testing` and `0.53.0/sync` in these repos.

Each server will be composed of the matching branch for each repo when it is
available. If a branch is missing from a repo, then a `/experimental` branch will
use the `0.53.0/sync` branch as a fallback; and a `/testing` branch will use
the `master` branch as a fallback.

This mean that if a branch is based on `master` you should use the `/testing`
suffix, and if a branch is based on the next release branch, you must use the
`/experimental` suffix.

## When it built

Currently the [/start-updater.sh](/start-updater.sh) scripts checks if there
has been an update to the repos every (a bit more than) 3 minutes.

## Usage

Each server runs as a dll build inside gdb inside bubblewrap inside tmux. GDB
can be used to troubleshot crashed servers, and tmux to access the game's
terminal easily.

For typical usage, you run `start-updater.sh` and leave it running. The updater
runs in tmux, and so does every server. The servers are started inside tmux
sessions.

Use `tmux -L testing-server attach` to join the tmux server after it was started,
and you can use `^b-s` to switch between sessions.

### update.sh

This is the scripts that decides what to build and that will report the status.
See `update.sh help` for individual commands.

Note you can run the commands while the server is running. Every command except
`update.sh deploy` are perfectly safe to run in parallel or while the updater
is running. I think that the worst that can happen is that `update.sh deploy`
can give incorrect output if run twice at the same time.

### `\*.nix`

You are not really supposed to call these files manually. If you want to
understand how they work, there should be a nice comment at the beginning of
each file. `default.nix` is the entry point.

## Setup your own

1. Install [nix](https://nixos.org/download.html#nix-install-linux). Nix is
   available both on NixOS and on other Linux distros. It may work on MacOS but
   wasn't tested.
2. Install bash, tmux, curl, jq and pgrep.

You don't need a GitHub API key, this updates slowly enough not to hit the
github API limit for unauthenticated users. I you could update the curl
commands if you need more frequent updates or if you want to extend this to
include more repos.
