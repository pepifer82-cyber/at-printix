alter table public.control_renewal_requests
  add column if not exists read_at timestamptz,
  add column if not exists read_by uuid references auth.users(id) on delete set null;

-- Las solicitudes que ya avanzaron del estado inicial se consideran leídas,
-- para no convertir pedidos antiguos ya atendidos en avisos nuevos.
update public.control_renewal_requests
set read_at = coalesce(read_at, updated_at, submitted_at),
    read_by = coalesce(read_by, handled_by)
where status <> 'received' and read_at is null;

create or replace function public.control_admin_list_renewal_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public', 'auth'
as $function$
declare
  v_rows jsonb;
begin
  if auth.uid() is null or not public.control_is_global_admin() then
    raise exception 'Acceso exclusivo del administrador maestro.';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.submitted_at desc),'[]'::jsonb)
    into v_rows
  from (
    select r.id,r.company_id,c.company_code,c.name as company_name,c.email as company_email,
      c.phone as company_phone,r.user_id,r.request_type,r.requested_plan_id,r.requested_plan_name,
      r.requested_amount,r.currency,r.billing_cycle,r.payment_method,
      r.contact_email,r.contact_phone,r.message,r.status,r.admin_note,
      r.submitted_at,r.updated_at,r.read_at,r.read_by
    from public.control_renewal_requests r
    join public.control_companies c on c.id=r.company_id
    order by r.submitted_at desc
    limit 300
  ) x;

  return jsonb_build_object('requests',v_rows);
end;
$function$;

create or replace function public.control_admin_mark_renewal_request_read(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth'
as $function$
declare
  v_row public.control_renewal_requests%rowtype;
  v_changed boolean := false;
begin
  if auth.uid() is null or not public.control_is_global_admin() then
    raise exception 'Acceso exclusivo del administrador maestro.';
  end if;

  select * into v_row
  from public.control_renewal_requests
  where id = p_request_id
  for update;

  if v_row.id is null then
    raise exception 'Solicitud no encontrada.';
  end if;

  if v_row.read_at is null then
    update public.control_renewal_requests
      set read_at = now(),
          read_by = auth.uid(),
          updated_at = now()
    where id = p_request_id
    returning * into v_row;

    v_changed := true;

    insert into public.control_company_audit_log(company_id,user_id,action,target_type,target_id,metadata)
    values(v_row.company_id,auth.uid(),'renewal_request_marked_read','renewal_request',v_row.id::text,
      jsonb_build_object('status',v_row.status,'read_at',v_row.read_at));
  end if;

  return jsonb_build_object(
    'ok',true,
    'id',v_row.id,
    'read_at',v_row.read_at,
    'already_read',not v_changed
  );
end;
$function$;

revoke all on function public.control_admin_mark_renewal_request_read(uuid) from public;
revoke all on function public.control_admin_mark_renewal_request_read(uuid) from anon;
grant execute on function public.control_admin_mark_renewal_request_read(uuid) to authenticated;
