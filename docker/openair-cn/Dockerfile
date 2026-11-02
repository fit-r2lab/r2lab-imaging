FROM ubuntu:latest

USER root

RUN apt-get update && apt-get -y install python3

RUN mkdir /root/openair

COPY * /root/openair/

WORKDIR /root/openair

RUN ./oai-gw.sh dumpvars
RUN ./oai-gw.sh base1
RUN ./oai-gw.sh base2
RUN ./oai-gw.sh deps
RUN ./oai-gw.sh build
