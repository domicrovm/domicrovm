FROM ruby:4.0-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile ./
RUN bundle install

FROM ruby:4.0-slim
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY Gemfile config.ru ./
EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "--port", "8080"]
