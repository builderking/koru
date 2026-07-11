# Koru Cloudflare Pages publishing plan

Status: **plan only — no Cloudflare project has been created and nothing has been deployed**
Repository: builderking/koru
Website source: website/
Hosting target: Cloudflare Pages with GitHub integration

## Locked deployment decisions

| Setting | Value |
| --- | --- |
| Cloudflare Pages project name | koru |
| GitHub owner | builderking |
| GitHub repository | koru |
| Production branch | main |
| Repository root directory | website |
| Dependency installation | Cloudflare automatic install from package-lock.json; local and CI verification use npm ci |
| Build command | npm run build |
| Build output directory | dist |
| Framework | Astro, static output |
| Preview deployments | All branches and pull requests originating in the repository |
| Pull request comments | Enabled |
| Cloudflare Functions | None for launch |
| Runtime adapter | None for launch |
| Production publish trigger | Successful Pages build from main |
| Initial hostname | Cloudflare-assigned koru.pages.dev, subject to availability |
| Custom domain | Not selected; separate approval later |

The website will pin Node through website/.node-version and commit package-lock.json. Local and repository CI must run npm ci before npm run build. Cloudflare Pages performs its own automatic dependency-install step from website/ before running npm run build, and the first deployment must verify that the resolved dependency tree matches package-lock.json.

Cloudflare's Astro guide uses npm run build and dist for Astro projects, and its build-image documentation describes automatic dependency installation and .node-version support: [Deploy an Astro site](https://developers.cloudflare.com/pages/framework-guides/deploy-an-astro-site/), [Build image](https://developers.cloudflare.com/pages/configuration/build-image/).

## Why Git integration

Git integration matches the repository workflow:

- pushes to main can produce production deployments;
- non-production branches can receive unique preview deployments;
- pull requests from the same repository can receive preview URLs and status feedback;
- Cloudflare retains successful production deployments for rollback;
- the deployment state remains tied to a Git commit.

References:

