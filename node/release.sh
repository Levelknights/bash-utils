#!/usr/bin/env bash

function currentAppVersion() {
    node -p "require('./package').version"
}

function lastBuildNumberForRcPrefix {
    MINOR_VER=$1
    RESULT=0
    for i in $(git ls-remote --tags -q --symref origin | cut -d$'\t' -f2 | grep -v -e '{}$' | grep "${MINOR_VER}"); do
        i="${i##*.}"
        RESULT=$(( $i > $RESULT ? $i : $RESULT ))
    done
    echo ${RESULT}
}

function endWith() {
    echo "$*" >&2
    exit 1
}

RELEASE_BRANCH_PREFIX="release/"

git fetch origin

export CURRENT_VER="$(currentAppVersion)"
export MINOR_VER="$(echo ${CURRENT_VER} | sed 's/\.[^.]*$//')"
export RELEASE_TAG_PREFIX="release/${MINOR_VER}"
export NEXT_BUILD_NUMBER=$(( $(lastBuildNumberForRcPrefix ${RELEASE_TAG_PREFIX}) + 1))
export NEXT_VER="$MINOR_VER.$NEXT_BUILD_NUMBER"
export RELEASE_TAG="$RELEASE_TAG_PREFIX.$NEXT_BUILD_NUMBER"

echo "CURRENT_VER = $CURRENT_VER"
echo "MINOR_VER = $MINOR_VER"
echo "RELEASE_TAG_PREFIX = $RELEASE_TAG_PREFIX"
echo "NEXT_BUILD_NUMBER = $NEXT_BUILD_NUMBER"
echo "NEXT_VER = $NEXT_VER"
echo "RELEASE_TAG = $RELEASE_TAG"

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

echo "[INFO] Create release branch & setup new version in node"
git checkout -b "${RELEASE_TAG}"
npm version "${NEXT_VER}" || endWith "Could not set new version ${NEXT_VER}"

echo "[INFO] push changes to SCM"
git push --set-upstream origin develop || endWith "COuld not push branch to origin"
git push --tags origin develop || endWith "Could not push tags to origin"

