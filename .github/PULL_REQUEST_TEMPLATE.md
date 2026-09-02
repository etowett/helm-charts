## What and why

<!-- One paragraph. What changes, and what problem it solves. Link the issue:
     "Closes #22" / "Refs #22". -->

## Charts touched

<!-- Delete the rows that don't apply. -->

| Chart | Old version | New version | Bump reason |
|-------|-------------|-------------|-------------|
| `app` |             |             |             |
| `cron` |            |             |             |

**No chart touched?** Say so and delete the table — the checklist below is then
only the last two boxes.

## The chart contract

A change to `templates/`, `values.yaml`, `values.schema.json` or `Chart.yaml`
ships inside the package, so it needs every box. A change to only `README.md`
or `examples/` needs none of them.

- [ ] `Chart.yaml` `version` bumped, and the bump matches the blast radius —
      **major** for a removed/renamed values key, a changed default that alters
      a running workload, or a raised `kubeVersion` floor.
- [ ] `CHANGELOG.md` entry for exactly that version, Keep a Changelog format,
      leading with **Changed (breaking)** if users must edit their values.
- [ ] `values.schema.json` updated for every new or changed key.
- [ ] `@param` comment in `values.yaml` **and** the matching row in the chart
      README's parameter table.
- [ ] At least one `examples/*.yaml` exercises the new behaviour.

## Verification

<!-- Paste the actual output, not a claim that it passed. -->

- [ ] `make check` — helm lint + render every chart with every example
- [ ] `make validate` — kubeconform against every supported Kubernetes version
- [ ] `make doctor` — tool-version lockstep and agent-config mirrors
- [ ] `make test-hooks` — only if `.claude/hooks/` changed

```
$ make check && make validate

```

## Anything reviewers should know

<!-- Deviations, follow-ups you deliberately left out, decisions you'd like a
     second opinion on. Delete if there are none. -->
