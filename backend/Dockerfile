FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npx tsc

EXPOSE 3000

# Cloud Run requires the PORT env var
ENV PORT=3000
ENV NODE_ENV=production

CMD ["node", "dist/index.js"]
