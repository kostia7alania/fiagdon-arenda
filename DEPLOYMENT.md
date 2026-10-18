# Production deployment

Production: https://fiagdon-arenda.ru/ on FirstByte Moscow.

Every push to `main` starts `.github/workflows/deploy.yml`. GitHub Actions uses a
dedicated SSH key and a pinned server host key. Its server-side SSH command is
restricted to `deploy <commit SHA>`; it cannot open a shell or forward ports.

The unprivileged `fiagdon-deploy` account fetches this public repository. Only
the current tip of `main` can be deployed. The server exports the static files,
checks local resources and sitemap XML, then atomically switches
`/srv/fiagdon-arenda/current` to the new release. Earlier releases remain in
`/srv/fiagdon-arenda/releases`. Caddy serves the files and renews HTTPS certificates.

Repository variables: `PRODUCTION_HOST`, `PRODUCTION_USER`.
Repository secrets: `PRODUCTION_SSH_KEY`, `PRODUCTION_KNOWN_HOSTS`.
Credentials are never committed. No build system or third-party deployment action
is required. Server administrative access is separate from the Actions key.

Verification: `https://fiagdon-arenda.ru/.well-known/deploy.json` identifies the
active commit. The Actions log reports the same SHA. A failed export or static
check leaves the previous release active.

For a manual redeploy, use **Actions → Deploy production → Run workflow** on
`main`. To roll back, an administrator can atomically switch `current` to a
previous release; the next successful push to `main` replaces that rollback.

Server deployment helpers under `/usr/local/lib/fiagdon-arenda` are installed by
an administrator from `ops/deploy.sh` and `ops/ssh-command.sh`. Changes to those
helpers require updating the installed copies. The site validator is read from
the commit being deployed. The site route is `/etc/caddy/sites-enabled/fiagdon-arenda.caddy`.
