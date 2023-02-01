FROM ubuntu:22.04
LABEL maintainer="spyroot@gmail.com"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/New_York

RUN apt-get update
RUN apt-get install gnupg build-essential software-properties-common -y
RUN apt-get install tzdata vim curl wget unzip zip gzip unzip genisoimage jq golang-go git python3-pip gnupg2 -y
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN pip3 install jello

RUN wget --quiet -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/hashicorp-archive-keyring.gpg
RUN gpg --ignore-time-conflict --no-default-keyring --keyring /etc/apt/trusted.gpg.d/hashicorp-archive-keyring.gpg --fingerprint
RUN apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
RUN apt-get update
RUN echo 'export TERM=xterm-256color' >> /root/.bashrc
RUN echo 'export TERM=xterm-256color' >> /root/.zshrc

# TODO fix arch for now M1 has issue
RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh

RUN apt-get install zsh-autosuggestions bash-completion -y
RUN apt-get install terraform -y

ENV LANG en_US.utf8

