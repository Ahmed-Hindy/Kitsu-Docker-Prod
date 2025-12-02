# ---------- Build stage ----------
FROM node:20-alpine AS build

WORKDIR /app

# git is needed only to clone the repo
RUN apk add --no-cache git

# KITSU_VERSION comes from build args (docker-compose)
ARG KITSU_VERSION=v1.0.0
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
COPY nginx.conf /etc/nginx/conf.d/default.conf
