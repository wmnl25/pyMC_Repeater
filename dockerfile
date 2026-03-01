# ---------------------------
# Builder stage
# ---------------------------
FROM python:3.11-alpine AS builder

WORKDIR /build

# Build dependencies
RUN apk add --no-cache \
    build-base \
    linux-headers \
    python3-dev

COPY pyproject.toml .
COPY repeater ./repeater

# Build wheels (including spidev)
RUN pip wheel --no-cache-dir --wheel-dir /wheels .

# ---------------------------
# Runtime stage
# ---------------------------
FROM python:3.11-alpine

ENV PYTHONUNBUFFERED=1 \
    CONFIG_PATH=/etc/pymc_repeater/config.yaml

ARG UID=10001
ARG GID=10001

# Create non-root user
RUN addgroup -g ${GID} repeater && \
    adduser -D -u ${UID} -G repeater repeater

WORKDIR /opt/pymc_repeater

# Copy wheels from builder
COPY --from=builder /wheels /wheels

# Install from wheels only
RUN pip install --no-cache-dir /wheels/* && \
    rm -rf /wheels

# Config directory
RUN mkdir -p /etc/pymc_repeater && \
    chown -R ${UID}:${GID} /etc/pymc_repeater

USER ${UID}:${GID}

EXPOSE 8000

ENTRYPOINT ["/bin/sh", "-c", "test -f ${CONFIG_PATH} || (echo 'Missing config.yaml' && exit 1); exec python3 -m repeater --config ${CONFIG_PATH}"]
