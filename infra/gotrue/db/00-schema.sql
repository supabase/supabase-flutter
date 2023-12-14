CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION postgres;
GRANT ALL PRIVILEGES ON SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO postgres;
ALTER USER postgres
SET search_path = "auth";


BEGIN;
-- Tables have not been created yet
SET LOCAL check_function_bodies TO FALSE;

create OR REPLACE function auth.reset_and_init_auth_data() returns void language sql security definer as $$
DELETE FROM auth.users;
DELETE FROM auth.mfa_amr_claims;
DELETE FROM auth.mfa_challenges;
DELETE FROM auth.mfa_factors;
DELETE FROM auth.sessions;
DELETE FROM auth.refresh_tokens;


INSERT INTO auth.users (
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
VALUES -- For unverified factors
    (
        '00000000-0000-0000-0000-000000000000',
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        'fake1@email.com',
        '',
        '',
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
    -- For verified factors
    (
        '00000000-0000-0000-0000-000000000000',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        'fake2@email.com',
        '',
        '',
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


INSERT INTO auth.identities (
        id,
        provider_id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
    )
VALUES (
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        'google',
        '18bc7a4e-c095-4573-93dc-e0be29bada97',
        '{"sub": "18bc7a4e-c095-4573-93dc-e0be29bada97", "email": "fake1@email.com"}',
        'email',
        now(),
        now(),
        now()
    ),
    (
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        'apple',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        '{"sub": "28bc7a4e-c095-4573-93dc-e0be29bada97", "email": "fake2@email.com"}',
        'email',
        now(),
        now(),
        now()
    );


INSERT INTO auth.mfa_factors (
        id,
        user_id,
        friendly_name,
        factor_type,
        status,
        created_at,
        updated_at,
        secret
    )
VALUES (
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


INSERT INTO auth.mfa_challenges (id, factor_id, created_at, ip_address)
VALUES (
        'b824ca10-cc13-4250-adba-20ee6e5e7dcd',
        '1d3aa138-da96-4aea-8217-af07daa6b82d',
        now(),
        COALESCE(
            (
                SPLIT_PART(
                    current_setting('request.headers', true)::json->>'x-forwarded-for',
                    ',',
                    1
                )
            )::inet,
            '192.168.96.1'::inet
        )
    );


INSERT INTO auth.sessions (
        id,
        user_id,
        created_at,
        updated_at,
        factor_id,
        aal
    )
VALUES (
        'c2297abc-e22a-4bc8-ab79-b939b09556d9',
        '28bc7a4e-c095-4573-93dc-e0be29bada97',
        now(),
        now(),
        '2d3aa138-da96-4aea-8217-af07daa6b82d',
        'aal2'
    );


INSERT INTO auth.mfa_amr_claims (
        session_id,
        created_at,
        updated_at,
        authentication_method,
        id
    )
VALUES(
        'c2297abc-e22a-4bc8-ab79-b939b09556d9',
        now(),
        now(),
        'totp',
        'c12fa6c6-dc60-43fa-ac09-1413d77c2bd6'
    );
$$;
COMMIT;