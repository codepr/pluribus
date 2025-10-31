FROM elixir:1.18-alpine AS build

# install build dependencies
RUN apk add --no-cache build-base

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod
ENV COOKIE="secret"
ENV ERL_DIST_PORT=8001

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

# compile and build release
COPY lib lib
COPY rel rel
RUN mix do compile, release

# prepare release image
FROM alpine:latest AS app

# install runtime dependencies
RUN apk add --no-cache libstdc++ libgcc ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/pluribus /app

USER nobody:nobody

CMD ["bin/pluribus", "start"]
