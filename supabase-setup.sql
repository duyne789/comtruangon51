-- ============================================================
-- Cơm Trưa Ngon — Supabase setup (chạy trong SQL Editor)
-- ============================================================

-- 1) Bảng xếp hạng (top quán)
create table if not exists leaderboard (
  id uuid primary key default gen_random_uuid(),
  player_name text not null check (char_length(trim(player_name)) between 1 and 24),
  shop_name text not null check (char_length(trim(shop_name)) between 1 and 32),
  score int not null check (score >= 0),
  day_reached int not null default 1 check (day_reached >= 1),
  rating numeric(3,2) not null default 4.0,
  difficulty text not null default 'de' check (difficulty in ('de','binh','kho','sieu')),
  money int default 0,
  created_at timestamptz not null default now()
);

create index if not exists leaderboard_score_idx on leaderboard (score desc, created_at asc);

-- 2) Lượt truy cập theo ngày (CHỈ xem trong Supabase Dashboard — game không hiện)
create table if not exists daily_visits (
  day date primary key default (current_date),
  visits int not null default 0 check (visits >= 0)
);

-- 3) Log visit thô (tuỳ chọn, phân tích sau)
create table if not exists visit_log (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  day date not null default (current_date),
  shop_name text,
  difficulty text
);

-- 4) Hàm đếm visit (security definer — client không ghi trực tiếp daily_visits)
create or replace function bump_daily_visit(p_shop text default null, p_diff text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into daily_visits(day, visits) values (current_date, 1)
  on conflict (day) do update set visits = daily_visits.visits + 1;

  insert into visit_log(shop_name, difficulty)
  values (nullif(trim(p_shop), ''), nullif(trim(p_diff), ''));
end;
$$;

-- 5) Nộp điểm: chỉ insert, chống spam tên rỗng / điểm âm (check ở table)
--    Client chỉ được INSERT, không UPDATE/DELETE

-- 6) RLS
alter table leaderboard enable row level security;
alter table daily_visits enable row level security;
alter table visit_log enable row level security;

-- Xóa policy cũ nếu chạy lại script
drop policy if exists "lb_select" on leaderboard;
drop policy if exists "lb_insert" on leaderboard;
drop policy if exists "dv_select" on daily_visits;
drop policy if exists "vl_insert" on visit_log;

-- Leaderboard: ai cũng đọc (top 50 limit ở client), ai cũng insert 1 dòng
create policy "lb_select" on leaderboard for select to anon, authenticated using (true);
create policy "lb_insert" on leaderboard for insert to anon, authenticated
  with check (
    char_length(trim(player_name)) between 1 and 24
    and char_length(trim(shop_name)) between 1 and 32
    and score >= 0 and score <= 100000000
    and day_reached >= 1 and day_reached <= 9999
  );
-- Không cho UPDATE / DELETE từ anon

-- daily_visits: KHÔNG cho client đọc (chỉ Dashboard / service role)
-- không tạo policy select cho anon → anon không đọc được
-- không cho insert trực tiếp

-- visit_log: không đọc từ client
create policy "vl_insert" on visit_log for insert to anon, authenticated with check (true);
-- không policy select → client không đọc log

revoke all on table daily_visits from anon, authenticated;
grant select, insert on table leaderboard to anon, authenticated;
grant insert on table visit_log to anon, authenticated;
grant usage, select on sequence visit_log_id_seq to anon, authenticated;

grant execute on function bump_daily_visit(text, text) to anon, authenticated;

-- Xem lượt truy cập trong Dashboard:
--   Table Editor → daily_visits
-- hoặc: select * from daily_visits order by day desc;


-- Cho phép cập nhật điểm (để BXH không trùng khi điểm cao hơn)
drop policy if exists "lb_update" on leaderboard;
create policy "lb_update" on leaderboard for update to anon, authenticated using (true) with check (true);


