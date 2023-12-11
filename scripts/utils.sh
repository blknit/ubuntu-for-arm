#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

git_repo_config() {
    if [[ -z "$(git config --get user.name)" ]]
    then
        git config user.name "build"
    fi
    if [[ -z "$(git config --get user.email)" ]]
    then
        git config user.email "build@build.com"
    fi
}

git_source() {
    local git_url="$1" git_rev="$2"

    git init
    git_repo_config
    git am --abort &>/dev/null || true

    local origin=$(sha1sum <(echo "$git_url") | cut -d' ' -f1)
    git remote add $origin $git_url 2>/dev/null && true

    if (( ${#git_rev} == 40))
    then
        if [[ "$(git rev-parse FETCH_HEAD)" != "$git_rev" ]]
        then
            git fetch --depth 1 $origin $git_rev
        fi
        git reset --hard FETCH_HEAD
        git clean -ffd
        git switch --detach $git_rev
        git tag -f tag_$git_rev
    else
        git fetch --depth 1 $origin tag $git_rev
        git reset --hard FETCH_HEAD
        git clean -ffd
        git switch --detach tags/$git_rev
    fi
}