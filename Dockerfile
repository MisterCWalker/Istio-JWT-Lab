FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi

COPY server.js ./
EXPOSE 3000

HEALTHCHECK --interval=5s --timeout=2s --start-period=2s --retries=5 \
  CMD wget -qO- http://127.0.0.1:3000/ || exit 1

CMD ["node", "server.js"]