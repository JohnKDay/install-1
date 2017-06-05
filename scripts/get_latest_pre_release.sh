#!/bin/bash
# Check if the user requested a specific build
set -vx
if [[ "${1}" == "" ]]; then
	repo=install
else
        repo=${1}
fi

# Try to get the latest pre-release (could be an official release)
	releases=$(curl -s https://api.github.com/repos/contiv/${repo}/releases)
	if [[ "$releases" != *"browser_download_url"* ]]; then
                print error
		exit 1
	fi
  release=$(echo "$releases" | python -c 'import json, sys;print json.load(sys.stdin)[0]["name"]')
echo $release
