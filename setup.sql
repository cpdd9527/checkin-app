-- ============================================
-- 打卡搭子 · Supabase 建表脚本
-- 使用方法：Supabase Dashboard → SQL Editor → 粘贴全部执行
-- ============================================

-- 1. 用户资料表
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  account text unique not null,
  nickname text not null,
  secret_q text not null,
  secret_a_hash text not null,
  secret_salt text not null,
  role text not null default 'user',   -- 'admin' / 'user'，仅首个注册者为 admin，界面不显示
  created_at timestamptz default now()
);

-- 2. 打卡项目表（每个用户自己的项目）
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  emoji text default '✅',
  sort int default 0,
  created_at timestamptz default now(),
  unique(user_id, name)
);

-- 3. 打卡记录表
create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  date text not null,          -- YYYY-MM-DD
  note text default '',
  meta jsonb default '{}'::jsonb,  -- 锻炼: {type:"推日"} 学习: {subject, duration}
  created_at timestamptz default now()
);

-- 4. RLS：全部开启，用户只能碰自己的数据
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.checkins enable row level security;

drop policy if exists "profiles_own" on public.profiles;
create policy "profiles_own" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "projects_own" on public.projects;
create policy "projects_own" on public.projects
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "checkins_own" on public.checkins;
create policy "checkins_own" on public.checkins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 5. 注册函数：写入资料，第一个注册者自动成为管理员
create or replace function public.register_profile(
  p_account text, p_nickname text, p_q text, p_a_hash text, p_salt text
) returns void
language plpgsql security definer as $$
begin
  if not exists (select 1 from public.profiles) then
    insert into public.profiles(id, account, nickname, secret_q, secret_a_hash, secret_salt, role)
    values (auth.uid(), p_account, p_nickname, p_q, p_a_hash, p_salt, 'admin');
  else
    insert into public.profiles(id, account, nickname, secret_q, secret_a_hash, secret_salt, role)
    values (auth.uid(), p_account, p_nickname, p_q, p_a_hash, p_salt, 'user');
  end if;
end $$;

grant execute on function public.register_profile(text,text,text,text,text) to authenticated;

-- 6. 索引
create index if not exists checkins_user_date on public.checkins(user_id, date);
create index if not exists checkins_proj on public.checkins(project_id);
