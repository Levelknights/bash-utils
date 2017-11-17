#!/bin/bash

function mvnExpression {
    printf '_EXPRESSION_RESULT_\t${project.version}' | mvn help:evaluate --non-recursive | grep ^_EXPRESSION_RESULT_ | cut -f2
}

function end_with() {
	echo "$*" >&2
	exit 1
}

function usage() {
	echo "Maven git variables preparation v1.0 (c) 2017 Levelknights"
	echo ""
	echo "  -p    Sets profiles variable (default 'deploy')"
	echo "  -o    Prints variables to output"
	echo "  -s    Release version strategy: cut_snapshot, last_tag, manual"
	echo "  -t    Release tag (default 'v$RELEASE_VER')"
	echo "  -v    If strategy manual, then release version"
	echo "  -n    If strategy manual, then next version (if -SNAPSHOT wanted needs to be passed)"
	echo ""
	echo "  -h    For this message"
	echo ""
}

OUTPUT=false
export PROFILES="deploy"
export ARTIFACT_ID="$(mvnExpression "project.artifactId")"
export CURRENT_VER="$(mvnExpression "project.version")"

while getopts "hp:os:t:v:n:" opt; do
	case "${opt}" in
		h)
			usage
			exit 0
			;;
		p) #Profiles
			PROFILES="${OPTARG}"
			;;
		o) #Output
			OUTPUT=true
			;;
		s) #Strategy
			_STRATEGY="${OPTARG}"
			;;
		t) #Tag name
			_TAG_NAME="${OPTARG}"
			;;
		v) #Release version
			_RELEASE_VERSION="${OPTARG}"
			;;
		n) #Next
			_NEXT_VERSION="${OPTARG}"
			;;

		*)
			usage
			end_with "Unknown parameter ${opt}"
			;;
	esac
done
shift $((OPTIND-1))

#TODO strategies

export RELEASE_VER="$(echo $CURRENT_VER | sed "s/-SNAPSHOT//g")"

export NEXT_VER=${RELEASE_VER%.*}"."$(( ${RELEASE_VER##*.} + 1 ))"-SNAPSHOT"

if [ "$_TAG_NAME" != "" ]; then
	export TAG_NAME="${_TAG_NAME}"
else 
	export TAG_NAME="v$RELEASE_VER"
fi


if [ $OUTPUT ]; then
	echo "PROFILES=$PROFILES"
	echo "ARTIFACT_ID=$ARTIFACT_ID"
	echo "CURRENT_VER=$CURRENT_VER"
	echo "RELEASE_VER=$RELEASE_VER"
	echo "TAG_NAME=$TAG_NAME"
	echo "NEXT_VER=$NEXT_VER"
fi
