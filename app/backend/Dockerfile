FROM gcr.io/distroless/nodejs22-debian13:nonroot

LABEL org.opencontainers.image.title="Aspecta Backend"

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

COPY --chown=1000:1000 server.js ./server.js

USER 1000:1000

EXPOSE 3000

CMD ["server.js"]
