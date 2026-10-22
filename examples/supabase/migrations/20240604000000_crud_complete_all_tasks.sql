-- A database function for the "database CRUD with PostgREST" example, so it can
-- show a typed RPC call generated from the schema.
--
-- Marks every open task complete, or only those of one project when
-- `target_project_id` is given, and returns how many tasks it changed.

create function public.complete_all_tasks(target_project_id uuid default null)
returns integer
language sql
as $$
  with completed as (
    update public.tasks
    set is_complete = true
    where not is_complete
      and (target_project_id is null or project_id = target_project_id)
    returning 1
  )
  select count(*)::integer from completed;
$$;
