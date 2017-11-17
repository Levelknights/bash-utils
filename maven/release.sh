#!/usr/bin/env bash

function mvnExpression {
    mvn help:evaluate -Dexpression=$1 | grep -v -e "\[INFO" | grep -v -e "^Download"
}

function lastBuildNumberForRcPrefix {
    MINOR_VER=$1
    RESULT=-1
    for i in $(git branch | grep "${MINOR_VER}"); do
        i="${i##*.}"
        RESULT=$(( $i > $RESULT ? $i : $RESULT ))
    done
    echo ${RESULT}
}

function endWith() {
    echo "$*" >&2
    exit 1
}

BRANCH_PREFIX="rc/"
PROFILES="inpar,deploy"

export ARTIFACT_ID="$(mvnExpression "project.artifactId")"
export CURRENT_VER="$(mvnExpression "project.version")"
export MINOR_VER="$(echo ${CURRENT_VER} | sed "s/-SNAPSHOT//g")"
export RC_BRANCH_PREFIX="rc/${MINOR_VER}"
export NEXT_BUILD_NUMBER=$(( $(lastBuildNumberForRcPrefix ${RC_BRANCH_PREFIX}) + 1))
export NEXT_VER="$MINOR_VER.$NEXT_BUILD_NUMBER"
export RC_BRANCH="$RC_BRANCH_PREFIX.$NEXT_BUILD_NUMBER"

echo "PROFILES    = $PROFILES"
echo "ARTIFACT_ID = $ARTIFACT_ID"
echo "CURRENT_VER = $CURRENT_VER"
echo "MINOR_VER = $MINOR_VER"
echo "RC_BRANCH_PREFIX = $RC_BRANCH_PREFIX"
echo "NEXT_BUILD_NUMBER = $NEXT_BUILD_NUMBER"
echo "NEXT_VER = $NEXT_VER"
echo "RC_BRANCH = $RC_BRANCH"

echo "[INFO] -----------------------------------------------------------"

BUILD_USER=$1
if [ "$BUILD_USER" == "" ]; then
    BUILD_USER="-";
fi

echo "BUILD_USER=${BUILD_USER}"

CURRENT_BRANCH=$(git symbolic-ref HEAD 2>/dev/null)
if [ "$CURRENT_BRANCH" != "refs/heads/master" ]; then
    git branch
    echo "[ERROR] You are not at \"refs/heads/master\" branch!";
    exit 1
fi

CHANGED=$(git diff-index --name-only HEAD --)
if [ -n "$CHANGED" ]; then
    git status
    echo "[ERROR] Changes found!";
    exit 1
fi

if [ "$JENKINS_URL" == "" ]; then
    read -p "Are you sure? " -n 1 -r
    if [[ $REPLY =~ ^[^Yy]$ ]]; then
      echo
      exit 1;
    fi
    echo
fi

echo "[INFO] setup new version in pom"
git branch "${RC_BRANCH}" || endWith "Could not create branch ${RC_BRANCH}"
git checkout "${RC_BRANCH}" || endWith "Could not checkout branch ${RC_BRANCH}"
mvn -B versions:set -DnewVersion="${NEXT_VER}" -DgenerateBackupPoms=false || endWith "Could not set new version ${NEXT_VER}"
git add -A || endWith "Could not add changed files to commit"
git commit -m "release ${NEXT_VER} (by ${BUILD_USER})" || endWith "Could not commit files as release ${NEXT_VER}"

echo "[INFO] checkout tag \"${RC_BRANCH}\" and perform DEPLOY to repository with profiles \"${PROFILES}\""
git checkout "${RC_BRANCH}" || endWith "Could not checkout branch ${RC_BRANCH} for deployment"
mvn deploy -P "${PROFILES}" -DskipTests=true || endWith "Could not successfully deploy"

echo "[INFO] push changes to SCM"
git push origin --follow-tags || endWith "Could not push tags to origin"

echo "[SUCCESS] release SUCCESS"
git checkout master --force && git clean -f -d && mvn release:clean || endWith "Could cleanup workspace"


