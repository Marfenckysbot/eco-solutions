FROM node:22-alpine

WORKDIR /workspace

COPY package.json package-lock.json ./
COPY apps/api/package.json ./apps/api/package.json
COPY apps/admin-dashboard/package.json ./apps/admin-dashboard/package.json
COPY packages/payments/package.json ./packages/payments/package.json

RUN npm ci --omit=dev

COPY apps/api ./apps/api
COPY packages/payments ./packages/payments

WORKDIR /workspace/apps/api
ENV NODE_ENV=production
ENV PORT=5000
EXPOSE 5000

CMD ["npm", "start"]
