FROM ubuntu

LABEL version=0.3.0-dev.0

RUN apt update
RUN apt install -y httpie jq

COPY ./poolminder.sh /
COPY ./VERSION /
COPY ./LICENSE /
COPY ./README.md /

CMD ["--help"]
ENTRYPOINT ["./poolminder.sh"]
