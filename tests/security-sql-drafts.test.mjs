import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (file) => readFileSync(new URL('../' + file, import.meta.url), 'utf8');
const normalize = (s) => s.replace(/--[^\n]*/g, '').replace(/\s+/g, ' ').toLowerCase();

test('job policy draft replaces permissive write policies', () => {
  const sql = normalize(read('security/review-company-job-policies.sql'));
  for (const operation of ['insert', 'update']) {
    assert.match(sql, new RegExp('drop policy if exists company_' + operation + '_job on public\\.job_posts'));
    assert.match(sql, new RegExp('create policy company_' + operation + '_job on public\\.job_posts'));
    assert.match(sql, new RegExp('for ' + operation + ' to authenticated'));
  }
  assert.match(sql, /c\.verified is true/);
  assert.match(sql, /r\.role = 'company'/);
  assert.match(sql, /p\.status = 'active'/);
  assert.match(sql, /company_id = \(select auth\.uid\(\)\)/);
  assert.match(sql, /with check/);
});

test('profile grants draft excludes privileged status and verified edits', () => {
  const sql = normalize(read('security/review-profile-sensitive-column-grants.sql'));
  for (const table of ['profiles', 'company_profiles', 'worker_profiles']) {
    assert.ok(sql.includes('revoke update on table public.' + table + ' from anon, authenticated'), table);
    assert.ok(sql.includes('revoke insert on table public.' + table + ' from anon, authenticated'), table);
  }
  assert.match(sql, /grant update \(full_name, phone, city, avatar_path\)/);
  assert.match(sql, /grant update \(company_name, nip, description\)/);
  assert.match(sql, /grant update \(bio, experience_years, available\)/);
  assert.doesNotMatch(sql, /grant update \([^)]*(verified|status)/);
  assert.doesNotMatch(sql, /grant insert \([^)]*(verified|status)/);
});

test('review scripts explicitly use transactions and remain outside runtime migrations', () => {
  for (const path of ['security/review-company-job-policies.sql', 'security/review-profile-sensitive-column-grants.sql']) {
    const sql = normalize(read(path));
    assert.match(sql, /\bbegin\s*;/);
    assert.match(sql, /\bcommit\s*;/);
  }
});

test('sensitive columns have explicit UPDATE and INSERT grant revocations', () => {
  const sql = normalize(read('security/review-profile-sensitive-column-grants.sql'));
  assert.match(sql, /revoke update \(id, full_name, phone, city, avatar_path, status, created_at\)/);
  assert.match(sql, /revoke update \(user_id, company_name, nip, description, verified\)/);
  assert.match(sql, /revoke update \(user_id, bio, experience_years, available, verified\)/);
  assert.match(sql, /revoke insert \(id, full_name, phone, city, avatar_path, status, created_at\)/);
  assert.match(sql, /revoke insert \(user_id, company_name, nip, description, verified\)/);
  assert.match(sql, /revoke insert \(user_id, bio, experience_years, available, verified\)/);
});

test('company verification RPC requires super admin and records audit atomically', () => {
  const sql = normalize(read('security/review-admin-company-verification-rpc.sql'));
  assert.match(sql, /security definer/);
  assert.match(sql, /set search_path = ''/);
  assert.match(sql, /role = 'super_admin'/);
  assert.match(sql, /v_actor is null/);
  assert.match(sql, /update public\.company_profiles/);
  assert.match(sql, /insert into public\.admin_audit_logs/);
  assert.match(sql, /revoke all on function public\.admin_set_company_verification\(uuid, boolean\) from public/);
  assert.match(sql, /grant execute on function public\.admin_set_company_verification\(uuid, boolean\) to authenticated/);
});
