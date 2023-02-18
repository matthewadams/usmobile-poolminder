FROM bash:alpine3.16

LABEL version=0.1.0-dev.6

RUN apk update
RUN apk add httpie jq

COPY ./poolminder.sh /
COPY ./VERSION /
COPY ./LICENSE /
COPY ./README.md /

CMD ["--help"]
ENTRYPOINT ["./poolminder.sh"]
