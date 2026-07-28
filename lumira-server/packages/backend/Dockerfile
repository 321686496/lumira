# syntax=docker/dockerfile:1

# =============================================================================
# Base — install all dependencies (pnpm workspace, hoisted node-linker)
# =============================================================================
FROM node:20-alpine AS base
RUN apk add --no-cache libc6-compat python3 make g++
RUN npm install -g pnpm@9
WORKDIR /app

# Copy workspace manifests first for better layer caching
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY packages/backend/package.json packages/backend/
COPY packages/admin/package.json packages/admin/
COPY packages/shared/package.json packages/shared/

# Use hoisted node-linker so node_modules is flat (no symlinks to .pnpm store),
# making runtime COPY straightforward.
RUN pnpm config set node-linker hoisted \
    && pnpm install --frozen-lockfile

# =============================================================================
# Builder — build shared + backend, then prune to production deps
# =============================================================================
FROM base AS builder
COPY packages/shared/ packages/shared/
COPY packages/backend/ packages/backend/

RUN pnpm --filter @lumira/shared build
RUN pnpm --filter @lumira/backend build

# Re-install with --prod to remove devDependencies from node_modules
RUN pnpm install --prod --frozen-lockfile

# =============================================================================
# Runner — minimal production image
# =============================================================================
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Production node_modules (pruned, hoisted — workspace symlinks dereferenced on COPY)
COPY --from=builder /app/node_modules/ node_modules/
COPY --from=builder /app/package.json ./
COPY --from=builder /app/packages/backend/package.json packages/backend/
COPY --from=builder /app/packages/shared/package.json packages/shared/

# Built artifacts only (no source)
COPY --from=builder /app/packages/backend/dist/ packages/backend/dist/
COPY --from=builder /app/packages/shared/dist/ packages/shared/dist/

EXPOSE 3000
CMD ["node", "packages/backend/dist/main.js"]
