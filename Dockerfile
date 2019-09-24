FROM ubuntu:bionic
RUN apt-get update && apt-get install -y \
    curl \
    gdal-bin \
    jq \
    sqlite \
    libssl1.0.0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/

RUN curl -O -L https://github.com/t-rex-tileserver/t-rex/releases/download/v0.10.0/t-rex-v0.10.0-x86_64-unknown-linux-gnu.deb \
    && apt install ./t-rex-v0.10.0-x86_64-unknown-linux-gnu.deb && rm ./t-rex-v0.10.0-x86_64-unknown-linux-gnu.deb

RUN curl -O -L https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc && mv ./mc /usr/bin

COPY scripts/trex_mvt.sh .
COPY scripts/config.toml.template .