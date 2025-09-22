FROM alpine:latest

RUN apk add --no-cache curl bash jq

# Install s5cmd
RUN curl -L https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_Linux-64bit.tar.gz | tar -xz -C /usr/local/bin s5cmd

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
