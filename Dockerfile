# ═══════════════════════════════════════════════════════════════
# 4. Dockerfile
# ═══════════════════════════════════════════════════════════════

---
FROM node:18-alpine AS frontend-builder

WORKDIR /app
COPY app/frontend/package*.json ./
RUN npm install
COPY app/frontend/ ./
RUN npm run build

# ═══════════════════════════════════════════════════════════════

FROM python:3.11-slim

# تثبيت الأدوات الضرورية
RUN apt-get update && apt-get install -y \
    mergerfs \
    gcc \
    make \
    wget \
    smartmontools \
    util-linux \
    parted \
    e2fsprogs \
    curl \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# تثبيت SnapRAID
RUN cd /tmp && \
    wget https://github.com/amadvance/snapraid/releases/download/v12.3/snapraid-12.3.tar.gz && \
    tar xzf snapraid-12.3.tar.gz && \
    cd snapraid-12.3 && \
    ./configure && make && make install && \
    cd / && rm -rf /tmp/snapraid-*

# إعداد Python
WORKDIR /app
COPY app/backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# نسخ Backend
COPY app/backend/ ./backend/

# نسخ Frontend المبني
COPY --from=frontend-builder /app/build ./frontend/build

# إعداد Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# إعداد Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# المنافذ
EXPOSE 80

# نقطة البداية
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
