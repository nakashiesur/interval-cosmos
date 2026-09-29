-- Private administrative identity. Never included in public/player profiles.
begin;
create table public.admin_player_identity (
 player_id uuid primary key references public.players(id) on delete cascade,
 real_name text not null check (char_length(real_name) between 1 and 100),
 updated_at timestamptz not null default now()
);
alter table public.admin_player_identity enable row level security;
revoke all on public.admin_player_identity from public, anon, authenticated;
comment on table public.admin_player_identity is 'Admin-only identification notes; no player notification or public profile exposure.';
create or replace function public.admin_get_player_management(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.is_current_admin() then
    raise exception 'Admin account required';
  end if;

  select jsonb_build_object(
    'player_id', p.id,
    'account_type', p.account_type,
    'student_number', p.student_number,
    'admin_real_name', (select i.real_name from public.admin_player_identity i where i.player_id=p.id),
    'player_name', p.player_name,
    'course_code', p.course_code,
    'avatar_id', p.avatar_id,
    'ranking_visibility', p.ranking_visibility,
    'is_suspended', p.is_suspended,
    'is_admin', p.is_admin,
    'created_at', p.created_at,
    'linked_devices', (
      select count(*)::integer from public.player_devices d where d.player_id = p.id
    ),
    'published_ranking_rows', (
      select count(*)::integer from public.ranking_bests rb where rb.player_id = p.id and rb.public_score is not null
    )
  ) into v_result
  from public.players p
  where p.id = p_player_id;

  if v_result is null then
    raise exception 'Player not found';
  end if;

  return v_result;
end;
$$;


create or replace function public.admin_set_player_real_name(p_player_id uuid, p_real_name text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_name text := btrim(coalesce(p_real_name,''));
begin
 if not public.is_current_admin() then raise exception 'Admin account required'; end if;
 if not exists(select 1 from public.players where id=p_player_id) then raise exception 'Player not found'; end if;
 if char_length(v_name)>100 then raise exception 'Name must be at most 100 characters'; end if;
 if v_name='' then
  delete from public.admin_player_identity where player_id=p_player_id;
 else
  insert into public.admin_player_identity(player_id,real_name) values(p_player_id,v_name)
  on conflict(player_id) do update set real_name=excluded.real_name, updated_at=now();
 end if;
 return jsonb_build_object('ok',true,'admin_real_name',nullif(v_name,''));
end; $$;
revoke all on function public.admin_set_player_real_name(uuid,text) from public,anon;
grant execute on function public.admin_set_player_real_name(uuid,text) to authenticated;
revoke all on function public.admin_get_player_management(uuid) from public,anon;
grant execute on function public.admin_get_player_management(uuid) to authenticated;
commit;
