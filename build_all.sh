#!/bin/sh

TAG=2.3.1

./compile_javascript.sh
mix deps.clean --all

docker run -ti --rm -v $(pwd):/build elixir-builder /build/compile_release.sh && \
  sudo chown -R lauri: . && \
  docker build -t luopio/foghorn:$TAG . && \
  docker push luopio/foghorn:$TAG