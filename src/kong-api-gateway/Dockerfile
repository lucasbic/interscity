FROM nginx:1.25.2-bookworm

RUN apt-get update -qq && apt-get upgrade -y

COPY dist /usr/share/nginx/html
