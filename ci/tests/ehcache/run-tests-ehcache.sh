#!/bin/bash
source ./ci/functions.sh

runBuild=false
echo "Reviewing changes that might affect the Gradle build..."
currentChangeSetAffectsTests
retval=$?
if [ "$retval" == 0 ]
then
    echo "Found changes that require the build to run test cases."
    runBuild=true
else
    echo "Changes do NOT affect project test cases."
    runBuild=false
fi

if [ "$runBuild" = false ]; then
    exit 0
fi


gradle="./gradlew $@"
gradleBuild=""
gradleBuildOptions="--build-cache --configure-on-demand --no-daemon -DtestCategoryType=EHCACHE"

echo -e "***********************************************"
echo -e "Gradle build started at `date`"
echo -e "***********************************************"

gradleBuild="$gradleBuild testEhcache jacocoRootReport -x test -x javadoc -x check \
    -DskipGradleLint=true \
    -DskipNestedConfigMetadataGen=true "

if [[ "${TRAVIS_COMMIT_MESSAGE}" == *"[show streams]"* ]]; then
    gradleBuild="$gradleBuild -DshowStandardStreams=true "
fi

if [[ "${TRAVIS_COMMIT_MESSAGE}" == *"[rerun tasks]"* ]]; then
    gradleBuild="$gradleBuild --rerun-tasks "
fi

if [[ "${TRAVIS_COMMIT_MESSAGE}" == *"[refresh dependencies]"* ]]; then
    gradleBuild="$gradleBuild --refresh-dependencies "
fi

if [ -z "$gradleBuild" ]; then
    echo "Gradle build will be ignored since no commands are specified to run."
else
    tasks="$gradle $gradleBuildOptions $gradleBuild"
    echo -e "***************************************************************************************"

    echo $tasks
    echo -e "***************************************************************************************"

    waitloop="while sleep 9m; do echo -e '\n=====[ Gradle build is still running ]====='; done &"
    eval $waitloop
    waitRetVal=$?

    ./ci/tests/ehcache/run-terracotta-server.sh

    eval $tasks
    retVal=$?

    docker stop tc-server

    echo -e "***************************************************************************************"
    echo -e "Gradle build finished at `date` with exit code $retVal"
    echo -e "***************************************************************************************"

    if [ $retVal == 0 ]; then
        echo "Uploading test coverage results..."
        bash <(curl -s https://codecov.io/bash)
        echo "Gradle build finished successfully."
        exit 0
    else
        echo "Gradle build did NOT finish successfully."
        exit $retVal
    fi
fi
