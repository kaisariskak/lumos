import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type DeleteAccountResponse = {
  ok: boolean;
  code?: string;
  appleRevoked?: boolean;
};

type DeleteAccountRpcResponse = {
  ok?: boolean;
  code?: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: DeleteAccountResponse) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

const statusForRpcCode = (code?: string) => {
  switch (code) {
    case 'no_session':
      return 401;
    case 'super_admin_forbidden':
      return 403;
    case 'group_ownership_blocked':
      return 409;
    default:
      return 500;
  }
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== 'POST') {
    return json(405, { ok: false, code: 'method_not_allowed' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('delete-account missing required Supabase env vars');
    return json(500, { ok: false, code: 'function_unavailable' });
  }

  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return json(401, { ok: false, code: 'no_session' });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: {
      headers: { Authorization: authorization },
    },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData.user;

  if (userError || !user) {
    return json(401, { ok: false, code: 'no_session' });
  }

  const userId = user.id;

  try {
    const { data, error: rpcError } = await adminClient.rpc('delete_account_data', {
      p_user_id: userId,
    });

    if (rpcError) {
      console.error('delete-account data cleanup RPC failed', rpcError);
      return json(500, { ok: false, code: 'delete_failed' });
    }

    const cleanup = data as DeleteAccountRpcResponse | null;
    if (!cleanup?.ok) {
      const code = cleanup?.code ?? 'delete_failed';
      return json(statusForRpcCode(code), { ok: false, code });
    }

    const { error: deleteUserError } =
      await adminClient.auth.admin.deleteUser(userId);

    if (deleteUserError) {
      console.error('delete-account auth user delete failed', deleteUserError);
      return json(500, { ok: false, code: 'delete_failed' });
    }

    return json(200, { ok: true, appleRevoked: false });
  } catch (error) {
    console.error('delete-account failed', error);
    return json(500, { ok: false, code: 'delete_failed' });
  }
});
