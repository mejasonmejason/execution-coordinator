I will do these one at a time in the main checkout so nothing collides:

1. First the eslint v9 bump in packages/lint-config. I will fix the breakage, open a PR and wait for it to merge.
2. Once that is merged, I will pull main and add GET /healthz to services/api, then open a second PR.
3. After that lands, I will fix the dark mode toggle in apps/dashboard/src/Theme.tsx for #301.

Doing them sequentially on one branch keeps it simple. I will report back when all three are merged.
