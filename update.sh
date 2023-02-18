#!/usr/bin/env bash
set -e

fly deploy -a poolminder --build-only -e POOLMINDER_VERBOSE=1 -e DRY_RUN='' --push --image-label "$(cat VERSION)"
