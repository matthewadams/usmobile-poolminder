FROM bash:alpine3.16

LABEL version=0.3.0-dev.0

RUN apk update
RUN apk add httpie jq

COPY ./poolminder.sh /
COPY ./VERSION /
COPY ./LICENSE /
COPY ./README.md /

CMD ["--help"]
ENTRYPOINT ["./poolminder.sh"]
