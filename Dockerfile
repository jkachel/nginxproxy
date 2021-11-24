FROM nginx:alpine

EXPOSE 80
EXPOSE 443

COPY config/ /etc/nginx

RUN apk add certbot certbot-nginx openssl