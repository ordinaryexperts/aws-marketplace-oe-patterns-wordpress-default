FROM ubuntu:20.04

# setup timezone
RUN echo 'Etc/UTC' > /etc/timezone && \
    ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && \
    apt-get install -q -y --no-install-recommends tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -q -y --no-install-recommends \
    curl    \
    dirmngr \
    git     \
    gnupg2  \
    groff   \
    jq      \
    less    \
    nano    \
    tree    \
    unzip   \
    vim     \
    wget    \
    && rm -rf /var/lib/apt/lists/*
