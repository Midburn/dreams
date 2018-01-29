# base on ruby-2.3.1 minimal image
FROM ruby:2.3.1-slim

# Install dependencies
# build-essential: Needed for many gems
# postgresql-client: used DB
# git: needed for bundle for some gems
# libpq-dev: pg gem (postgres gem)
# imagemagick libmagickcore-dev libmagickwand-dev: for rmagick gem
# libsqlite3-dev: for sqlite3 gem
# nodejs: for uglifier gem (js compression)
RUN apt-get -y update && apt-get -y install postgresql-client-9.4 build-essential \
        git libpq-dev imagemagick libmagickcore-dev libmagickwand-dev \
        libsqlite3-dev nodejs

ENV PROJECT_PATH /dreams
RUN mkdir -p  $PROJECT_PATH
WORKDIR $PROJECT_PATH

# First copy dependencies to not recreate unnecessary layers
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

RUN bundle install

COPY . .

CMD bundle exec puma -C config/puma.rb
