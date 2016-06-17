FROM alpine:3.4
MAINTAINER Lauri Kainulainen <lauri.kainulainen@gmail.com>

RUN apk --update add ncurses-libs && rm -rf /var/cache/apk/*

COPY rel /rel

ENTRYPOINT ["rel/foghorn/bin/foghorn"]