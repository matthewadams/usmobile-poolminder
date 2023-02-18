#!/usr/bin/env bash
set -e

APP=poolminder
APP_ARG="-a $APP"
APP_REGEX="^$APP"
TAG="$(cat VERSION)"
SCHEDULE=${1:-hourly}

LOCATION=local
if [ -z "$(which docker)" ]; then
  LOCATION=remote
fi

if [ -z "$(fly apps list | grep -vE '^APP\s+' | grep -iE "$APP_REGEX\s+")" ]; then
  echo "No app named $APP found; creating." >&2
  fly apps create $APP --machines
else
  echo "App $APP exists; not creating." >&2
fi

echo "Building & pushing Docker image $LOCATIONly." >&2
fly deploy \
  $APP_ARG \
  --build-only \
  --$LOCATION-only \
  --push \
  --image-label $TAG \
  --verbose

# just nuke all machines & run a new one
IDS="$(fly machine list -q $APP_ARG)"
if echo "$IDS" | grep -Eqv '^No\s+'; then # -q should only emit machine ids or nothing, but it doesn't
  echo "Existing machine(s) found; destroying." >&2
  IDS="$(echo "$IDS" | tail -n +6)" # -q should only emit machine ids or nothing, but it doesn't
  for id in $IDS; do
    echo "Destroying machine $id." >&2
    fly machine destroy "$id" $APP_ARG -f --verbose
  done
fi

IMAGE=registry.fly.io/$APP:$TAG
echo "Running $IMAGE on a new machine $SCHEDULE." >&2
fly machine run \
  $IMAGE \
  $APP_ARG \
  --schedule $SCHEDULE \
  -e POOLMINDER_VERBOSE=1 \
  -e POOLMINDER_NO_DRY_RUN=1 \
  --detach \
  --verbose
