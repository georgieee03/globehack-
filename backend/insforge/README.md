## InsForge Backend

This backend is now managed through the linked InsForge project in the repo root `.insforge/` directory.

### Common commands

- `pnpm --filter @hydrascan/backend insforge:current`
- `pnpm --filter @hydrascan/backend insforge:metadata`
- `pnpm --filter @hydrascan/backend db:tables`
- `pnpm --filter @hydrascan/backend db:query -- \"select now();\"`

### Import migrations

InsForge imports one SQL file at a time. From the repo root, run the migration files in name order:

```powershell
Get-ChildItem backend\insforge\migrations\*.sql |
  Sort-Object Name |
  ForEach-Object { cmd /c npx @insforge/cli db import $_.FullName }
```

Then import seed data as needed:

```powershell
cmd /c npx @insforge/cli db import backend\insforge\seed\seed.sql
cmd /c npx @insforge/cli db import backend\insforge\seed\demo-personas.sql
```

### Required backend environment

- `INSFORGE_URL`
- `INSFORGE_ANON_KEY`
- `INSFORGE_SERVICE_TOKEN`
- `HYDRAWAV_API_BASE_URL`

`INSFORGE_ANON_KEY` is required for local verification scripts and authenticated test flows.

`INSFORGE_SERVICE_TOKEN` should be set to a project-scoped backend token for server-side function execution. Do not commit it to the repo.
