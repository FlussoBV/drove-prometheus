FROM prom/prometheus:v1.4.1
MAINTAINER Joost van der Griendt <joostvdg@gmail.com>
LABEL authors="Joost van der Griendt <joostvdg@gmail.com>"
LABEL version="1.0.0"
LABEL description="Docker container for confugiring Prometheus for Flusso Drove'"

ADD rootfs /