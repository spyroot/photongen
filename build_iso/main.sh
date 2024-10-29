docker build -t iso_builder .
docker run -it --rm --privileged -v "$(pwd)":/app -w /app iso_builder /bin/bash