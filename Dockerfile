FROM elixir:1.17-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git npm

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy source code
COPY . .

# Compile assets
WORKDIR /app/assets
RUN npm install
WORKDIR /app
RUN mix assets.deploy

# Build release
RUN mix compile && \
  mix release

# Start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

# Copy the release from the build stage
COPY --from=build /app/_build/prod/rel/post_meeting_app .

# Expose port
EXPOSE 4000

# Set environment
ENV PHX_SERVER=true

# Run migrations and start server
CMD ["bin/post_meeting_app", "start"]

