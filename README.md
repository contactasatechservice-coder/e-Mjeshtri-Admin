# e-Mjeshtri Web

Responsive Next.js web rebuild (mobile + desktop). Roles: Qytetar, Mjeshtër, Kompani, Super Admin (server provisioned only).

## Setup

1. `npm install`
2. Copy `.env.example` to `.env.local` and set the Supabase publishable/anon key.
3. `npm run dev`
4. `npm run build`

**Security:** never expose the Supabase service role key. Public registration allows only citizen, worker, company. Admin provisioning must be server-side. Role panels are placeholders; database RLS enforces access. Configure Supabase Auth redirect URLs for the deployment domain.

**Deployment:** This branch is a new Next.js app. Vercel project settings must use Next.js and have the environment variables configured. Do not deploy this branch as production before validation.
