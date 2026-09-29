# ═══════════════════════════════════════════════════════════════════
# CP2 — Dockerfile production-ready (multi-stage, non-root)
#
# Stage 1 `builder`: cài dependency vào /install (stage này bị vứt bỏ sau)
# Stage 2 `runtime`: chỉ copy KẾT QUẢ từ builder + source code → image nhỏ
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder ────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

# Copy RIÊNG requirements.txt trước: layer này chỉ invalidates khi dependency
# đổi → sửa code không phải cài lại thư viện (Docker cache theo layer)
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Chỉ mang site-packages đã cài sang, không mang theo toolchain của builder
COPY --from=builder /install /usr/local

# Source code copy SAU khi cài dependency để tận dụng cache
COPY app ./app
COPY utils ./utils

# Chạy bằng user thường: container bị thoát khỏi cũng không thành root trên host
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Cloud (Railway/Render/Cloud Run) tự gán PORT — không cố định 8000
ENV PORT=8000 \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# Docker tự hỏi thăm /health; không 2xx → container bị đánh dấu unhealthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.environ.get('PORT', '8000'), timeout=3).read()" || exit 1

# Bind 0.0.0.0 (không phải 127.0.0.1) và đọc cổng từ ${PORT:-8000}
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
