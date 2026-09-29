# Cơm Trưa Ngon

Game quản lý quán cơm trưa (web PWA) – phong cách Tiệm Mì Cay.

## Chạy game

### Trên máy tính
Mở `index.html` bằng Chrome / Edge / Firefox.

### Trên điện thoại (khuyến nghị)
1. Upload cả thư mục lên hosting miễn phí (Netlify Drop, GitHub Pages…)
2. Hoặc server local cùng WiFi: `npx serve .`
3. Mở URL trên điện thoại → **Thêm vào màn hình chính** để cài như app.

**Lưu ý:** PWA cần mở qua http/https (không phải file://).

## Đã nâng cấp

- Illustration SVG quán cơm đẹp, có trang trí động
- Tab Trang trí: mua chậu cây, đèn lồng, dây đèn, bảng menu, thảm, quạt
- PWA: manifest + icon 192/512 + apple-touch-icon
- Cân bằng giá / XP / số khách
- Âm thanh nhẹ (nút 🔊) + animation CSS
- Lưu tiến trình localStorage (key v2)

- Nhạc nền chill: 5 bài lofi + 2 bài sôi động nhẹ, tự tổng hợp bằng Web Audio (trống, bass, hợp âm Rhodes, reverb, tiếng đĩa than). Nút 🎵 / ⏭ ở đầu quán, chỉnh âm lượng trong Cài đặt.
- Tab 🏛 Thuế: thuế phát sinh mỗi cuối ngày theo doanh thu (2% → 6.5% theo cấp quán), chốt kỳ mỗi 7 ngày, hạn nộp +3 ngày. Đúng hạn +20 XP, 3 kỳ liền giảm 20% thuế suất; trễ bị phạt 1.5%/ngày, trễ 3 ngày bị thanh tra (phạt 15%, cưỡng chế thu từ két, trừ 0.15★).

## Supabase (BXH + lượt truy cập)

1. Tạo project tại https://supabase.com
2. SQL Editor → dán & Run file `supabase-setup.sql`
3. Settings → API → copy **Project URL** và **anon public** key
4. Mở `index.html` → sửa 2 dòng:
   ```js
   const SB_URL = 'https://xxxx.supabase.co';
   const SB_ANON = 'eyJ...';
   ```
5. Host game (GitHub Pages / Netlify / bất kỳ static host)

- **BXH**: tab 🏆 BXH (top 50) + nút Đăng BXH cuối ngày
- **Lượt truy cập**: chỉ xem trong Supabase → Table `daily_visits` (game **không** hiện số này)

**Bảo mật:** RLS bật; client chỉ INSERT leaderboard + gọi `bump_daily_visit`; **không** đọc được `daily_visits` từ game.
