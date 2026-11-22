# syntax=docker/dockerfile:1.7

FROM node:22.18.0-bookworm-slim AS base

WORKDIR /app

ENV NODE_ENV=production

FROM base AS deps

COPY package*.json ./

RUN cat package.json

RUN npm ci --include=dev --verbose

RUN cat package-lock.json | grep '"typescript"' || true

RUN ls -la node_modules

RUN ls -la node_modules/.bin

RUN npm ls --depth=0
FROM base AS builder

COPY --from=deps /app/node_modules ./node_modules

COPY package*.json ./
COPY tsconfig.json ./
COPY src ./src
COPY migrations ./migrations
RUN npm run build

FROM base AS prod-deps

COPY package*.json ./

RUN npm ci \
    --omit=dev \
    --ignore-scripts \
    --no-audit \
    --no-fund \
 && npm cache clean --force


FROM node:22.18.0-bookworm-slim AS runtime

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

LABEL org.opencontainers.image.title="LeadFlow Backend"
LABEL org.opencontainers.image.description="LeadFlow API"
LABEL org.opencontainers.image.vendor="LeadFlow Internship Assignment"

COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/migrations ./migrations
COPY package*.json ./

USER node

EXPOSE 3000

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=20s \
    --retries=3 \
CMD node -e "fetch(`http://127.0.0.1:${process.env.PORT}/healthz`).then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node","dist/server.js"]