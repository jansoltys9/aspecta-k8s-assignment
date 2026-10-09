FROM node:22-alpine

LABEL org.opencontainers.image.title="Aspecta Backend"

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

COPY --chown=node:node server.js ./server.js

USER 1000:1000

EXPOSE 3000

CMD ["node", "server.js"]
