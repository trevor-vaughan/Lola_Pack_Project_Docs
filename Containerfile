FROM registry.access.redhat.com/ubi10-minimal:10.2

RUN microdnf -y install ca-certificates git tar gzip findutils shadow-utils \
    && microdnf clean all

ARG UV_VERSION=0.11.26
ADD https://astral.sh/uv/${UV_VERSION}/install.sh /tmp/uv-install.sh
RUN sh /tmp/uv-install.sh && rm -f /tmp/uv-install.sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv

ARG LOLA_REF=v0.7.0
ENV UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/opt/uv/tools \
    UV_PYTHON_INSTALL_DIR=/opt/uv/python
RUN uv python install 3.13 \
    && uv tool install --python 3.13 "git+https://github.com/LobsterTrap/lola@${LOLA_REF}" \
    && chmod -R a+rX /opt/uv /usr/local/bin/lola

RUN useradd -m -u 1001 cleanroom
USER cleanroom
WORKDIR /work
# One-shot verification image, not a long-running service: no health check.
HEALTHCHECK NONE
ENTRYPOINT ["/bin/sh"]
