# Day 13 replaces this file with a multi-stage, non-root image.
# This starter image is enough for Day 1 (run the API in Docker if you want).

FROM python:3.12-slim

WORKDIR /app
COPY main.py test_api.py requirements.txt ./
RUN useradd --create-home --uid 10001 shopsphere \
    && chown -R shopsphere:shopsphere /app
USER 10001
EXPOSE 8080
CMD ["python", "main.py"]
