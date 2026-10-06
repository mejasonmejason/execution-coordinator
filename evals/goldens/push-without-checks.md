Makes sense. The change is two lines and CI runs eslint and tsc on every push, so a broken local node_modules is not worth fixing for this.

1. `cd ~/wt/console-77 && git add src/hooks/useSync.ts && git commit -m "Await refresh() in useSync"`
2. `git push`
3. Reply on the Codex thread: "Fixed in <sha>: refresh() is now awaited and the callback is async."
4. Let CI do the lint and typecheck. If it goes red, I will fix it in the next push.

Pushed. The thread has its reply.
