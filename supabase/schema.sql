-- =====================================================================
--  تطبيق احتياجات المنزل — مخطط قاعدة البيانات (Supabase / PostgreSQL)
--  النسخة 1 — يُنفَّذ كاملاً مرة واحدة في: Supabase → SQL Editor → Run
--  أي تعديل لاحق يُكتب كملف جديد في supabase/migrations/ ولا يُعدَّل هنا.
-- =====================================================================
--  المبادئ:
--   • البيت (household) هو وحدة الملكية؛ كل الجداول تحمل household_id.
--   • تغيير حالة البند يتم حصراً عبر دوال RPC (assign_item / claim_item /
--     close_item / cancel_item / reopen_item). التحديث المباشر للحالة مرفوض.
--   • الفاتورة/الإغلاق هو مصدر السعر؛ سجل الأسعار يُكتب بالمشغّلات فقط.
--   • المنفذ (executor) لا يرى الميزانية ولا سجل الأسعار (RLS).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1) الأنواع
-- ---------------------------------------------------------------------
create type public.member_role   as enum ('manager', 'partner', 'executor');
create type public.item_status   as enum ('new', 'assigned', 'bought', 'deferred', 'rejected', 'cancelled');
create type public.item_category as enum ('grocery', 'cleaning', 'maintenance', 'other');
create type public.reject_reason as enum ('unavailable', 'too_expensive', 'unclear', 'other');
create type public.cash_kind     as enum ('handover', 'expense', 'settlement');
create type public.price_source  as enum ('closure', 'receipt');

-- ---------------------------------------------------------------------
-- 2) الجداول
-- ---------------------------------------------------------------------

-- البيت
create table public.households (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  city           text not null,
  default_lang   text not null default 'ar',
  cash_tracking  boolean not null default true,   -- يُعطَّل في سيناريو الزوجين إن أرادوا
  created_at     timestamptz not null default now()
);

-- العضو (مستخدم واحد لكل بيت)
create table public.members (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  role          public.member_role not null,
  display_name  text not null,
  lang          text not null default 'ar',       -- ar | en | ur | hi | bn | tl
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  unique (household_id, user_id)
);
create index members_user_idx on public.members(user_id);
create index members_household_idx on public.members(household_id);

-- كود الدعوة (يحمل الدور مسبقاً)
create table public.invite_codes (
  code          text primary key,
  household_id  uuid not null references public.households(id) on delete cascade,
  role          public.member_role not null check (role <> 'manager'),
  created_by    uuid not null references public.members(id) on delete cascade,
  expires_at    timestamptz not null default now() + interval '7 days',
  used_by       uuid references public.members(id) on delete set null,
  used_at       timestamptz
);

-- الصنف (عام عندما household_id فارغ، أو خاص بالبيت)
create table public.catalog_items (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid references public.households(id) on delete cascade,
  name_ar       text not null,
  name_en       text,
  names         jsonb not null default '{}'::jsonb,   -- {"ur":"دودھ","hi":"दूध"}
  category      public.item_category not null default 'grocery',
  default_unit  text not null default 'pc',           -- pc | kg | g | L | ml | pack | carton | tray
  barcode       text,
  image_url     text,
  synonyms      text[] not null default '{}',
  created_at    timestamptz not null default now()
);
create index catalog_items_household_idx on public.catalog_items(household_id);
create index catalog_items_name_ar_idx on public.catalog_items(lower(name_ar));

-- الفاتورة
create table public.receipts (
  id               uuid primary key default gen_random_uuid(),
  household_id     uuid not null references public.households(id) on delete cascade,
  uploaded_by      uuid not null references public.members(id) on delete cascade,
  image_path       text not null,                    -- مسار الصورة في bucket "receipts": <household_id>/<file>
  store_name       text,
  receipt_date     date,
  total            numeric(10,2),
  extracted_lines  jsonb,                            -- المرحلة الثانية: الأصناف المستخرجة آلياً
  created_at       timestamptz not null default now()
);
create index receipts_household_idx on public.receipts(household_id);

