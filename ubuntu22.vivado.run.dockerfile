# docker build -t ubuntu22/vivado/run - < ubuntu22.vivado.run.dockerfile

FROM ubuntu:22.04

RUN apt update -qq \
 && apt install -y libtinfo5 libx11-6 locales \
 && locale-gen "en_US.UTF-8"
