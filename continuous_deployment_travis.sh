#!/usr/bin/env bash

if [ "${DEPLOY_ENVIRONMENT}" != "" ] && [ "${TRAVIS_PULL_REQUEST}" == "false" ] &&\
   ([ "${TRAVIS_BRANCH}" == "${DEPLOY_BRANCH}" ] || ([ "${DEPLOY_TAGS}" == "true" ] && [ "${TRAVIS_TAG}" != "" ])) &&\
   ! echo "${TRAVIS_COMMIT_MESSAGE}" | grep -- --no-deploy
then
    openssl aes-256-cbc -K $encrypted_6b28fc776349_key -iv $encrypted_6b28fc776349_iv -in ./k8s-ops-secret.json.enc -out ./secret-k8s-ops.json -d
    OPS_REPO_SLUG="Midburn/midburn-k8s"
    OPS_REPO_BRANCH="master"
    if [ "${TRAVIS_TAG}" != "" ]; then
        IMAGE_TAG="gcr.io/midbarrn/midburn-dreams-tag:${TRAVIS_TAG}"
    else
        IMAGE_TAG="gcr.io/midbarrn/midburn-dreams-cd:${TRAVIS_COMMIT}"
    fi
    B64_UPDATE_VALUES=`echo '{"dreams":{"image":"'${IMAGE_TAG}'"}}' | base64 -w0`
    wget https://raw.githubusercontent.com/OriHoch/sk8s-ops/master/run_docker_ops.sh
    chmod +x *.sh
    ! ./run_docker_ops.sh "${DEPLOY_ENVIRONMENT}" "/dreams/continuous_deployment.sh" \
                          "orihoch/sk8s-ops" "${OPS_REPO_SLUG}" "${OPS_REPO_BRANCH}" "" "
                            -v `pwd`:/dreams
                            -e B64_UPDATE_VALUES=${B64_UPDATE_VALUES}
                            -e K8S_OPS_GITHUB_REPO_TOKEN=${K8S_OPS_GITHUB_REPO_TOKEN}
                            -e OPS_REPO_SLUG=${OPS_REPO_SLUG}
                            -e OPS_REPO_BRANCH=${OPS_REPO_BRANCH}
                            -e B64_UPDATE_VALUES=${B64_UPDATE_VALUES}
                            -e IMAGE_TAG=${IMAGE_TAG}
                          " \
        && echo 'failed to run docker ops' && exit 1
fi

exit 0
