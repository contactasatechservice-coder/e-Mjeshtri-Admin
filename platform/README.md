# e-Mjeshtri 2.0 platform

Next.js responsive scaffold. No paid services are activated. Existing root admin deployment remains untouched.

## Local development

Run `npm install` then `npm run dev` inside `platform/`.

## Status

Landing page and informational routes only. Authentication, real job posts, offers, chat, subscriptions, RLS and payments are NOT implemented. Do not deploy as a live marketplace yet.

## Vercel

Create a separate Vercel project with Root Directory `platform` for preview, without changing the existing root Vercel deployment. Configure Supabase only after reviewing security policies.
