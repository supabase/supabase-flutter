-- Computed fields and computed relationships for the postgrest typed table
-- tests: functions whose only argument is a row of a relation. PostgREST
-- selects a scalar one like a column and embeds a row- or set-returning one
-- like a foreign table; none of them is part of `select=*`.

create function public.username_upper(public.users)
returns text as $$
  select upper($1.username);
$$ language sql stable;

create function public.message_count(public.users)
returns bigint as $$
  select count(*) from public.messages where username = $1.username;
$$ language sql stable;

-- A set-returning function is a to-many computed relationship.
create function public.channel_messages(public.channels)
returns setof public.messages as $$
  select * from public.messages where channel_id = $1.id;
$$ language sql stable;

-- ROWS 1 makes PostgREST embed the result as a single object.
create function public.latest_channel_message(public.channels)
returns setof public.messages rows 1 as $$
  select * from public.messages
  where channel_id = $1.id
  order by inserted_at desc
  limit 1;
$$ language sql stable;