-- CLOUD SAVE
create table if not exists game_saves (
  save_code text primary key,
  shop_name text,
  data jsonb not null,
  updated_at timestamptz default now()
);
create index if not exists game_saves_updated on game_saves(updated_at desc);
alter table game_saves enable row level security;
drop policy if exists "gs_select" on game_saves;
drop policy if exists "gs_insert" on game_saves;
drop policy if exists "gs_update" on game_saves;
create policy "gs_select" on game_saves for select to anon, authenticated using (true);
create policy "gs_insert" on game_saves for insert to anon, authenticated
  with check (char_length(save_code) between 8 and 20 and data is not null);
create policy "gs_update" on game_saves for update to anon, authenticated
  using (true) with check (char_length(save_code) between 8 and 20 and data is not null);


-- ============================================================
-- Nếu bảng đã tạo trước đó, chạy thêm để sửa constraint difficulty:
-- ============================================================
do $$
declare r record;
begin
  for r in (
    select c.conname
    from pg_constraint c
    join pg_class t on c.conrelid=t.oid
    where t.relname='leaderboard' and c.contype='c' and pg_get_constraintdef(c.oid) ilike '%difficulty%'
  ) loop
    execute 'alter table leaderboard drop constraint '||quote_ident(r.conname);
  end loop;
  alter table leaderboard add constraint leaderboard_difficulty_check
    check (difficulty in ('de','binh','kho','sieu'));
exception when others then
  raise notice 'constraint update: %', SQLERRM;
end $$;


-- ============================================================
-- Avatar + Logo thương hiệu trên BXH (chạy thêm nếu bảng đã có)
-- ============================================================
alter table leaderboard add column if not exists avatar text;
alter table leaderboard add column if not exists logo_emoji text;
alter table leaderboard add column if not exists logo_data text;



-- ============================================================
-- CHAT TỔNG (không cần đăng nhập — anon đọc/ghi)
-- ============================================================
create table if not exists public_chat (
  id bigint generated always as identity primary key,
  nick text not null check (char_length(nick) between 1 and 16),
  message text not null check (char_length(message) between 1 and 120),
  created_at timestamptz default now()
);
create index if not exists public_chat_created_idx on public_chat (created_at desc);

alter table public_chat enable row level security;

drop policy if exists "public_chat_select" on public_chat;
create policy "public_chat_select" on public_chat for select using (true);

drop policy if exists "public_chat_insert" on public_chat;
create policy "public_chat_insert" on public_chat for insert with check (
  char_length(nick) between 1 and 16
  and char_length(message) between 1 and 120
);

-- Không cho sửa/xóa từ client (chỉ insert + select)



-- ============================================================
-- BXH Bầu Cua (minigame)
-- ============================================================
create table if not exists bau_leaderboard (
  nick text primary key,
  shop_name text,
  net int default 0,
  won int default 0,
  played int default 0,
  updated_at timestamptz default now()
);
alter table bau_leaderboard enable row level security;
create policy bau_lb_select on bau_leaderboard for select using (true);
create policy bau_lb_insert on bau_leaderboard for insert with check (true);
create policy bau_lb_update on bau_leaderboard for update using (true);



-- ============================================================
-- 7) BXH khu Giải trí (Tài xỉu + Nổ hũ + Bầu cua) — mọi người thấy
-- ============================================================
create table if not exists casino_leaderboard (
  shop_key text primary key,
  shop_name text not null default '',
  net numeric not null default 0,
  tx_net numeric not null default 0,
  bau_net numeric not null default 0,
  wagered numeric not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists casino_lb_net_idx on casino_leaderboard (net desc, updated_at asc);

alter table casino_leaderboard enable row level security;

drop policy if exists "cas_lb_select" on casino_leaderboard;
drop policy if exists "cas_lb_insert" on casino_leaderboard;
drop policy if exists "cas_lb_update" on casino_leaderboard;

create policy "cas_lb_select" on casino_leaderboard for select to anon, authenticated using (true);
create policy "cas_lb_insert" on casino_leaderboard for insert to anon, authenticated
  with check (char_length(trim(shop_key)) between 1 and 40);
create policy "cas_lb_update" on casino_leaderboard for update to anon, authenticated
  using (true) with check (true);
