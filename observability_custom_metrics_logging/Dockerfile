# Build with context = fastapi-docker-optimized:
#   docker build -t YOUR_IMAGE -f Dockerfile fastapi-docker-optimized
FROM python:3.10-slim

WORKDIR /app
COPY . .

RUN pip install --no-cache-dir fastapi uvicorn

EXPOSE 80
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "80"]
