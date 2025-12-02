# dserver Docker image
# Python 3.12-slim based container for running dservercore with plugins
FROM python:3.12-slim

SHELL ["/bin/bash", "-c"]

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# System dependencies
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        curl \
        git \
        gcc \
        libpq-dev \
        python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid 1000 dserver \
    && useradd --uid 1000 --gid dserver --shell /bin/bash --create-home dserver

# Create directories
RUN mkdir -p /venv /scripts /app \
    && chown -R dserver:dserver /venv /scripts /app

# Copy scripts
COPY --chown=dserver:dserver ./compose/dserver/scripts /scripts
RUN chmod +x /scripts/*.sh

# Set working directory
WORKDIR /app

# Switch to non-root user
USER dserver

# Entrypoint activates the virtual environment
ENTRYPOINT ["/scripts/entrypoint.sh"]

# Default command
CMD ["/scripts/start-dserver.sh"]
