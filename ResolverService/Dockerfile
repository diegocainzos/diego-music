FROM python:3.13-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    DENO_DIR=/tmp/deno \
    PYTHONPATH=/service

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /service
COPY ResolverService/requirements.txt ./requirements.txt
RUN python -m pip install --requirement requirements.txt

RUN useradd --create-home --uid 10001 resolver \
    && mkdir -p /var/cache/diegomusic /service/data /home/resolver/.cache \
    && chown -R resolver:resolver /var/cache/diegomusic /service/data /home/resolver

COPY --chown=resolver:resolver ResolverService/app ./app
COPY --chown=resolver:resolver app ./backend_app
USER resolver

EXPOSE 8080
CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers", "--forwarded-allow-ips", "*", "--no-access-log"]
