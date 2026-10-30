import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = (path) => readFileSync(new URL('../' + path, import.meta.url), 'utf8');

test('all four role pages call the server-only role guard', () => {
  const roles = {
    'app/panel/qytetar/page.tsx': 'citizen',
    'app/panel/mjeshter/page.tsx': 'worker',
    'app/panel/kompani/page.tsx': 'company',
    'app/panel/admin/page.tsx': 'super_admin',
  };
  for (const [path, role] of Object.entries(roles)) {
    const page = source(path);
    assert.match(page, /import\s*\{\s*requireRole\s*\}\s*from/);
    assert.ok(page.includes("await requireRole(['" + role + "'])"), path);
  }
});

test('server role guard verifies auth user and reads roles from database', () => {
  const guard = source('lib/server/require-role.ts');
  assert.match(guard, /import 'server-only'/);
  assert.match(guard, /auth\.getUser\(\)/);
  assert.match(guard, /from\('user_roles'\)/);
  assert.match(guard, /allowedRoles\.includes/);
});

test('panel routes require a server auth gate', () => {
  const layout = source('app/panel/layout.tsx');
  const middleware = source('middleware.ts');
  assert.match(layout, /auth\.getUser\(\)/);
  assert.match(middleware, /auth\.getUser\(\)/);
  assert.match(middleware, /matcher:\s*\['\/panel\/:path\*'\]/);
});

test('role routing handles multi-role accounts and avoids trusting signup metadata', () => {
  const panel = source('app/panel/page.tsx');
  assert.match(panel, /from\('user_roles'\)/);
  assert.match(panel, /roles\.length === 1/);
  assert.match(panel, /roles\.map\(/);
  assert.doesNotMatch(panel, /user_metadata|app_metadata/);
});

test('no service role credentials are referenced by panel authorization', () => {
  for (const path of ['middleware.ts', 'app/panel/layout.tsx', 'app/panel/page.tsx', 'lib/server/require-role.ts']) {
    assert.doesNotMatch(source(path), /SUPABASE_SERVICE_ROLE_KEY|service_role/i, path);
  }
});
