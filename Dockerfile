FROM ubuntu

LABEL version=0.2.3-qa.0

RUN apt update
RUN apt install -y httpie jq

COPY ./poolminder.sh /
COPY ./VERSION /
COPY ./LICENSE /
COPY ./README.md /

CMD ["--help"]
ENTRYPOINT ["./poolminder.sh"]