- [Cloudflare Pages Git integration](https://developers.cloudflare.com/pages/configuration/git-integration/)
- [Get started with Git integration](https://developers.cloudflare.com/pages/get-started/git-integration/)
- [Preview deployments](https://developers.cloudflare.com/pages/configuration/preview-deployments/)
- [Branch deployment controls](https://developers.cloudflare.com/pages/configuration/branch-build-controls/)
- [Rollbacks](https://developers.cloudflare.com/pages/configuration/rollbacks/)

Important platform constraints:

- a Git-integrated Pages project cannot later be converted into a Direct Upload project; automatic Git builds can be disabled and Wrangler used, but the project type does not switch;
- pull requests from forks do not receive the same automatic preview behavior as branches and pull requests originating in the connected repository;
- preview deployments are publicly accessible by default unless protected with Cloudflare Access;
- the assigned pages.dev project subdomain cannot be renamed; a different name requires deleting and recreating the project;
- preview deployments are not valid rollback targets;
- any successfully built production deployment can be a rollback target.

These constraints are why the project name, repository connection, and production branch must be confirmed before the creation call.

## Website architecture for Pages

The launch site is static Astro:

- no server-side rendering;
- no Pages Functions;
- no KV, D1, R2, Workers AI, secrets, or environment bindings;
- no Astro Cloudflare adapter;
- no server runtime dependency;
- no third-party analytics script by default.

This keeps the output portable. The contents of website/dist can be served by any static host if Pages becomes unsuitable.

Recommended repository files:

    website/
      .node-version
      astro.config.mjs
      package.json
      package-lock.json
      public/
        _headers
        robots.txt
      src/
      dist/                 # generated locally, not committed

The Astro build should use the default static output. Astro documents static deployment as the default and reserves adapters for on-demand rendering: [Astro deployment guide](https://docs.astro.build/en/guides/deploy/) and [on-demand rendering](https://docs.astro.build/en/guides/on-demand-rendering/).

## Local preflight before any Cloudflare write

Run these from a clean checkout, not from an uncommitted working state:

    cd website
    npm ci
    npm run build

Verify:

- the command exits successfully;
- website/dist/index.html exists;
- every local route requested by the landing site has a generated HTML response;
- asset paths work under a production-like static server;
- there are no credentials, account identifiers, source maps containing private paths, or unpublished user content in dist;
- the page works without a server function;
- canonical and social metadata use the approved production URL or a controlled placeholder;
- privacy, security, license, GitHub, and release links resolve;
- the generated site passes accessibility and responsive review;
- dependencies and Node version match the committed lockfile and .node-version.

Do not create a Pages project to discover ordinary local build errors.

## Cloudflare MCP execution protocol

Future Cloudflare work must use the connected Cloudflare MCP tools in this order:

1. **docs**
2. **search**
3. **execute, read-only**
4. resolve GitHub repository identifiers
5. present the final configuration and mutation for explicit approval
6. **execute, write**, only after approval
7. **execute, read-only verification**

This sequence prevents an old API assumption or guessed identifier from turning into a remote resource.

### Step 1: current documentation lookup

Use the Cloudflare docs tool to retrieve current guidance for:

- Pages GitHub integration and GitHub App repository access;
- Astro static build settings;
- preview deployment behavior and pull request limitations;
- branch build controls;
- project naming and pages.dev subdomain behavior;
- custom domains, if one is later approved;
- rollback behavior;
- current build-image Node selection.

The docs call should happen in the same execution session as deployment planning because platform behavior can change.

### Step 2: exact API schema lookup

Use the Cloudflare search tool against the current OpenAPI specification to confirm:

- POST /accounts/{account_id}/pages/projects
- GET /accounts/{account_id}/pages/projects
- GET /accounts/{account_id}/pages/projects/{project_name}
- GET /accounts/{account_id}/pages/projects/{project_name}/deployments
- the current rollback endpoint if an API rollback is proposed;
- request fields for build_config and source.config;
- required Pages permissions for the connected token.

Search must precede execute. Do not infer endpoint shape from an old script or from dashboard labels.

The current create endpoint is documented at [Create project](https://developers.cloudflare.com/api/resources/pages/subresources/projects/methods/create/). At the time of this plan it requires name and production_branch, and accepts build_config and source objects.

### Step 3: read-only Cloudflare preflight

Use execute only for a GET that:

- identifies the connected account without printing credentials;
- lists existing Pages projects;
- checks whether a project named koru already exists;
- records its configuration if it does exist.

Conceptual MCP execute call:

    async () => cloudflare.request({
      method: "GET",
      path: "/accounts/ACCOUNT_ID/pages/projects",
      query: { per_page: 100 }
    })

Abort creation if:

- koru already exists;
- the connected account is not the intended BuilderKing account;
- Pages Write authority is missing;
- the GitHub integration cannot see builderking/koru;
- the repository default or production branch is not main;
- the local website build is not passing;
- the project-name or brand gate remains unresolved.

An existing project is not permission to update it. Inspect and report before any mutation.

### Step 4: resolve GitHub numeric identifiers

Cloudflare's GitHub source configuration requires repository and owner IDs as strings. Resolve them from GitHub rather than guessing:

    gh api repos/builderking/koru --jq \
      '{owner:.owner.login, owner_id:(.owner.id|tostring), repo_name:.name, repo_id:(.id|tostring), default_branch:.default_branch, visibility:.visibility}'

Confirm:

- owner is builderking;
- repository name is koru;
- default branch and intended production branch are main;
- visibility matches the project's public decision;
- owner_id and repo_id are present and represented as strings;
- the installed Cloudflare Pages GitHub App has access to this repository.

GitHub's authoritative endpoint is [Get a repository](https://docs.github.com/en/rest/repos/repos#get-a-repository).

Repository IDs should be copied into the one approved mutation payload and not committed to the app or website. They are configuration identifiers, not secrets, but hard-coding them adds no value.

### Step 5: approval packet

Before any POST, show the operator:

- connected Cloudflare account name;
- whether koru already exists;
- Pages project name;
- generated pages.dev name consequence;
- GitHub owner, repository, owner ID, and repository ID;
- production branch;
- root, build, and output directories;
- preview and production trigger settings;
- GitHub App access scope;
- exact JSON request body;
- statement that the next call creates a remote project and connects automatic deployments.

Approval must be specific to creating this project. A request to plan, inspect, or build the website is not approval to create or deploy.

### Step 6: create only after explicit approval

Current planned API call:

    POST /accounts/ACCOUNT_ID/pages/projects

Planned body:

    {
      "name": "koru",
      "production_branch": "main",
      "build_config": {
        "build_caching": true,
        "build_command": "npm run build",
        "destination_dir": "dist",
        "root_dir": "website"
      },
      "source": {
        "type": "github",
        "config": {
          "owner": "builderking",
          "owner_id": "GITHUB_OWNER_ID",
          "repo_name": "koru",
          "repo_id": "GITHUB_REPO_ID",
          "production_branch": "main",
          "production_deployments_enabled": true,
          "preview_deployment_setting": "all",
          "pr_comments_enabled": true
        }
      }
    }

Conceptual MCP execute call:

    async () => cloudflare.request({
      method: "POST",
      path: "/accounts/ACCOUNT_ID/pages/projects",
      body: APPROVED_BODY
    })

Do not use the deprecated source.config.deployments_enabled field. Use production_deployments_enabled and preview_deployment_setting.

The initial payload intentionally omits path_includes and path_excludes. Those filters can prevent expected previews if wildcard semantics or monorepo changes are misunderstood. Add path-based build controls later through a separately reviewed change if unnecessary site builds become a real cost.

The body must be revalidated against the OpenAPI schema immediately before execution. In particular, confirm whether root_dir accepts website exactly in the current API. The locked intended directory is website; a schema or API discrepancy must be reported, not silently “fixed” to another repository path.

### Step 7: read-only verification after creation

Immediately GET:

    /accounts/ACCOUNT_ID/pages/projects/koru

Verify returned values:

- name is koru;
- production_branch is main;
- source.type is github;
- source.config owner and repo_name are builderking and koru;
- owner_id and repo_id match the GitHub lookup;
- production_deployments_enabled is true;
- preview_deployment_setting is all;
- pr_comments_enabled is true;
- build command is npm run build;
- root directory is website;
- destination directory is dist;
- uses_functions is false;
- subdomain is the expected assigned hostname.

After a commit is intentionally pushed through the normal repository workflow, list deployments:

    /accounts/ACCOUNT_ID/pages/projects/koru/deployments

For the first production deployment verify:

- trigger branch is main;
- trigger commit hash is the intended commit;
- environment is production;
- build stage succeeded;
- final URL returns 200 over HTTPS;
- the deployed source matches the tagged or reviewed commit;
- no Cloudflare Function is present;
- security headers, canonical metadata, asset caching, and redirects behave as expected.

For a pull request from a branch in builderking/koru verify:

- a unique preview deployment is created;
- the branch alias resolves;
- the PR receives the expected status or comment;
- X-Robots-Tag includes noindex;
- the preview is not treated as a production rollback target.

Cloudflare documents that preview deployments receive X-Robots-Tag: noindex by default. Verify the header with:

    curl -I https://PREVIEW_HOST.pages.dev

## GitHub integration permissions

Install or configure the Cloudflare Pages GitHub App with access only to builderking/koru unless a broader repository set is already an intentional BuilderKing policy.

The integration should:

- read repository content and metadata needed to build;
- report deployment checks and approved PR comments;
- not expose Cloudflare credentials to pull request code;
- not make production secrets available to untrusted branches;
- not run release-signing work on Pages.

The static launch website requires no Pages environment variable. If an environment variable becomes necessary, document its purpose and scope before adding it, and keep production and preview values separate.

## Branch and preview policy

**Production**

- only main is the production branch;
- changes reach main through reviewed pull requests;
- Cloudflare production publishing is the result of a successful build from main;
- a failed new build must not replace the last successful production deployment.

**Preview**

- all repository branches may create previews initially;
- pull requests from the same repository receive previews;
- fork pull requests are reviewed without assuming a Cloudflare preview exists;
- preview URLs are treated as public;
- no secrets, draft customer material, or confidential screenshots may be put into website branches;
- Cloudflare Access may be added if future previews contain non-public launch content.

## Headers and caching

Astro's hashed assets can use long-lived immutable caching. HTML should remain revalidatable so releases and corrections appear predictably.

Plan website/public/_headers for:

- a reviewed Content-Security-Policy;
- Referrer-Policy;
- X-Content-Type-Options;
- Permissions-Policy;
- frame-ancestors through CSP;
- long immutable cache rules for hashed build assets;
- shorter or revalidated caching for HTML.

Do not paste a generic CSP before the final asset and analytics decisions. Build the narrow policy from the production output and test it in a preview.

Cloudflare Pages already provides optimized static asset serving. Avoid custom cache rules until a measured need exists: [Serving Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/).

## Custom-domain plan

No custom domain is chosen in this plan.

When a domain is approved:

1. confirm trademark and Koru brand approval;
2. document domain owner and recovery access;
3. use current Cloudflare Pages custom-domain documentation;
4. check existing DNS and production services before mutation;
5. add the domain through an explicitly approved Cloudflare operation;
6. verify certificate issuance, apex/www behavior, canonical URL, redirects, HSTS decision, and ownership;
7. update Astro site metadata and structured data in the same release;
8. retain koru.pages.dev as the platform hostname unless policy requires otherwise.

Do not buy, transfer, attach, or redirect a domain as part of website implementation without separate authorization.

## Rollback

### Bad website deployment

Cloudflare Pages supports immediate rollback to a previously successful **production** deployment:

1. open the Pages project;
2. open Deployments;
3. choose a known-good successful production deployment;
4. select Rollback to this deployment;
5. confirm;
6. verify production URL, critical links, and response headers;
7. revert or fix the source change on main so Git history and production intent converge.

Preview deployments cannot be rollback targets. See [Cloudflare Pages rollbacks](https://developers.cloudflare.com/pages/configuration/rollbacks/).

If API rollback is proposed, use docs and search to retrieve the current rollback endpoint, present the exact target deployment and mutation for approval, then verify through GET calls. Never select a target only by recency; match the known-good commit hash.

### Bad project configuration

- inspect the project with GET;
- compare returned fields to this locked table;
- prepare the smallest API or dashboard correction;
- obtain explicit approval before PATCH;
- verify through a fresh GET and a preview build.

### Wrong project name or subdomain

The pages.dev subdomain cannot be renamed. Deleting and recreating the project is destructive and requires separate explicit approval after confirming there is no production traffic, custom domain, environment configuration, or deployment history that must be preserved.

### Failed initial creation

Do not retry blindly. Capture the Cloudflare error code and documentation URL, re-run API search for the current schema, confirm GitHub App access and IDs, and present the corrected payload before another mutation.

## Operational verification checklist

### Before creation

- [ ] brand and project name approved;
- [ ] public builderking/koru repository exists;
- [ ] main is the intended production branch;
- [ ] website/package-lock.json and website/.node-version are committed;
- [ ] npm ci succeeds in website/;
- [ ] npm run build succeeds in website/;
- [ ] output is website/dist;
- [ ] no runtime adapter or Function is required;
- [ ] security, privacy, source, and release links are valid;
- [ ] GitHub numeric owner and repo IDs are verified;
- [ ] Cloudflare account and GitHub App scope are verified;
- [ ] no existing koru Pages project exists;
- [ ] final API schema is retrieved;
- [ ] explicit create approval is recorded.

### After creation

- [ ] project GET matches approved configuration;
- [ ] assigned pages.dev subdomain is recorded;
- [ ] first preview succeeds;
- [ ] preview is noindex;
- [ ] first production deployment comes only from main;
- [ ] production URL and assets return over HTTPS;
- [ ] security headers pass;
- [ ] no Functions or unexpected bindings exist;
- [ ] Cloudflare and GitHub show the same commit;
- [ ] rollback target and operator procedure are documented;
- [ ] a custom domain has not been attached without separate approval.

## Known platform checks before launch

Review [Cloudflare Pages known issues](https://developers.cloudflare.com/pages/platform/known-issues/) immediately before launch. Also recheck:

- build image and supported Node versions;
- repository integration permissions;
- preview behavior for forks;
- Pages build limits and asset limits;
- deployment retention;
- framework preset behavior;
- Git integration versus Direct Upload restrictions;
- current API deprecations.

## Explicit non-actions in this planning task

This document does not authorize or perform:

- Cloudflare project creation;
- Cloudflare project update or deletion;
- GitHub App installation or permission changes;
- Git push or pull request creation;
- a Pages build or deployment;
- custom-domain purchase or attachment;
- DNS mutation;
- rollback;
- analytics enablement.