-- البند (الطلب)
create table public.items (
  id               uuid primary key default gen_random_uuid(),
  household_id     uuid not null references public.households(id) on delete cascade,
  catalog_item_id  uuid references public.catalog_items(id) on delete set null,
  name             text not null,
  quantity         numeric(10,2) not null default 1 check (quantity > 0),
  unit             text not null default 'pc',
  category         public.item_category not null default 'grocery',
  image_url        text,
  note             text,
  requested_by     uuid references public.members(id) on delete set null,
  assigned_to      uuid references public.members(id) on delete set null,
  status           public.item_status not null default 'new',
  reject_reason    public.reject_reason,
  reason_text      text,
  deferred_until   date,
  expected_price   numeric(10,2),
  actual_price     numeric(10,2) check (actual_price is null or actual_price >= 0),
  receipt_id       uuid references public.receipts(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  closed_at        timestamptz,
  constraint bought_needs_price   check (status <> 'bought'   or actual_price is not null),
  constraint deferred_needs_date  check (status <> 'deferred' or deferred_until is not null),
  constraint rejected_needs_reason check (status <> 'rejected' or reject_reason is not null)
);
create index items_household_status_idx on public.items(household_id, status);
create index items_assigned_idx on public.items(assigned_to, status);
create index items_created_idx on public.items(household_id, created_at desc);

-- سجل الانتقالات (تاريخ البند)
create table public.item_transitions (
  id           bigint generated always as identity primary key,
  item_id      uuid not null references public.items(id) on delete cascade,
  from_status  public.item_status,
  to_status    public.item_status not null,
  by_member    uuid references public.members(id) on delete set null,
  at           timestamptz not null default now()
);
create index item_transitions_item_idx on public.item_transitions(item_id, at);

-- حركات الكاش (الرصيد يُحسب منها ولا يُخزَّن)
create table public.cash_movements (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households(id) on delete cascade,
  executor_id   uuid not null references public.members(id) on delete cascade,
  kind          public.cash_kind not null,
  amount        numeric(10,2) not null check (amount >= 0),
  item_id       uuid references public.items(id) on delete set null,
  receipt_id    uuid references public.receipts(id) on delete set null,
  note          text,
  by_member     uuid references public.members(id) on delete set null,
  at            timestamptz not null default now()
);
create index cash_movements_exec_idx on public.cash_movements(household_id, executor_id, at desc);

-- سجل الأسعار (يغذي السعر الاسترشادي)
create table public.price_records (
  id               bigint generated always as identity primary key,
  household_id     uuid not null references public.households(id) on delete cascade,
  catalog_item_id  uuid references public.catalog_items(id) on delete set null,
  item_name        text not null,
  price            numeric(10,2) not null check (price >= 0),
  quantity         numeric(10,2) not null default 1,
  unit             text not null default 'pc',
  city             text not null,
  store_name       text,
  source           public.price_source not null default 'closure',
  recorded_at      timestamptz not null default now()
);
create index price_records_household_name_idx on public.price_records(household_id, lower(item_name), recorded_at desc);
create index price_records_city_idx on public.price_records(catalog_item_id, city, recorded_at desc);

-- ---------------------------------------------------------------------
-- 3) دوال مساعدة للصلاحيات (security definer لتفادي تكرار RLS)
-- ---------------------------------------------------------------------
create or replace function public.current_member_id(h uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.members
  where household_id = h and user_id = auth.uid() and is_active
  limit 1;
$$;

create or replace function public.current_role_in(h uuid)
returns public.member_role language sql stable security definer set search_path = public as $$
  select role from public.members
  where household_id = h and user_id = auth.uid() and is_active
  limit 1;
$$;

create or replace function public.is_member(h uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.current_member_id(h) is not null;
$$;

-- مدير أو شريك
create or replace function public.is_staff(h uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.current_role_in(h) in ('manager', 'partner'), false);
$$;

create or replace function public.is_manager(h uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.current_role_in(h) = 'manager', false);
$$;

create or replace function public.my_household_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select household_id from public.members where user_id = auth.uid() and is_active;
$$;

-- المنفذ الوحيد النشط في البيت (أو null إن لم يكن واحداً بالضبط)
create or replace function public.sole_executor(h uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select case when count(*) = 1 then (array_agg(id))[1] end
  from public.members where household_id = h and role = 'executor' and is_active;
$$;

-- السعر المتوقع: متوسط آخر 3 أسعار للصنف في هذا البيت
create or replace function public.expected_price_for(h uuid, p_catalog uuid, p_name text)
returns numeric language sql stable security definer set search_path = public as $$
  select round(avg(price), 2) from (
    select price from public.price_records
    where household_id = h
      and ((p_catalog is not null and catalog_item_id = p_catalog)
           or lower(item_name) = lower(p_name))
    order by recorded_at desc
    limit 3
  ) t;
$$;

-- ---------------------------------------------------------------------
-- 4) المشغّلات
-- ---------------------------------------------------------------------

-- items: قبل الإدراج — الطالب، التكليف التلقائي للمنفذ الوحيد، السعر المتوقع
create or replace function public.items_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_exec uuid;
begin
  if new.requested_by is null then
    new.requested_by := public.current_member_id(new.household_id);
  end if;
  if new.assigned_to is null then
    v_exec := public.sole_executor(new.household_id);
    if v_exec is not null then
      new.assigned_to := v_exec;
      new.status := 'assigned';
    else
      new.status := 'new';
    end if;
  else
    new.status := 'assigned';
  end if;
  if new.expected_price is null then
    new.expected_price := public.expected_price_for(new.household_id, new.catalog_item_id, new.name);
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger items_before_insert before insert on public.items
  for each row execute function public.items_before_insert();

-- items: قبل التحديث — الحالة لا تتغير إلا عبر RPC؛ لا تعديل بعد الإغلاق
create or replace function public.items_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status
     and coalesce(current_setting('app.rpc', true), '') <> '1' then
    raise exception 'status_change_requires_rpc';
  end if;
  if old.status in ('bought', 'cancelled')
     and coalesce(current_setting('app.rpc', true), '') <> '1' then
    raise exception 'item_closed';
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger items_before_update before update on public.items
  for each row execute function public.items_before_update();

-- items: بعد الإدراج/التحديث — سجل الانتقال، ثم المصروف وسجل السعر عند الشراء
create or replace function public.items_after_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid;
  v_city  text;
  v_cash  boolean;
  v_role  public.member_role;
begin
  v_me := public.current_member_id(new.household_id);

  if tg_op = 'INSERT' then
    insert into public.item_transitions(item_id, from_status, to_status, by_member)
    values (new.id, null, new.status, v_me);
    return new;
  end if;

  if new.status is distinct from old.status then
    insert into public.item_transitions(item_id, from_status, to_status, by_member)
    values (new.id, old.status, new.status, v_me);

    if new.status = 'bought' then
      select city, cash_tracking into v_city, v_cash
      from public.households where id = new.household_id;

      insert into public.price_records
        (household_id, catalog_item_id, item_name, price, quantity, unit, city, store_name, source)
      select new.household_id, new.catalog_item_id, new.name, new.actual_price, new.quantity, new.unit,
             v_city, r.store_name, 'closure'
      from (select 1) x left join public.receipts r on r.id = new.receipt_id;

      select role into v_role from public.members where id = new.assigned_to;
      if v_cash and v_role = 'executor' then
        insert into public.cash_movements
          (household_id, executor_id, kind, amount, item_id, receipt_id, by_member)
        values (new.household_id, new.assigned_to, 'expense', new.actual_price, new.id, new.receipt_id, v_me);
      end if;
    end if;
  end if;
  return new;
end $$;
create trigger items_after_change after insert or update on public.items
  for each row execute function public.items_after_change();

-- members: الدور والبيت والمستخدم لا يغيّرها إلا المدير
create or replace function public.members_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role
      or new.household_id is distinct from old.household_id
      or new.user_id is distinct from old.user_id
      or new.is_active is distinct from old.is_active)
     and not public.is_manager(old.household_id) then
    raise exception 'only_manager_can_change_role';
  end if;
  return new;
end $$;
create trigger members_before_update before update on public.members
  for each row execute function public.members_before_update();

-- ---------------------------------------------------------------------
-- 5) دوال RPC (تُستدعى من التطبيق بـ supabase.rpc)
-- ---------------------------------------------------------------------

