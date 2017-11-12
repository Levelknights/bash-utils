#!/usr/bin/env bash

function mvnExpression {
    printf '_EXPRESSION_RESULT_\t${project.version}' | mvn help:evaluate --non-recursive | grep ^_EXPRESSION_RESULT_ | cut -f2
}

function lastBuildNumberForRcPrefix {
    MINOR_VER=$1
    RESULT=-1
    for i in $(git tag | grep "${MINOR_VER}"); do
        i="${i##*.}"
        RESULT=$(( $i > $RESULT ? $i : $RESULT ))
    done
    echo ${RESULT}
}

PROFILES="deploy"

export ARTIFACT_ID="$(mvnExpression "project.artifactId")"
export CURRENT_VER="$(mvnExpression "project.version")"
export MINOR_VER="$(echo ${CURRENT_VER} | sed "s/-SNAPSHOT//g")"
export RC_TAG_PREFIX="release-${MINOR_VER}"
export NEXT_BUILD_NUMBER=$(( $(lastBuildNumberForRcPrefix ${RC_TAG_PREFIX}) + 1))
export NEXT_VER="$MINOR_VER.$NEXT_BUILD_NUMBER"
export RC_TAG="$RC_TAG_PREFIX.$NEXT_BUILD_NUMBER"

echo "PROFILES = $PROFILES"
echo "ARTIFACT_ID = $ARTIFACT_ID"
echo "CURRENT_VER = $CURRENT_VER"
echo "MINOR_VER = $MINOR_VER"
echo "RC_TAG_PREFIX = $RC_TAG_PREFIX"
echo "NEXT_BUILD_NUMBER = $NEXT_BUILD_NUMBER"
echo "NEXT_VER = $NEXT_VER"
echo "RC_TAG = $RC_TAG"

echo "[INFO] -----------------------------------------------------------"

if [[ "$CURRENT_VER" != *"-SNAPSHOT" ]]; then
    echo "[ERROR] You shouldn't release not SNAPSHOT version"
    exit 1
fi

BUILD_USER=$1
if [ "$BUILD_USER" == "" ]; then
    BUILD_USER="unknown user";
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
mvn -B versions:set -DnewVersion="${NEXT_VER}" -DgenerateBackupPoms=false \
    && git add -A \
    && git commit -m "release ${NEXT_VER} (by ${BUILD_USER})" \
    && git tag "${RC_TAG}"

echo "[INFO] checkout tag \"${RC_TAG}\" and perform DEPLOY to repository with profiles \"${PROFILES}\""
mvn deploy -P "${PROFILES}" -DskipTests=true

echo "[INFO] push changes to SCM"
git push origin --follow-tags

echo "[SUCCESS] release SUCCESS"
git reset --hard origin/master && git clean -f -d && mvn release:clean

