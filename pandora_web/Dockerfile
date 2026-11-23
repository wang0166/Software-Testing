# ---------- Build stage ----------
FROM m.daocloud.io/docker.io/library/node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

ENV VITE_USE_MOCK=false
ENV VITE_API_BASE=/api

RUN npm run build


# ---------- Runtime stage ----------
FROM m.daocloud.io/docker.io/library/nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]