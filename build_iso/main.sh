open -a Docker
docker build -t iso_builder .
docker run -it --rm --privileged -v "$(pwd)":/app -w /app -p 8000:8000 iso_builder /bin/bash
