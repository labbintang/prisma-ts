### BASE ###
FROM node:16-bullseye AS base

RUN apt-get update && apt-get install --no-install-recommends --yes openssl

WORKDIR /app

### BUILDER ###
FROM base AS builder

# Install production dependencies
COPY *.json package.lock ./
COPY packages/common/*.json ./packages/common/
COPY packages/backend/*.json ./packages/backend/

RUN npm install --production --pure-lockfile
RUN cp -RL packages/backend/node_modules/ /tmp/node_modules/

# Install all dependencies
RUN yarn install --pure-lockfile

# Copy source files
COPY packages/common/ ./packages/common/
COPY packages/backend/ ./packages/backend/

# Build
RUN npm --cwd ./packages/common/ build
RUN npm --cwd ./packages/backend/ generate
RUN npm --cwd ./packages/backend/ build

### RUNNER ###
FROM base

# Copy runtime dependencies
COPY --from=builder /tmp/node_modules/ ./node_modules/
COPY --from=builder /app/packages/backend/node_modules/@prisma/client/ ./node_modules/@prisma/client/
COPY --from=builder /app/packages/backend/node_modules/.prisma/client/ ./node_modules/.prisma/client/
COPY --from=builder /app/packages/common/dist/ ./node_modules/common/dist/

# Copy runtime project
COPY --from=builder /app/packages/backend/dist/src/ ./src/
COPY packages/backend/package.json ./

USER node

CMD ["node", "-r", "tsconfig-paths/register", "src/server.js"]