-- Resets and re-seeds the auth tables the gotrue test suite depends on.
-- Ported from the former infra/gotrue/db/00-schema.sql. Lives in the public
-- schema so it is reachable via PostgREST at /rest/v1/rpc/reset_and_init_auth_data.
-- check_function_bodies is disabled because the function references auth tables
-- whose row shape is owned by the gotrue migrations.
set check_function_bodies to false;

create or replace function public.reset_and_init_auth_data()
returns void language sql security definer as $$
-- WHERE clauses are required because the Data API session enables pg_safeupdate.
delete from auth.users where true;
delete from auth.mfa_amr_claims where true;
delete from auth.mfa_challenges where true;
delete from auth.mfa_factors where true;
delete from auth.sessions where true;
delete from auth.refresh_tokens where true;

insert into auth.users (
    instance_id,
    id,
    email,
    aud,
    role,
    encrypted_password,
    email_confirmed_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    phone,
    phone_confirmed_at
)
values
    (
        '00000000-0000-0000-0000-000000000000',
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        'fake1@email.com',
        'authenticated',
        'authenticated',
        '$2a$10$fOz84O1J.eztX.VzugMBteSCiLv4GnrzZJgoC4aJMvMPqCI.15vR2',
        now(),
        now(),
        '{"provider": "email", "providers": ["email"]}',
        '{}',
        now(),
        now(),
        '',
        '',
        '',
        '',
        '166600000000',
        now()
    ),
    (
        '00000000-0000-0000-0000-000000000000',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        'fake2@email.com',
        'authenticated',
        'authenticated',
        '$2a$10$fOz84O1J.eztX.VzugMBteSCiLv4GnrzZJgoC4aJMvMPqCI.15vR2',
        now(),
        now(),
        '{"provider": "email", "providers": ["email"]}',
        '{}',
        now(),
        now(),
        '',
        '',
        '',
        '',
        null,
        null
    );

insert into auth.identities (
    id,
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
values (
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        '{"sub": "18bc7a4e-c095-4573-93dc-e0be29bada97", "email": "fake1@email.com"}',
        'email',
        now(),
        now(),
        now()
    ),
    (
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        '{"sub": "28bc7a4e-c095-4573-93dc-e0be29bada97", "email": "fake2@email.com"}',
        'email',
        now(),
        now(),
        now()
    );

insert into auth.mfa_factors (
    id,
    user_id,
    friendly_name,
    factor_type,
    status,
    created_at,
    updated_at,
    secret
)
values (
        '1d3aa138-da96-4aea-8217-af07daa6b82d',
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        'UnverifiedFactor',
        'totp',
        'unverified',
        now(),
        now(),
        'R7K3TR4HN5XBOCDWHGGUGI2YYGQSCLUS'
    ),
    (
        '2d3aa138-da96-4aea-8217-af07daa6b82d',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        'VerifiedFactor',
        'totp',
        'verified',
        now(),
        now(),
        'R7K3TR4HN5XBOCDWHGGUGI2YYGQSCLUS'
    );

insert into auth.mfa_challenges (id, factor_id, created_at, ip_address)
values (
        'b824ca10-cc13-4250-adba-20ee6e5e7dcd',
        '1d3aa138-da96-4aea-8217-af07daa6b82d',
        now(),
        coalesce(
            (
                split_part(
                    current_setting('request.headers', true)::json->>'x-forwarded-for',
                    ',',
                    1
                )
            )::inet,
            '192.168.96.1'::inet
        )
    );

insert into auth.sessions (
    id,
    user_id,
    created_at,
    updated_at,
    factor_id,
    aal
)
values (
        'c2297abc-e22a-4bc8-ab79-b939b09556d9',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        now(),
        now(),
        '2d3aa138-da96-4aea-8217-af07daa6b82d',
        'aal2'
    );

insert into auth.mfa_amr_claims (
    session_id,
    created_at,
    updated_at,
    authentication_method,
    id
)
values(
        'c2297abc-e22a-4bc8-ab79-b939b09556d9',
        now(),
        now(),
        'totp',
        'c12fa6c6-dc60-43fa-ac09-1413d77c2bd6'
    );
$$;

grant execute on function public.reset_and_init_auth_data() to anon, authenticated, service_role;
