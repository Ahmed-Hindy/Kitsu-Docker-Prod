
FROM node:20-bullseye AS build

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 --branch v1.0.0 https://github.com/cgwire/kitsu.git .


ENV PUBLIC_API_URL=${KITSU_PUBLIC_API_URL:-http://localhost:8080/api}

RUN npm ci || npm install
RUN npm run build


FROM nginx:1.27-alpine AS kitsu-web

COPY --from=build /app/dist/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
