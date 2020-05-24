FROM elixir:1.10.3-alpine as build

# install build dependencies
RUN apk add --update git build-base

# prepare build dir
RUN mkdir /app
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get
RUN mix deps.compile

# build project
COPY lib lib
RUN mix compile

# build release
RUN mix release

# prepare release image
FROM alpine:3.9 AS app
RUN apk add --update openssl ncurses-libs

RUN mkdir /app
WORKDIR /app

# copy the release that was built earlier
COPY --from=build /app/_build/prod/rel/foghorn ./
RUN chown -R nobody: /app
USER nobody

ENV HOME=/app
ENV FOGHORN_CONFIG /config.yaml
ENV FOGHORN_DEBUG 1
ENTRYPOINT ["/app/bin/foghorn"]
