# Telemetry AI

[![Maven Central](https://img.shields.io/maven-central/v/io.quarkiverse.telemetry/telemetry-ai.svg?label=Maven%20Central)](https://search.maven.org/artifact/io.quarkiverse.telemetry/telemetry-ai)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

LLM-powered root-cause analysis of distributed telemetry data using Quarkus, LangChain4j, and Grafana LGTM via MCP.

For detailed documentation, see the [docs](docs/modules/ROOT/pages/index.adoc).

## Requirements

* **Java 21+** and **Maven 3.9+** (or use the included `./mvnw` wrapper)
* **Docker** or **Podman** — Quarkus Dev Services automatically starts LGTM (Grafana, Tempo, Loki, Prometheus), MySQL, and Toxiproxy containers
* **[uvx](https://docs.astral.sh/uv/)** — used to run the `mcp-grafana` MCP server (`pip install uv` or `brew install uv`)
* **LLM API key** — at least one of: `OPENAI_API_KEY`, `GROK_API_KEY`, `GEMINI_API_KEY`, or `WATSONX_API_KEY`

## How to run / test the AI part

From project root, run this 3 commands

(1) ./mvn.proxy.sh quarkus:dev

Wait for (1) to **fully** start, so (2) and (3) share the **same** LGTM resources.

(2) ./mvn.app.sh quarkus:dev

(3) ./mvn.ai.sh quarkus:dev

In (3) you have 3 profiles:
* default - OpenAI
* -Pgrok - Grok xAI
* -Pwatsonx - WatsonX
* -Pgemini - Gemini

This will run Quarkus with same `quarkus.profile` property as Maven profile name,
and picking up the right Quarkus LangChain4J dependencies.

```xml
<!-- Default: OpenAI -->
<profile>
    <id>openai</id>
    <activation>
        <activeByDefault>true</activeByDefault>
    </activation>
    <properties>
        <quarkus.profile>openai</quarkus.profile>
    </properties>
    ...
```

---

(1) Starts a simple `proxy` app, that just forwards the request to an "actual" `app`. 

(2) Starts an `app` that based on the `poke` value returns http code.

```java
    @GET
    @Path("/poke")
    @Produces(MediaType.TEXT_PLAIN)
    public Response poke(@QueryParam("value") Integer value) {
        log.info("Poking ... " + value);
        arr[0] = value;
        if (inRange(400, 600, value)) {
            Response.Status status = Response.Status.fromStatusCode(value);
            throw new WebApplicationException(
                    "App error: " + status.getStatusCode(),
                    Response.status(status)
                            .entity(status.getReasonPhrase())
                            .build()
            );
        }
        Integer copy = value;
        if (!inRange(200, 600, value)) {
            copy = 200; // plain ok
        }
        return Response.status(copy).entity("Poked with " + value).build();
    }
```

(3) Starts the actual AI analysis application.

Set the API key for your chosen LLM provider before starting the AI module:

```bash
export OPENAI_API_KEY=sk-...   # for default/openai profile
export GROK_API_KEY=xai-...    # for -Pgrok profile
```

To enable Dev MCP (source examination, dashboard generation), the companion apps must have `quarkus.dev-mcp.enabled=true` in their `application.properties`, and the AI module needs to know their ports:

```bash
./mvn.ai.sh quarkus:dev -Dapp.ports=8081,8082
```

---

Poke the `proxy` app via browser or curl: `http://localhost:8081/poke?value=<your choice of http code>`

Poke it a few times with different `http codes`, so we get different traces, logs, metrics, ...

---

You can check any app's DevUI on where the Grafana / LGTM is available - for any other queries, etc

### Standalone AI module

To quickly start just the AI module with Dev Services (LGTM auto-starts):

```bash
./dev-ai.sh 8081,8082
```

This runs the AI module in Quarkus dev mode, automatically starting LGTM via Dev Services. The ports argument tells the AI module which companion app ports to connect to via Dev MCP.

For production use with an existing LGTM instance, use the pre-built uber-jar:

```bash
./run-ai.sh 8081,8082 http://localhost:3000 http://localhost:3200
```

The uber-jar can also be downloaded from Maven Central as `io.quarkiverse.telemetry:telemetry-ai-core:<version>:jar:runner`.

### Manual LGTM (without DevServices)

Use `run-lgtm.sh` to start LGTM and the AI module in one command:

```bash
./run-lgtm.sh                  # no app.ports
./run-lgtm.sh 8081,8082        # with app.ports for Dev MCP
```

Or do it manually. To connect to an externally started LGTM stack instead of using Quarkus DevServices, start LGTM manually:

```bash
docker run -p 3000:3000 -p 4317:4317 -p 4318:4318 -p 3200:3200 grafana/otel-lgtm:0.24.0
```

Then run each Quarkus app with the `lgtm` profile. The `ai` module also needs an LLM profile (e.g. `openai`, `grok`) — Quarkus supports multiple comma-separated profiles:

```bash
./mvn.proxy.sh quarkus:dev -Dquarkus.profile=lgtm
./mvn.app.sh quarkus:dev -Dquarkus.profile=lgtm
./mvn.ai.sh quarkus:dev -Dquarkus.profile=lgtm,openai
```

---

## Web UI

Once the `ai` app is running (step 3), open `http://localhost:8080` in a browser to access the **Telemetry AI Analysis** web UI.

The UI provides:
* **Traces** — number of recent traces to analyze (1–20)
* **Output Format** — HTML, Markdown, Plain Text, or AsciiDoc
* **Examine Source** — optionally include source code examination in the analysis
* **Create Dashboard** — optionally generate a dashboard JSON from the analysis

Click **Analyze** to call `/analyze/{n}` and view results in three collapsible sections:
1. **Analysis** — the main AI-generated trace/log/metric analysis (always present)
2. **Examined Sources** — source code insights rendered as Markdown (when enabled)
3. **Dashboard** — generated dashboard definition as JSON (when enabled)

Each section has a **Copy** button for clipboard export.

---

## Integration tests

Use `run-integration-test.sh` to run integration tests with flexible LLM and test type selection.

The script takes up to three arguments:
1. **Test type** — `chaos` (ChaosIntegrationTest), `db` (DbIntegrationTest), or `weather` (WeatherIntegrationTest) (default: `chaos`)
2. **AI profile** — which LLM powers `TelemetryAiService` / `DevMcpAiService` (default: `openai`)
3. **Scorer** — which LLM scores the test evaluation (default: `openai`)

```bash
./run-integration-test.sh                       # chaos, both openai
./run-integration-test.sh chaos grok            # chaos, AI=grok, scorer=openai
./run-integration-test.sh chaos openai grok     # chaos, AI=openai, scorer=grok
./run-integration-test.sh chaos grok grok       # chaos, both grok
./run-integration-test.sh db openai             # db, AI=openai, scorer=openai
./run-integration-test.sh db grok grok          # db, both grok
./run-integration-test.sh weather openai grok   # weather, AI=openai, scorer=grok
```

Run all provider combinations for a test type:
```bash
./run-all-integration-tests.sh chaos            # all 4 combos for chaos
./run-all-integration-tests.sh db               # all 4 combos for db
./run-all-integration-tests.sh weather          # all 4 combos for weather
```

Supported AI profiles: `openai`, `grok`, `gemini`, `watsonx`.
Supported scorers: `openai` (default), `grok`, `watsonx`.

Grok (xAI) reuses the `quarkus-langchain4j-openai` extension with `base-url=https://api.x.ai/v1`.
Set `GROK_API_KEY` env var before running with grok.
Set `WATSONX_BASE_URL`, `WATSONX_API_KEY`, and `WATSONX_PROJECT_ID` env vars before running with watsonx.

### Running specific test methods

Use `run-integration-methods.sh` to run individual test methods:

```bash
./run-integration-methods.sh <chaos|db|weather> <ai-profile> [scorer] <method1> [method2] ...
```

Pass an empty string `''` for scorer to use the default (openai).

```bash
# Chaos tests
./run-integration-methods.sh chaos openai grok analyzeIntermittentFailures analyzeNetworkPartition
./run-integration-methods.sh chaos grok '' analyzeRequestFlood

# DB tests
./run-integration-methods.sh db openai '' analyzeNormalTraffic

# Weather tests
./run-integration-methods.sh weather openai grok analyzeWeatherSlowApi
```

Available chaos test methods:

| Method | Scenario |
|---|---|
| `analyzeNormalTraffic` | Baseline healthy requests |
| `analyzeErrorTraffic` | HTTP 500, 403, random 5xx |
| `analyzeLatency` | Injected delays (3-5s) |
| `analyzeResourcePressure` | Memory allocation, CPU burn, memory leaks |
| `analyzeCascadingFailure` | Exception + threadpool + GC churn |
| `analyzeLockContention` | Synchronized lock contention |
| `analyzeIntermittentFailures` | ~60% random failure rate |
| `analyzeNetworkPartition` | App stopped/restarted mid-test |
| `analyzeRequestFlood` | Multiple delayed requests + error |
| `analyzeDeadlock` | Thread deadlock with timeout detection |
| `examineSourceCode` | Source code examination via Dev MCP |
| `generateDashboard` | Grafana dashboard generation from analysis |

Available db test methods:

| Method | Scenario |
|---|---|
| `analyzeNormalTraffic` | Database person queries (by name, surname) |
| `analyzeSlowQueries` | Slow queries via Toxiproxy latency injection (3s delay) |
| `analyzePoolExhaustion` | Connection pool exhaustion via 4s latency + small pool + concurrent requests |
| `analyzeDbOutage` | Database outage via Toxiproxy connection cut |

Available weather test methods:

| Method | Scenario |
|---|---|
| `analyzeWeatherNormal` | REST client calls to Open-Meteo API, healthy state |
| `analyzeWeatherSlowApi` | Toxiproxy 3s latency on weather API |
| `analyzeWeatherApiOutage` | Weather API outage via Toxiproxy connection cut |
