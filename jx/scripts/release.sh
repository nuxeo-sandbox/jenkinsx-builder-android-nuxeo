#!/usr/bin/env bash
set -e
set -u

# ensure we're not on a detached head
git checkout master

# until we switch to the new kubernetes / jenkins credential implementation use git credentials store
git config credential.helper store

export VERSION="$(jx-release-version)"
echo "Releasing version to ${VERSION}"

echo $(docker --version)
docker build -t $DOCKER_REGISTRY/$ORG/$APP_NAME:${VERSION} .
docker push $DOCKER_REGISTRY/$ORG/$APP_NAME:${VERSION}
docker tag $DOCKER_REGISTRY/$ORG/$APP_NAME:${VERSION} $DOCKER_REGISTRY/$ORG/$APP_NAME:latest
docker push $DOCKER_REGISTRY/$ORG/$APP_NAME

#jx step tag --version ${VERSION}
git tag -fa v${VERSION} -m "Release version ${VERSION}"
git push origin v${VERSION}

updatebot push-regex -r "\s+tag: (.*)" -v ${VERSION} --previous-line "\s+repository: nuxeo-sandbox/builder-android-nuxeo" values.yaml
updatebot push-version --kind helm nuxeo-sandbox/builder-android-nuxeo ${VERSION}
updatebot push-version --kind docker nuxeo-sandbox/builder-android-nuxeo ${VERSION}
updatebot update-loop
