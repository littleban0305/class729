FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_VERSION=3.24.3
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /opt
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa bash ca-certificates nginx \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} /opt/flutter
RUN flutter --version

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
