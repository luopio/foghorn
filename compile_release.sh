#!/bin/sh

mix deps.get --only prod
mix compile
mix release.clean --implode
mix release
