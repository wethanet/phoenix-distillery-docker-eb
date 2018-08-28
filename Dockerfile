#===========
# Build Stage
#===========
FROM elixir:1.6.5 as build
MAINTAINER Andrew McCallum andrew@wetha.net

# Create environment variables, as ElasticBeanstalk doesn't provide these except to the running app which is too late for us
ENV APP_NAME="app"
RUN $(/opt/elasticbeanstalk/containerfiles/support/generate_env | sed 's/^/export /') 
ENV DEBIAN_FRONTEND=noninteractive
ENV REPLACE_OS_VARS=true

# create app folder
RUN mkdir /app
COPY . /app
WORKDIR /app

RUN apt-get update && \
  apt-get install -y build-essential erlang-dev imagemagick erlang-xmerl && \
  apt-get clean

# install node
RUN curl -sL https://deb.nodesource.com/setup_6.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install -y -q nodejs

# install dependencies
RUN mix local.rebar
RUN mix local.hex --force

RUN mix archive.install --force https://github.com/phoenixframework/archives/raw/master/phoenix_new.ez

RUN mix deps.get
RUN mix compile

# install node dependencies
WORKDIR /app/assets
RUN npm install -g brunch
RUN npm install --unsafe-perm node-sass
RUN npm install
RUN brunch build --production

WORKDIR /app
RUN mix phx.digest

RUN mix release

RUN mkdir /release
RUN RELEASE_DIR=`ls -d /app/_build/$MIX_ENV/rel/$APP_NAME/releases/*/` && \
    mkdir /export && \
    tar -xf "$RELEASE_DIR/$APP_NAME.tar.gz" -C /export

#================
# Deployment Stage
#================
# FROM alpine:3.6

FROM elixir:1.6.5

ENV APP_NAME="app"
RUN $(/opt/elasticbeanstalk/containerfiles/support/generate_env | sed 's/^/export /') 
ENV REPLACE_OS_VARS=true

WORKDIR /app

COPY --from=build /export/ .

EXPOSE 4000

ENTRYPOINT ["/app/bin/$APP_NAME"]
CMD ["foreground"]

