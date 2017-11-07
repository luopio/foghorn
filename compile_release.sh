#!/bin/sh

export MIX_ENV=prod
mix deps.get --only prod && \
    mix compile && \
    mix release.clean --implode && \
    mix release
