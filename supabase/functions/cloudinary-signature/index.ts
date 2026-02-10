// @ts-nocheck
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function toHex(buffer: ArrayBuffer) {
  return [...new Uint8Array(buffer)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function sha1(value: string) {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-1', encoded);
  return toHex(digest);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const cloudinaryApiKey = Deno.env.get('CLOUDINARY_API_KEY');
  const cloudinaryApiSecret = Deno.env.get('CLOUDINARY_API_SECRET');

  if (!cloudinaryApiKey || !cloudinaryApiSecret) {
    return new Response(JSON.stringify({ error: 'Missing Cloudinary secrets in Supabase function config.' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');

  if (!authHeader || !supabaseUrl || !supabaseAnonKey) {
    return new Response(JSON.stringify({ error: 'Unauthorized request.' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const body = await req.json().catch(() => ({}));
  const timestamp = Number(body.timestamp) || Math.floor(Date.now() / 1000);
  const folder = typeof body.folder === 'string' && body.folder.trim() ? body.folder.trim() : 'wedahub/projects';

  const paramsToSign = `folder=${folder}&timestamp=${timestamp}`;
  const signature = await sha1(`${paramsToSign}${cloudinaryApiSecret}`);

  return new Response(
    JSON.stringify({
      timestamp,
      folder,
      apiKey: cloudinaryApiKey,
      signature,
    }),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  );
});
