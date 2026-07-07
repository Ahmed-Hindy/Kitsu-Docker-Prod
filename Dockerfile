# ---------- Build stage ----------
FROM node:22-alpine AS build

WORKDIR /app

# KITSU_VERSION must be passed from versions.env by Compose or CI.
ARG KITSU_VERSION
RUN test -n "$KITSU_VERSION" || (echo "KITSU_VERSION build arg is required" >&2; exit 1)
ENV KITSU_VERSION=${KITSU_VERSION}

# git is needed only to clone the repo
RUN apk add --no-cache git
RUN git clone --depth=1 --branch "${KITSU_VERSION}" https://github.com/cgwire/kitsu.git .

# Vite reads VITE_* variables at build time
# This comes from docker-compose build args
ARG VITE_API_URL=/api
ENV VITE_API_URL=${VITE_API_URL}

# Install dependencies and build
RUN npm ci
RUN npm run build

# ---------- Runtime stage ----------
FROM nginx:1.27-alpine AS kitsu-web

# Copy built assets from builder
COPY --from=build /app/dist/ /usr/share/nginx/html/
COPY kitsu-web.nginx.conf /etc/nginx/conf.d/default.conf
