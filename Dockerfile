FROM ruby:alpine
MAINTAINER Ivan Vergés <ivan@platoniq.net>

RUN mkdir /app
COPY / /app/

RUN gem install sinatra shotgun haml aws-sdk rack-flash3

EXPOSE 8080
ENTRYPOINT ["shotgun", "--host", "0.0.0.0", "--port", "8080", "/app/s3uploader.rb"]
