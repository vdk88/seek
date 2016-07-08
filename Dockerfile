FROM ruby:2.1

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libssl-dev build-essential git libreadline-dev \
            libxml++2.6-dev openjdk-7-jdk libsqlite3-dev sqlite3 libcurl4-gnutls-dev \
            poppler-utils libreoffice libmagick++-dev libxslt1-dev libpq-dev ruby2.1 ruby2.1-dev \
            nodejs build-essential mysql-client postgresql-client nginx \
            telnet vim links && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
ENV RAILS_ENV=production

# Bundle install throw errors if Gemfile has been modified since Gemfile.lock
COPY Gemfile* ./
RUN bundle config --global frozen 1 && \
    bundle install --without development test

# App code (picky about what gets copied to make caching of the assets:precompile more likely)
COPY Rakefile config.ru ./
COPY app app
COPY config config
COPY db db
COPY lib lib
COPY public public
COPY spec spec
COPY script script
COPY solr solr
COPY vendor vendor

# SQLite Database (for asset compilation)
RUN cp config/database.sqlite.yml config/database.yml && \
    bundle exec rake db:setup
RUN bundle exec rake assets:precompile

# Config
COPY docker/seek_local.rb config/initializers/seek_local.rb
COPY config/sunspot.default.yml config/sunspot.yml

COPY docker docker

COPY docker/nginx.conf /etc/nginx/sites-available/default

# Cleanup
RUN rm -rf /tmp/* /var/tmp/*

# Network
EXPOSE 80

# Shared
VOLUME ["/home/app/seek/filestore", "/home/app/seek/config", "/home/app/seek/log"]

CMD ["docker/entrypoint.sh"]