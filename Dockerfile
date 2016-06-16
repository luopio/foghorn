#FROM alpine:3.4
FROM msaraiva/elixir
MAINTAINER Lauri Kainulainen <lauri.kainulainen@gmail.com>

RUN apk --update add ncurses-libs && rm -rf /var/cache/apk/*
# COPY . /usr/src/app
# ADD foghorn /usr/local/bin/foghorn
# ENTRYPOINT ["/usr/local/bin/foghorn"]

COPY rel /rel
ENTRYPOINT ["rel/foghorn/bin/foghorn"]

# CMD ['mix', 'run']
