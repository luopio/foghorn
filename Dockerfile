FROM alpine:3.4
MAINTAINER Lauri Kainulainen <lauri.kainulainen@gmail.com>

RUN apk --update add ncurses-libs && rm -rf /var/cache/apk/*

COPY _build /_build

EXPOSE 5555

ENV FOGHORN_CONFIG /config.yaml

ENTRYPOINT ["_build/prod/rel/foghorn/bin/foghorn"]
