-- Apply this migration in Supabase SQL Editor if you already installed an earlier
-- version of Football-League-Manager's schema. It adds secure website-based role changes.
create or replace function public.admin_set_profile_role(p_user_id uuid,p_role text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  target public.profiles%rowtype;
  active_admins integer;
begin
  if not public.is_admin() then raise exception 'Admin permission required.'; end if;
  if p_role not in ('admin','user') then raise exception 'Invalid role.'; end if;
  select * into target from public.profiles where id=p_user_id for update;
  if not found then raise exception 'Account not found.'; end if;
  if target.status='deleted' then raise exception 'Archived accounts cannot change role.'; end if;
  if target.role='admin' and p_role='user' and target.status='active' then
    select count(*) into active_admins from public.profiles where role='admin' and status='active';
    if active_admins<=1 then raise exception 'At least one active Admin must remain.'; end if;
  end if;
  update public.profiles set role=p_role,updated_at=now() where id=p_user_id;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,reason,before_data,after_data)
  values(auth.uid(),'role_change','profile',p_user_id::text,'Role changed by Admin',jsonb_build_object('role',target.role),jsonb_build_object('role',p_role));
  insert into public.notifications(user_id,title,message,kind)
  values(p_user_id,'Account role updated','Your account role is now '||p_role||'.','account');
  return jsonb_build_object('ok',true,'role',p_role);
end $$;

grant execute on function public.admin_set_profile_role(uuid,text) to authenticated;
revoke all on function public.admin_set_profile_role(uuid,text) from public, anon;
