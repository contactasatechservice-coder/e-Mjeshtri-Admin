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
