FROM bash:alpine3.16

LABEL version=0.1.0-dev.4

RUN apk update
RUN apk add httpie jq

COPY ./poolminder.sh /
COPY ./VERSION /
COPY ./LICENSE /
COPY ./README.md /

ENTRYPOINT ["./poolminder.sh"]