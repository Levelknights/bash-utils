#!/usr/bin/env bash

function endWith() {
    echo "$*" >&2
    exit 1
}
echo "[INFO] -----------------------------------------------------------"

BUILD_USER=$1
if [ "$BUILD_USER" == "" ]; then
    BUILD_USER="unknown user";
fi

CHANGED=$(git diff-index --name-only HEAD --)
if [ -n "$CHANGED" ]; then
    git status
    echo "[ERROR] Changes found!";
    exit 1
fi

if [ "$JENKINS_HOME" == "" ]; then
    read -p "Are you sure? " -n 1 -r
    if [[ $REPLY =~ ^[^Yy]$ ]]; then
      echo
      exit 1;
    fi
    echo
else 
    BUILD_USER="Jenkins"
fi

git fetch origin
git flow init --defaults

# git flow release (new branch and tag)
RELEASE_BRANCH_NAME=$(node -p "require('./package').version" | sed "s/-SNAPSHOT//g")
git flow release start "${RELEASE_BRANCH_NAME}"

# change version
yarn version --minor --no-git-tag-version || endWith "Could not set version in package.json"
RELEASE_VERSION=$(node -p "require('./package').version") || endWith "Could not get current version"
git add -A && git commit -m"change version to ${RELEASE_VERSION} (by ${BUILD_USER})" || endWith "Could not commit release version"
export RELEASE_VERSION

# finish release
export GIT_MERGE_AUTOEDIT=no
git flow release finish -m "release version ${RELEASE_VERSION}" "${RELEASE_VERSION}"  || endWith "Could not execute git flow release"
export GIT_MERGE_AUTOEDIT=""

# increase develop version 
yarn version --minor --no-git-tag-version || endWith "Could not increment version"
NEW_WORKING_VERSION="$(node -p "require('./package').version")-SNAPSHOT" || endWith "Could not prepare new version with snapshot"
yarn version --new-version="${NEW_WORKING_VERSION}" --no-git-tag-version || endWith "Could not set version with snapshot"
git add -A && git commit -m"new working version ${NEW_WORKING_VERSION} (by ${BUILD_USER})" || endWith "Could not commit new working version"

echo "[INFO] push changes to SCM"
git push --set-upstream origin develop || endWith "Could not push branch to origin"
git push --tags origin || endWith "Could not push tags to origin"
git push --all origin || endWith "Could not push all to origin"


