# Build Kitsu (frontend)
FROM node:20-bullseye AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
RUN git clone --depth=1 https://github.com/cgwire/kitsu.git .
# Vite exposes only VITE_* at build time; we pass it from compose
ARG VITE_API_URL=/api
ENV VITE_API_URL=${VITE_API_URL}
RUN npm ci || npm install
RUN npm run build

# Serve with Nginx and proxy /api to the backend
FROM nginx:1.27-alpine
COPY --from=build /app/dist/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
