# Stage 1: Build frontend assets
FROM node:22-alpine AS build

WORKDIR /src

COPY package.json package-lock.json ./

RUN npm ci --no-audit --no-fund

COPY index.html ./
COPY src/ ./src/

RUN npm run build

# Stage 2: Minimal non-root runtime
FROM nginxinc/nginx-unprivileged:stable-alpine AS runtime

COPY --from=build /src/dist/ /usr/share/nginx/html/

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
