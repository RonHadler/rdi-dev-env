# ── Stage 1: Build ──
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package manifests (support both npm and pnpm)
COPY package.json package-lock.json* ./
COPY pnpm-lock.yaml* ./

# Install dependencies — detect lock file and use appropriate tool
RUN if [ -f pnpm-lock.yaml ]; then \
      corepack enable && pnpm install --frozen-lockfile; \
    else \
      npm ci; \
    fi

COPY . .

RUN npm run build

# ── Stage 2: Production ──
FROM node:22-alpine

WORKDIR /app

# Copy build artifacts and production dependencies
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# Run as non-root (node user exists in alpine)
USER node

EXPOSE ${PORT:-3000}

CMD ["node", "dist/index.js"]
