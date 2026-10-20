# full-sample

Every [wasichai](https://github.com/wasichai/wasichai) module in one app: the server and a web that mounts every
[wasichai-ui](https://github.com/wasichai/wasichai-ui) module. Both build against checkouts next to this one (a Gradle
composite build for `../wasichai`, linked packages for `../wasichai-ui`), so a change there is tested here at once.

The AI assistant (`wasichai-agent`) is left out: it is not supported in a native image yet (wasichai ADR-068).

## Run it

```bash
git clone https://github.com/wasichai/wasichai ../wasichai
docker compose up -d                       # PostGIS on 5433
export WASICHAI_DB_PORT=5433 WASICHAI_JWT_SECRET=dev-only-secret-that-is-at-least-32-bytes
./gradlew :server:bootRun                  # http://localhost:8090, admin@wasichai.local / admin
```

Without GeoServer, add `WASICHAI_GIS_GEOSERVER_ENABLED=false`: layer publishing is then refused, everything else works.

## Run the web

`web/` is the Vite host of the UI: `@wasichai/core` with the views, forms, pages, workflow, automation, documents and
gis modules (the assistant is left out, as on the server). Its `@wasichai/*` dependencies are links into
`../../wasichai-ui/packages`, built there first:

```bash
git clone https://github.com/wasichai/wasichai-ui ../wasichai-ui
(cd ../wasichai-ui && yarn install && yarn build)
cd web
yarn install
yarn dev                                   # http://localhost:5173, /api proxied to http://localhost:8090
yarn build && yarn preview                 # the built web on http://localhost:4173
```

`API_URL` points the proxy at another server. The wasichai manuals take their screenshots from this web
(wasichai `docs/manuals`, ADR-070).

## Native image

With GraalVM 25 or later as `JAVA_HOME`:

```bash
./gradlew :server:nativeCompile
server/build/native/nativeCompile/full-sample
```

The image fixes the switches that choose beans (`wasichai.<module>.enabled`, `wasichai.seed.dev`, …) when it is
built; database, secrets and the rest still read at startup.

## Smoke e2e

`e2e/smoke.sh` (bash, curl, jq) creates an object and exercises every module through the REST API. CI runs it against
the jar and against the native image.

```bash
BASE_URL=http://localhost:8090 e2e/smoke.sh
```
