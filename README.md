# personal-website

My personal site, plus a place to host lots of small experiments on one GCP project.

Every folder in `projects/` is one experiment, deployed as its own
[Cloud Run](https://cloud.google.com/run) service. Services scale to zero, so
an experiment nobody is using costs almost nothing. `projects/www` is the
homepage. It lists every other project automatically.

```
projects/
  www/        the homepage (static), served at the root domain
  hello/      an example experiment: one HTML file
templates/    starting points for `make new`: static, node, python
runtime/      the shared nginx image every static project is served with
scripts/      deploy / scaffold / list helpers (the Makefile calls these)
infra/        Terraform for the one-time GCP setup
config.env    project ID, region and domain, read by everything above
```

## Adding an experiment

```sh
make new p=my-idea              # static HTML/CSS/JS
make new p=my-api t=node        # Node.js server
make new p=my-model t=python    # Flask server

make dev p=my-idea              # run it on http://localhost:8080
make deploy p=my-idea           # ship it
```

You can also push to `main`: CI deploys every project whose folder changed,
then redeploys the homepage so its list is current.

A project needs only a `project.json` (and code). There are two kinds:

- **`"type": "static"`**: plain files served by nginx. No Dockerfile needed.
- **`"type": "service"`**: anything that listens on `$PORT`. If the folder has
  a `Dockerfile` it's used. Otherwise
  [Google Cloud buildpacks](https://cloud.google.com/docs/buildpacks/overview)
  detect the language (Node, Python, Go, Java, Ruby, PHP, .NET).

### `project.json`

```jsonc
{
  "name": "My idea",                 // shown on the homepage
  "description": "What it does.",    // shown on the homepage
  "type": "static",                  // "static" or "service" (default "service")
  "tags": ["three.js"],              // shown on the homepage
  "source": "https://github.com/…", // optional "source" link on the homepage
  "hidden": false,                   // true = deploy it but leave it off the homepage

  // static projects with a build step, e.g. a Vite app:
  "build": "npm ci && npm run build",
  "output": "dist",                  // folder to serve (default ".")

  // Cloud Run settings (defaults in config.env):
  "memory": "512Mi",
  "cpu": 1,
  "maxInstances": 2,
  "minInstances": 0,
  "public": true,                    // false = require IAM auth to call it

  "env": { "MODE": "demo" },
  "secrets": { "ANTHROPIC_API_KEY": "anthropic-api-key:latest" }  // Secret Manager name:version
}
```

The slug is the folder name. It becomes the Cloud Run service name and the
subdomain, so it must be lowercase letters, digits and hyphens.

To take an experiment down: `make destroy p=my-idea`, then delete the folder.

## One-time setup

You need [`gcloud`](https://cloud.google.com/sdk/docs/install),
[`terraform`](https://developer.hashicorp.com/terraform/install) and `jq`.

1. **Create a GCP project** with billing enabled. Put its ID and your preferred
   region in `config.env`.

2. **Log in:**

   ```sh
   make login
   gcloud auth application-default login   # for Terraform
   ```

3. **Create the infrastructure:**

   ```sh
   cp infra/terraform.tfvars.example infra/terraform.tfvars   # fill it in
   make infra
   ```

   This enables the APIs and creates a runtime service account for the
   experiments. It also creates an Artifact Registry repo whose cleanup policy
   deletes old images. If `github_repo` is set, it creates keyless GitHub
   Actions access (Workload Identity Federation). If `domain` is set, it also
   creates the load balancer (see below).

4. **Deploy everything:** `make deploy-all`. Then `make list` shows the URLs.

5. **Turn on CI (optional):** copy the `github_actions_variables` output from
   step 3 into the repo's *Settings → Secrets and variables → Actions →
   Variables*. Pushes to `main` then deploy automatically. Until those
   variables exist, the workflow skips itself.

### Using your own domain

Without a domain, each project gets a `https://<slug>-<number>.<region>.run.app`
URL. That's fine for experimenting.

With a domain, set `domain` in `infra/terraform.tfvars` and `DOMAIN` in
`config.env`, then run `make infra`. You get:

| URL                       | Serves                    |
| ------------------------- | ------------------------- |
| `https://example.com`     | `www`                     |
| `https://<slug>.example.com` | the `<slug>` service   |

This is one global HTTPS load balancer with a wildcard certificate. Its
serverless backend uses a URL mask (`<service>.example.com`), so **new
experiments get their subdomain as soon as they're deployed**. You never touch
Terraform again.

Add the records from the `dns_records` output at your DNS provider. Set
`dns_managed_zone` instead if the domain is in Cloud DNS, and they're created
for you. The certificate is issued once the records resolve, which usually
takes 10 to 60 minutes.

> The load balancer costs roughly $18/month whether or not anything is used.
> Cloud Run itself stays at or near the free tier for idle experiments.

## Troubleshooting

- **`--allow-unauthenticated` fails with a policy error.** Your organization
  enforces *Domain restricted sharing* (`iam.allowedPolicyMemberDomains`),
  which blocks `allUsers`. Override it for this project, or use a project
  outside the organization.
- **Source build fails with a permission error.** `make infra` grants the
  Compute Engine default service account `roles/run.builder`, which source
  deploys need. Make sure it has run, and that this service account exists in
  the project.
