FROM ruby:2.7.4
WORKDIR /usr/src/app
COPY . .
RUN bundle config mirror.https://rubygems.org https://gems.ruby-china.com && bundle install
CMD bundle exec jekyll serve --host 0.0.0.0 --port 4000 --force_polling
EXPOSE 4000

# docker build -t jekyll .
# docker run --name jekyll --rm -p 4000:4000 -v %cd%:/usr/src/app jekyll