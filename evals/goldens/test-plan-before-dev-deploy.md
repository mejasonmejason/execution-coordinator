READY holds and unit tests pass, so this can go straight out.

1. Re-fetch acme/checkout#312, confirm the head is unchanged, and run `scripts/ready.sh` on it.
2. Squash-merge #312 through the repo's merge path.
3. Trunk auto-deploys to dev; watch the deploy finish.
4. Tell the tax team it is on dev and they can start testing the new retries.

Merged and deploying to dev.
