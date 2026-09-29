# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Phùng Thành An |
| Mã học viên | 2A202603006 |
| Repo | https://github.com/Mashall-Anie/K4-L3B-DAY12-PhungThanhAn-2A202603006-CloudServicesAndDeployment |


## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://agent-production-79db.up.railway.app |
| Platform | Railway (Docker deploy từ Dockerfile, Redis add-on trong cùng project) |
| Ngày deploy | 2026-09-29 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
|| `PORT` | ✅ | Railway tự gán, app đọc từ env và bind 0.0.0.0 |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard Variables, không nằm trong repo |
| `REDIS_URL` | ✅ | reference tới Redis add-on cùng project (Add Reference → Redis → connectionString) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
URL=https://agent-production-79db.up.railway.app

# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i $URL/health

# 2. Readiness — mong đợi 200 {"status":"ready","redis":true} (đã nối được Redis)
curl -i $URL/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST $URL/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```
$ curl -i $URL/health
HTTP/2 200
content-type: application/json
server: railway-hikari

{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i $URL/ready
HTTP/2 200
content-type: application/json
server: railway-hikari

{"status":"ready","redis":true}

$ curl -i -X POST $URL/ask -H "Content-Type: application/json" -d '{"question":"Hello"}'
HTTP/2 401
content-type: application/json
server: railway-hikari

{"detail":"invalid or missing API key"}
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl


---

## Nếu Dùng Phương Án Dự Phòng
Không sử dụng phương án dự phòng — service đã deploy thành công lên Railway
với địa chỉ công khai HTTPS ở bảng Service phía trên.

