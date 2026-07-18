# ── Stage 1: Build ────────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
# Install ALL deps (including devDependencies: typescript, tsx, @types/*)
RUN npm ci

COPY . .
# Compile TypeScript → dist/
RUN npm run build

# ── Stage 2: Production runtime ───────────────────────────────
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
# Only production deps in the runtime image
RUN npm ci --only=production

# Copy compiled output from builder
COPY --from=builder /app/dist ./dist

EXPOSE 3000

ENV PORT=3000
ENV NODE_ENV=production

CMD ["node", "dist/index.js"]