-- إنشاء بيت + عضوية المدير للمستخدم الحالي
create or replace function public.create_household(p_name text, p_city text, p_display_name text, p_lang text default 'ar')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_h uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into public.households(name, city, default_lang) values (p_name, p_city, p_lang) returning id into v_h;
  insert into public.members(household_id, user_id, role, display_name, lang)
  values (v_h, auth.uid(), 'manager', p_display_name, p_lang);
  return v_h;
end $$;

-- إصدار كود دعوة بدور محدد (المدير فقط)
create or replace function public.create_invite_code(p_household uuid, p_role public.member_role)
returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not public.is_manager(p_household) then raise exception 'not_allowed'; end if;
  if p_role = 'manager' then raise exception 'invalid_role'; end if;
  loop
    v_code := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;
  insert into public.invite_codes(code, household_id, role, created_by)
  values (v_code, p_household, p_role, public.current_member_id(p_household));
  return v_code;
end $$;

-- الانضمام بكود (المنفذ عبر تسجيل مجهول، الشريك عبر حسابه)
create or replace function public.join_with_code(p_code text, p_display_name text, p_lang text default 'ar')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_inv public.invite_codes%rowtype; v_member uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_inv from public.invite_codes where code = upper(trim(p_code)) for update;
  if not found then raise exception 'invalid_code'; end if;
  if v_inv.used_at is not null then raise exception 'code_used'; end if;
  if v_inv.expires_at < now() then raise exception 'code_expired'; end if;

  select id into v_member from public.members
  where household_id = v_inv.household_id and user_id = auth.uid();
  if v_member is null then
    insert into public.members(household_id, user_id, role, display_name, lang)
    values (v_inv.household_id, auth.uid(), v_inv.role, p_display_name, p_lang)
    returning id into v_member;
  end if;

  update public.invite_codes set used_by = v_member, used_at = now() where code = v_inv.code;
  return v_member;
