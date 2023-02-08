FROM bash:alpine3.16

RUN apk update
RUN apk add httpie jq

COPY ./poolminder.sh /
ENTRYPOINT ["./poolminder.sh"]
