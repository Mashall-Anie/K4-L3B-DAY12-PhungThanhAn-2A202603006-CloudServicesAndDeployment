# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Họ và tên: Phùng Thành An  Mã học viên: 2A202603006

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống mình gặp thật khi deploy lên Railway: lần deploy đầu tiên service
chưa có biến `AGENT_API_KEY` nên container chết ngay lúc khởi động với
`ValidationError` (app fail fast), Railway báo "Deploy crashed". Nếu khóa có
mặc định `"changeme"` thì deployment đó sẽ hiện "Success" — service chạy ngon
với một khóa mà ai đọc source (repo công khai) cũng biết. Vì repo để public,
bất kỳ ai cũng có thể dùng khóa mặc định đó gọi `/ask` thoải mái, còn mình tin
rằng service đang an toàn. Việc chết sớm buộc mình phải vào dashboard set
đúng secret trước khi service chạy — sai lầm bị phát hiện ở phút đầu thay vì
sau khi hóa đơn/token bị ai đó tiêu hộ. Rút ra: secret không bao giờ được có
giá trị mặc định, và lỗi cấu hình nên nổ lúc khởi động chứ không phải im lặng
chạy sai.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log thật thu được khi gọi `/ask` (chạy uvicorn trên máy, user sv01):

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T02:46:00.324537+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
```

Hai việc làm được mà `print("đã trả lời xong")` không làm được:

1. **Lọc và tổng hợp bằng máy:** vì mỗi dòng là một JSON hợp lệ nên mình có
   thể `grep '"event": "ask_completed"'` rồi lấy `user_id`, cộng dồn
   `cost_usd` để biết từng user đã tiêu bao nhiêu tiền, đếm số request theo
   ngày. Chuỗi "đã trả lời xong" không có cấu trúc — không lọc theo user, hòa
   không tổng hợp được chi phí.
2. **Đối chiếu thời gian và đưa vào hệ thống log của cloud:** trường
   `timestamp` ISO-8601 + UTC cho phép so sánh chính xác giữa các service,
   còn Railway/Datadog gom log theo từng dòng — một event một dòng JSON nghĩa
   là một log entry đúng, kèm đủ metadata (tokens_in/out, cost) để cảnh báo
   khi chi phí tăng bất thường. Với `print`, log lên cloud chỉ là một câu
   chữ vô nghĩa trôi trong log stream.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ... MB |
| Multi-stage | 268 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần chênh lệch chính là: (1) base image — bản 1 stage dùng `python:3.11`
đầy đủ (~1 GB) vốn kèm cả compiler, header, công cụ build hệ thống, còn
bản multi-stage dùng `python:3.11-slim` chỉ chưa tới 200 MB; (2) tầng
`pip install` — khi cài thẳng vào image, pip có thể kéo theo các wheel và
công cụ chỉ cần lúc cài, trong khi bản multi-stage cài dependency ở stage
`builder` rồi chỉ `COPY --from=builder /install /usr/local` đúng kết quả là
site-packages. Tức là mọi thứ chỉ cần cho việc *build* đều bị vứt lại ở
stage builder, image cuối chỉ chứa thứ cần để *chạy*. Image nhỏ hơn nghĩa là
push/pull lên cloud nhanh hơn (lần deploy Railway của mình image nén chỉ
~61,5 MB), khởi động nhanh hơn và bề mặt tấn công (số package dư thừa) nhỏ hơn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Quan sát thật khi build lại sau khi code thay đổi: các layer `FROM
python:3.11-slim`, `WORKDIR /app`, `COPY requirements.txt .` và đặc biệt là
`RUN pip install ...` đều hiện **CACHED** — vì nội dung của chúng không đổi
(requirements.txt không đổi). Chỉ hai layer `COPY app ./app` và
`COPY utils ./utils` chạy lại (code mới), còn `RUN useradd` vẫn cache được vì
nó đứng sau nhưng không phụ thuộc nội dung code. Lần build sau của mình hết
sự kiện ~2,6 giây thay vì ~70 giây như lần đầu. Nếu đặt `COPY . .` trước
`RUN pip install`: `COPY . .` đổi mỗi khi bất kỳ file nào trong repo đổi →
layer đó invalidate → mọi layer đứng sau cũng bị invalidate theo chuỗi, trong
đó có `pip install` → mỗi lần sửa một dấu phẩy là cài lại toàn bộ thư viện.
Đó là lý do quy tắc "copy ít thay đổi trước, copy hay thay đổi sau" quyết định
tốc độ build hằng ngày.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện: lỗ hổng trong code Python (ví dụ RCE qua input độc hại) →
attacker chạy được lệnh bên trong container với đúng quyền của process — mà
process đang là **root** → với quyền root trong container, attacker có thể
cài thêm công cụ (apt/pip), đọc mọi file và secret môi trường trong container,
ghi vào volume được mount, quét mạng nội bộ, và nếu cấu hình mount lỏng lẻo
hoặc kernel có lỗ hổng escape thì leo tiếp ra máy host — vì UID 0 trong
container trùng UID 0 trên host. Lệnh `USER appuser` (mình dùng uid 10001)
cắt đứt chuỗi ngay tại bước "chạy lệnh với quyền cao": process chỉ còn là
một user thường — không cài được package hệ thống, không đọc được file ngoài
phạm vi cho phép, ngay cả thoát khỏi app cũng chỉ là một user vô danh.
Mình đã kiểm chứng bằng `docker compose exec agent whoami` → `appuser`.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa **20 request trong 2 giây**. Cách đạt: gửi 10 request vào lúc
10:00:59 — đúng sát cuối "phút 10:00", dùng hết quota của phút đó; rồi gửi
tiếp 10 request vào lúc 10:01:01 — đồng hồ đã nhảy sang phút mới, bộ đếm bị
reset về 0 nên lại có nguyên 10 quota mới. Như vậy 20 request dồn vào 2 giây
mà hệ thống vẫn thấy "đúng luật 10 request/phút". Đếm theo phút đồng hồ có
biên giới reset nên爆发 burst ngay biên. Sliding window 60 giây của mình
không có biên giới: tại 10:01:01, cửa sổ là [10:00:01 → 10:01:01], cả 10
request lúc 10:00:59 vẫn còn nằm trong cửa sổ nên request thứ 11 bị trả 429
— đúng hành vi mình quan sát khi gọi 12 lần liên tiếp: `200` × 10 rồi
`429` × 2.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Khác nhau về **đơn vị giới hạn**: rate limit chặn theo *số request trong khoảng
thời gian ngắn* (10 request/60 giây, chống spam/giữ tải), còn cost guard chặn
theo *số tiền tích lũy trong tháng* (10 USD/user/tháng, chống cháy hóa đơn).

- Rate limit cho qua nhưng cost guard chặn: user gửi đúng 3 request/phút
  (thưa hơn hạn mức 10/phút) nhưng mỗi request là prompt ~2000 ký tự đắt tiền.
  Về tần suất hoàn toàn hợp lệ, nhưng sau vài nghìn lượt như vậy chi phí tích
  lũy trong tháng chạm ngưỡng 10 USD → `guard.check` trả 402 Payment Required.
- Cost guard cho qua nhưng rate limit chặn: user lặp 15 request "test" liên
  tiếp trong vài giây, mỗi request chỉ tốn ~0,00002 USD — cả tháng cũng
  không tới ngân sách, nhưng đã vượt 10 request trong cửa sổ 60 giây →
  request thứ 11 nhận 429 kèm `Retry-After`. Đúng như vòng lặp 15 lần mình
  chạy: các mã cuối là 429 dù chi phí mỗi request gần như bằng 0.

Hai lớp này phải đi cùng nhau vì mỗi lớp chặn một kiểu lạm dụng mà lớp kia
không thấy.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Theo đúng thứ tự: (1) Redis mất kết nối 30 giây; (2) cả 3 container agent đều
thất bại khi kiểm tra Redis trong endpoint gộp → trả 503; (3) orchestrator
(Docker/Kubernetes) thấy liveness probe 503 trên cả 3 container → kết luận
process chết → tiến hành **restart cả 3 container**; (4) trong lúc restart,
không container nào phục vụ → user nhận lỗi 502/503 dù app hoàn toàn khỏe;
(5) Redis trở lại sau 30 giây nhưng service thì vừa bị restart oan, đang
cold-start lại, các request đang xử lý dở bị cắt. Nghĩa là một cú hiccup của
dependency gây sập toàn bộ cụm. Khi tách đúng: Redis chết → `/health` vẫn 200
(process sống, không restart gì cả), chỉ `/ready` trả 503 → load balancer chỉ
việc ngừng đẩy traffic mới vào trong 30 giây đó, service tự hồi phục khi Redis
quay lại. Liveness trả lời "có cần restart container này không?", readiness
trả lời "có nên gửi request vào đây bây giờ không?" — hai câu hỏi khác nhau
thì phải là hai endpoint khác nhau.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Kết quả thật khi mình scale 3 container và gọi xen kẽ qua 3 cổng 8000/8001/8002
với cùng `X-User-Id: sv-scale`: `history_length` lần lượt là **0, 2, 4, 6, 8,
10** — tăng đều sau mỗi lượt, bất kể request rơi vào container nào, vì cả 3
container cùng đọc/ghi một Redis chung. Nếu lịch sử nằm trong dict Python
trong RAM từng process: mỗi container có RAM riêng → mỗi instance giữ một
bản lịch sử riêng của chính nó → khi request lượn qua 3 instance, số sẽ lặp
lại và nhảy loạn (kiểu 0, 0, 2, 0, 4, 2...), agent "mất trí nhớ" mỗi khi
request rơi vào instance khác hoặc instance restart. Đó chính là minh chứng
thực nghiệm vì sao state phải đưa ra khỏi process (stateless) trước khi
scale ngang.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Lỗi gặp: chạy `railway init` và `railway up` đều bị từ chối với thông báo
`Free plan resource provision limit exceeded. Please upgrade to provision more
resources!` — nghe như hết tài nguyên, trong khi tài khoản trial còn credit.
Cách tìm nguyên nhân: mình so sánh từng lệnh — `railway add --database redis`
thì **thành công** nhưng mọi lệnh deploy **code** đều bị chặn, rồi tra tài liệu
thì ra trial của Railway có 2 loại: Full Trial (deploy được code + database)
và Limited Trial (chỉ deploy được database) — tài khoản chưa được verify nên
bị loại sau, thông báo lỗi gây hiểu lầm. Cách xử lý: kết nối GitHub vào
Account Settings để Railway verify tài khoản, sau đó tạo service bằng tay
trong dashboard và `railway up` vào đúng service đó thì deploy thành công.
Bài học: một thông báo lỗi trên cloud có thể nói hoàn toàn khác bản chất vấn
đề — phải cô lập được lệnh nào chạy được/lệnh nào bị chặn rồi mới kết luận
được nguyên nhân thật.