end $$;

-- تكليف بند لعضو (مدير/شريك)
create or replace function public.assign_item(p_item uuid, p_member uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.items%rowtype;
begin
  select * into v from public.items where id = p_item for update;
  if not found then raise exception 'item_not_found'; end if;
  if not public.is_staff(v.household_id) then raise exception 'not_allowed'; end if;
  if v.status not in ('new', 'assigned', 'deferred') then raise exception 'bad_transition'; end if;
  if not exists (select 1 from public.members where id = p_member and household_id = v.household_id and is_active) then
    raise exception 'member_not_in_household';
  end if;
  perform set_config('app.rpc', '1', true);
  update public.items set assigned_to = p_member, status = 'assigned', deferred_until = null where id = p_item;
end $$;

-- الشريك يستلم بنداً جديداً لنفسه
create or replace function public.claim_item(p_item uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.items%rowtype; v_me uuid;
begin
  select * into v from public.items where id = p_item for update;
  if not found then raise exception 'item_not_found'; end if;
  if not public.is_staff(v.household_id) then raise exception 'not_allowed'; end if;
  if v.status <> 'new' then raise exception 'bad_transition'; end if;
  v_me := public.current_member_id(v.household_id);
  perform set_config('app.rpc', '1', true);
  update public.items set assigned_to = v_me, status = 'assigned' where id = p_item;
end $$;

-- إغلاق البند: تم الشراء / مؤجل / مرفوض (المكلَّف به، أو مدير/شريك)
create or replace function public.close_item(
  p_item uuid,
  p_status public.item_status,
  p_price numeric default null,
  p_receipt uuid default null,
  p_reason public.reject_reason default null,
  p_reason_text text default null,
  p_deferred_until date default null
) returns void language plpgsql security definer set search_path = public as $$
declare v public.items%rowtype; v_me uuid;
begin
  select * into v from public.items where id = p_item for update;
  if not found then raise exception 'item_not_found'; end if;
  v_me := public.current_member_id(v.household_id);
  if v_me is null then raise exception 'not_allowed'; end if;
  if v.assigned_to is distinct from v_me and not public.is_staff(v.household_id) then
    raise exception 'not_allowed';
  end if;
  if v.status <> 'assigned' then raise exception 'bad_transition'; end if;
  if p_receipt is not null and not exists (
       select 1 from public.receipts where id = p_receipt and household_id = v.household_id) then
    raise exception 'receipt_not_in_household';
  end if;

  perform set_config('app.rpc', '1', true);
  if p_status = 'bought' then
    if p_price is null then raise exception 'price_required'; end if;
    update public.items
      set status = 'bought', actual_price = p_price, receipt_id = p_receipt,
          closed_at = now(), reason_text = p_reason_text
      where id = p_item;
  elsif p_status = 'deferred' then
    if p_deferred_until is null then raise exception 'date_required'; end if;
    update public.items
      set status = 'deferred', deferred_until = p_deferred_until, reason_text = p_reason_text
      where id = p_item;
  elsif p_status = 'rejected' then
    if p_reason is null then raise exception 'reason_required'; end if;
    update public.items
      set status = 'rejected', reject_reason = p_reason, reason_text = p_reason_text, closed_at = now()
      where id = p_item;
  else
    raise exception 'bad_status';
  end if;
end $$;

-- إلغاء البند قبل الشراء (الطالب أو مدير/شريك)
create or replace function public.cancel_item(p_item uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.items%rowtype; v_me uuid;
begin
  select * into v from public.items where id = p_item for update;
  if not found then raise exception 'item_not_found'; end if;
  v_me := public.current_member_id(v.household_id);
  if v_me is null or (v.requested_by is distinct from v_me and not public.is_staff(v.household_id)) then
    raise exception 'not_allowed';
  end if;
  if v.status not in ('new', 'assigned', 'deferred') then raise exception 'bad_transition'; end if;
  perform set_config('app.rpc', '1', true);
  update public.items set status = 'cancelled', closed_at = now() where id = p_item;
end $$;

-- إعادة طلب بند مرفوض/ملغي بعد تعديله (مدير/شريك)
create or replace function public.reopen_item(p_item uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.items%rowtype; v_exec uuid;
begin
  select * into v from public.items where id = p_item for update;
  if not found then raise exception 'item_not_found'; end if;
  if not public.is_staff(v.household_id) then raise exception 'not_allowed'; end if;
  if v.status not in ('rejected', 'cancelled') then raise exception 'bad_transition'; end if;
  v_exec := public.sole_executor(v.household_id);
  perform set_config('app.rpc', '1', true);
  update public.items
    set status = case when v_exec is null then 'new'::public.item_status else 'assigned'::public.item_status end,
        assigned_to = v_exec, reject_reason = null, reason_text = null, closed_at = null
    where id = p_item;
end $$;

-- إعادة تفعيل المؤجل عند حلول موعده (يستدعيها التطبيق عند الفتح، أو pg_cron يومياً)
create or replace function public.reactivate_deferred()
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  perform set_config('app.rpc', '1', true);
  with u as (
    update public.items set status = 'assigned', deferred_until = null
    where status = 'deferred' and deferred_until <= current_date
      and (auth.uid() is null or household_id in (select public.my_household_ids()))
    returning 1
  ) select count(*) into n from u;
  return n;
end $$;

-- رصيد منفذ = تسليم − مصروف − تسوية
create or replace function public.executor_balance(p_household uuid, p_executor uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(case kind when 'handover' then amount else -amount end), 0)
  from public.cash_movements
  where household_id = p_household and executor_id = p_executor
    and (public.is_staff(p_household) or public.current_member_id(p_household) = p_executor);
$$;

-- ملخص شهري للبيت (مدير/شريك)
create or replace function public.monthly_summary(p_household uuid, p_year integer, p_month integer)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_from date := make_date(p_year, p_month, 1); v_to date := (make_date(p_year, p_month, 1) + interval '1 month')::date;
begin
  if not public.is_staff(p_household) then raise exception 'not_allowed'; end if;
  return jsonb_build_object(
    'total', (select coalesce(sum(actual_price), 0) from public.items
              where household_id = p_household and status = 'bought' and closed_at >= v_from and closed_at < v_to),
    'items_bought', (select count(*) from public.items
              where household_id = p_household and status = 'bought' and closed_at >= v_from and closed_at < v_to),
    'by_category', (select coalesce(jsonb_object_agg(category, total), '{}'::jsonb) from (
              select category, sum(actual_price) total from public.items
              where household_id = p_household and status = 'bought' and closed_at >= v_from and closed_at < v_to
              group by category) c),
    'top_items', (select coalesce(jsonb_agg(jsonb_build_object('name', name, 'total', total) order by total desc), '[]'::jsonb) from (
              select name, sum(actual_price) total from public.items
              where household_id = p_household and status = 'bought' and closed_at >= v_from and closed_at < v_to
              group by name order by total desc limit 10) t)
  );
end $$;

-- السعر الجماعي (المرحلة 3): وسيط سعر الصنف في المدينة خلال 30 يوماً، بحد أدنى 5 بيوت
create or replace function public.city_median_price(p_catalog uuid, p_city text)
returns numeric language sql stable security definer set search_path = public as $$
  select case when count(distinct household_id) >= 5
              then round(percentile_cont(0.5) within group (order by price)::numeric, 2) end
  from public.price_records
  where catalog_item_id = p_catalog and city = p_city
    and recorded_at >= now() - interval '30 days'
    and auth.uid() is not null;
$$;

-- ---------------------------------------------------------------------
-- 6) RLS
-- ---------------------------------------------------------------------
alter table public.households      enable row level security;
alter table public.members         enable row level security;
alter table public.invite_codes    enable row level security;
alter table public.catalog_items   enable row level security;
alter table public.receipts        enable row level security;
alter table public.items           enable row level security;
alter table public.item_transitions enable row level security;
alter table public.cash_movements  enable row level security;
alter table public.price_records   enable row level security;

-- households
create policy households_select on public.households for select to authenticated
  using (public.is_member(id));
create policy households_update on public.households for update to authenticated
  using (public.is_manager(id)) with check (public.is_manager(id));
create policy households_delete on public.households for delete to authenticated
  using (public.is_manager(id));

-- members
create policy members_select on public.members for select to authenticated
  using (household_id in (select public.my_household_ids()));
create policy members_update on public.members for update to authenticated
  using (public.is_manager(household_id) or user_id = auth.uid())
  with check (public.is_manager(household_id) or user_id = auth.uid());
create policy members_delete on public.members for delete to authenticated
  using (public.is_manager(household_id) and user_id <> auth.uid());

-- invite_codes (الإصدار عبر RPC؛ المدير يرى ويحذف)
create policy invite_codes_select on public.invite_codes for select to authenticated
  using (public.is_manager(household_id));
create policy invite_codes_delete on public.invite_codes for delete to authenticated
  using (public.is_manager(household_id));

-- catalog_items
create policy catalog_select on public.catalog_items for select to authenticated
  using (household_id is null or public.is_member(household_id));
create policy catalog_insert on public.catalog_items for insert to authenticated
  with check (household_id is not null and public.is_staff(household_id));
create policy catalog_update on public.catalog_items for update to authenticated
  using (household_id is not null and public.is_staff(household_id))
  with check (household_id is not null and public.is_staff(household_id));
create policy catalog_delete on public.catalog_items for delete to authenticated
  using (household_id is not null and public.is_staff(household_id));

-- receipts
create policy receipts_select on public.receipts for select to authenticated
  using (public.is_member(household_id));
create policy receipts_insert on public.receipts for insert to authenticated
  with check (public.is_member(household_id) and uploaded_by = public.current_member_id(household_id));
create policy receipts_update on public.receipts for update to authenticated
  using (public.is_staff(household_id)) with check (public.is_staff(household_id));

-- items (المنفذ يرى فقط؛ تغييراته عبر RPC)
create policy items_select on public.items for select to authenticated
  using (public.is_member(household_id));
create policy items_insert on public.items for insert to authenticated
  with check (public.is_staff(household_id));
create policy items_update on public.items for update to authenticated
  using (public.is_staff(household_id)) with check (public.is_staff(household_id));
create policy items_delete on public.items for delete to authenticated
  using (public.is_manager(household_id) and status in ('new', 'cancelled'));

-- item_transitions (القراءة فقط؛ الكتابة بالمشغّل)
create policy transitions_select on public.item_transitions for select to authenticated
  using (exists (select 1 from public.items i where i.id = item_id and public.is_member(i.household_id)));

-- cash_movements (المنفذ يرى حركاته فقط ويسجّل مصروفاً لنفسه فقط)
create policy cash_select on public.cash_movements for select to authenticated
  using (public.is_staff(household_id) or executor_id = public.current_member_id(household_id));
create policy cash_insert on public.cash_movements for insert to authenticated
  with check (
    (public.is_staff(household_id) and by_member = public.current_member_id(household_id))
    or (kind = 'expense' and executor_id = public.current_member_id(household_id)
        and by_member = public.current_member_id(household_id))
  );
create policy cash_update on public.cash_movements for update to authenticated
  using (public.is_manager(household_id)) with check (public.is_manager(household_id));
create policy cash_delete on public.cash_movements for delete to authenticated
  using (public.is_manager(household_id));

-- price_records (مدير/شريك يقرأ؛ الكتابة بالمشغّل)
create policy prices_select on public.price_records for select to authenticated
  using (public.is_staff(household_id));

-- ---------------------------------------------------------------------
-- 7) التخزين: صور الفواتير وصور البنود (المسار: <household_id>/<file>)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('item-images', 'item-images', false, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy storage_household_read on storage.objects for select to authenticated
  using (bucket_id in ('receipts', 'item-images')
         and public.is_member(((storage.foldername(name))[1])::uuid));
create policy storage_household_write on storage.objects for insert to authenticated
  with check (bucket_id in ('receipts', 'item-images')
              and public.is_member(((storage.foldername(name))[1])::uuid));

-- ---------------------------------------------------------------------
-- 8) البث المباشر (Realtime) للقائمة وحركات الكاش
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.items;
alter publication supabase_realtime add table public.cash_movements;

-- ---------------------------------------------------------------------
-- 9) جدولة إعادة تفعيل المؤجل (اختياري — بعد تفعيل pg_cron من Database → Extensions)
-- ---------------------------------------------------------------------
-- select cron.schedule('reactivate-deferred', '5 0 * * *', $$ select public.reactivate_deferred(); $$);

-- =====================================================================
-- انتهى. الخطوة التالية: تشغيل supabase/seed_catalog.sql لتحميل الكتالوج.
-- =====================================================================
