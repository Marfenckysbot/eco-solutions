FROM node:22-alpine AS build

WORKDIR /workspace

COPY package.json package-lock.json ./
COPY apps/api/package.json ./apps/api/package.json
COPY apps/admin-dashboard/package.json ./apps/admin-dashboard/package.json
COPY packages/payments/package.json ./packages/payments/package.json

RUN npm ci
COPY apps/admin-dashboard ./apps/admin-dashboard
RUN npm run build --workspace apps/admin-dashboard

FROM nginx:1.27-alpine
COPY --from=build /workspace/apps/admin-dashboard/dist /usr/share/nginx/html
EXPOSE 80
