FROM ruby:3.3-slim
WORKDIR /app
COPY Gemfile ./
RUN bundle install
COPY config.ru ./
EXPOSE 8080
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "--port", "8080"]
