---
id: SPEC-001
topic: tidal-sonics
kind: spec
date: 2026-05-18
last_updated: 2026-05-18
status: ForApproval
depends_on: []
supersedes: null
superseded_by: null
context_files: []
success_criteria:
  - Solution and single project compile clean on .NET 10
  - `dotnet run` starts an MCP server on a known local port
  - MCP Inspector connects, lists the `hello` tool, and successfully invokes it
  - No container, no Azure, no auth in this slice
---

# SPEC-001: Project scaffold and first MCP tool, local only

## ADR

This first slice establishes the project skeleton and proves the official MCP SDK is wired correctly before any deployment, auth, or TIDAL work lands. Decisions captured here cascade through the rest of the project, so they're called out explicitly:

- **SDK:** `ModelContextProtocol.AspNetCore` (1.x stable). Attribute-based tool discovery via `[McpServerToolType]` / `[McpServerTool]`. Maintained jointly by Anthropic and Microsoft, hit 1.0 in March 2026. Chosen over the Azure Functions `[McpToolTrigger]` extension because (a) it's the official protocol SDK, so what's learned transfers cleanly, (b) ASP.NET Core's auth story is well-trodden for the Google OAuth work later, (c) it avoids tying ourselves to a preview Functions binding.
- **Framework:** .NET 10 (LTS, released November 2025). SDK supports net8.0+, so we're well inside the supported window. Bump to .NET 11 later if there's reason; no reason now.
- **Host shape:** ASP.NET Core minimal API. `WebApplication.CreateBuilder` → `AddMcpServer().WithHttpTransport().WithToolsFromAssembly()` → `app.MapMcp()`. The idiomatic shape from the SDK getting-started docs.
- **Transport:** Streamable HTTP. This is the current MCP standard (the older SSE transport is being phased out at the spec level) and is what `WithHttpTransport()` exposes. Required for remote hosting later; works fine for local dev now.
- **Stateless mode:** `options.Stateless = true`. We don't need server-to-client features like sampling or elicitation. Stateless is operationally simpler — no sticky sessions needed when we move to Container Apps in SPEC-003.
- **Project layout:** Single project (`TidalSonics.Server`) to start. Defer splitting into multiple projects (tests, abstractions, etc.) until there's a concrete reason. Premature structure costs comprehension.
- **No Dockerfile, no Azure resources, no auth in this slice.** SPEC-002 adds containerization; SPEC-003 adds deployment; SPEC-006 adds Google OAuth federation. Keeping each slice single-axis is the entire point of this cadence.

Out of scope for SPEC-001: the actual `hello` tool's signature beyond "takes a name, returns a greeting" — we're testing the wiring, not designing a real tool surface. The shape of real tools (`search_tracks`, `create_playlist`, etc.) is decided in their own specs.

## Specs

### Spec 1: Repository and solution layout

```
tidal-sonics/
├── .gitignore                       # standard VS / .NET gitignore
├── README.md                        # one-paragraph project overview
├── specs/
│   └── SPEC-001.md                  # this document
├── src/
│   └── TidalSonics.Server/
│       ├── TidalSonics.Server.csproj
│       ├── Program.cs
│       ├── appsettings.json
│       └── Tools/
│           └── HelloTool.cs
└── TidalSonics.sln
```

`specs/` is where future SPEC-NNN docs live. Claude Code is pointed at the relevant spec when working a task.

### Spec 2: Project file (`TidalSonics.Server.csproj`)

- SDK: `Microsoft.NET.Sdk.Web`
- `TargetFramework`: `net10.0`
- `Nullable`: enabled
- `ImplicitUsings`: enabled
- PackageReferences:
  - `ModelContextProtocol.AspNetCore` — pick the highest 1.x stable at scaffold time, pin it explicitly in the csproj rather than letting `dotnet add` pick a floating range.

No other packages this slice.

### Spec 3: `Program.cs`

Minimal API host that registers the MCP server, configures stateless streamable HTTP transport, discovers tools from the assembly, and binds to a fixed local port for predictable Inspector connection.

```csharp
using ModelContextProtocol.Server;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddMcpServer()
    .WithHttpTransport(options => options.Stateless = true)
    .WithToolsFromAssembly();

var app = builder.Build();

app.MapMcp();

app.Run("http://localhost:3001");
```

Port 3001 is the convention used in the SDK's getting-started docs and Inspector defaults assume that range. Pin it now; parameterise via configuration in a later slice if we ever need to.

### Spec 4: The `Hello` tool

```csharp
using System.ComponentModel;
using ModelContextProtocol.Server;

namespace TidalSonics.Server.Tools;

[McpServerToolType]
public static class HelloTool
{
    [McpServerTool, Description("Returns a friendly greeting. Used to verify MCP server wiring.")]
    public static string Hello(
        [Description("Name to greet.")] string name)
        => $"Hello, {name}! TidalSonics MCP server is alive.";
}
```

Deliberately trivial. Single string in, single string out. Static method on a static class — matches the SDK docs and sidesteps DI considerations for this first slice.

The `[Description]` attributes on both the method and the parameter are load-bearing: those strings are what an LLM client (and the Inspector) will see when deciding whether and how to call the tool. Treat tool descriptions as production code from day one — they're the API surface the model sees.

### Spec 5: Local validation via MCP Inspector

MCP Inspector is the official browser-based debugger for MCP servers. Launched via `npx @modelcontextprotocol/inspector`. It opens a UI where you point it at your server's URL/transport, browse the tool list, and invoke tools interactively.

For this slice:

- Server URL: `http://localhost:3001` (with whatever path `MapMcp()` exposes — see Notes)
- Transport: Streamable HTTP
- Expected tool list: one tool named `Hello`
- Expected invocation: `{ "name": "Jeremy" }` → `"Hello, Jeremy! TidalSonics MCP server is alive."`

This is the success criterion for the slice. No further validation needed.

## Tasks

Tasks are ordered. Each is small enough to run, verify, and commit before moving on. Use these as Claude Code prompts.

### Task 1: Initialize the repo and solution

In an empty `tidal-sonics/` directory:

```bash
git init
dotnet new gitignore
dotnet new sln -n TidalSonics
mkdir -p src specs
dotnet new web -n TidalSonics.Server -o src/TidalSonics.Server -f net10.0
dotnet sln add src/TidalSonics.Server/TidalSonics.Server.csproj
```

Verify `dotnet build` succeeds on the empty web project. Commit: `chore: scaffold solution and project structure`.

### Task 2: Add the MCP SDK package

```bash
cd src/TidalSonics.Server
dotnet add package ModelContextProtocol.AspNetCore
```

Inspect `TidalSonics.Server.csproj` and confirm the version that landed is a 1.x stable release. If `dotnet add` pulled a preview, pin to the latest stable 1.x explicitly in the csproj. Commit: `chore: add ModelContextProtocol.AspNetCore`.

### Task 3: Replace the default `Program.cs`

Replace the generated `Program.cs` with the contents from Spec 3 above. Strip any default sample endpoints that `dotnet new web` produced. Commit: `feat: register MCP server with stateless HTTP transport`.

### Task 4: Add the `Hello` tool

Create `src/TidalSonics.Server/Tools/HelloTool.cs` with the contents from Spec 4 above. Commit: `feat: add Hello tool for MCP wiring validation`.

### Task 5: Build and run

```bash
dotnet build
dotnet run --project src/TidalSonics.Server
```

Expected: server logs show it listening on `http://localhost:3001`. Leave it running.

### Task 6: Launch MCP Inspector and validate

In a separate terminal:

```bash
npx @modelcontextprotocol/inspector
```

In the Inspector UI:

1. Set transport to Streamable HTTP.
2. Set server URL to `http://localhost:3001` plus the MCP path (see Notes — likely `/` or `/mcp`).
3. Connect. No auth.
4. Confirm exactly one tool (`Hello`) appears in the list with the description we wrote.
5. Invoke it with `{ "name": "Jeremy" }`.
6. Confirm the response string comes back as expected.

If all six steps pass, SPEC-001 is **Completed**. Update frontmatter `status` and `last_updated`, and commit the spec file.

### Task 7: Stub the README

A `README.md` at the repo root with: project goal in one or two sentences, pointer to `specs/`, how to run locally. Doesn't need to be polished — placeholder we'll grow into. Commit: `docs: project README stub`.

## Notes

- **MCP endpoint path.** `MapMcp()` registers the MCP endpoints at a default path (likely `/` for the streamable HTTP endpoint). If Inspector can't auto-discover, pin it explicitly with `app.MapMcp("/mcp")` and connect to `http://localhost:3001/mcp`. Worth a one-line check during Task 6.
- **Host header validation.** DNS-rebinding protection (host filtering, restrictive CORS) is a production concern called out in the SDK docs. Not needed for localhost dev. We'll address it in SPEC-003 when the server becomes reachable from the public internet.
- **What `dotnet new web` produces.** The minimal `web` template typically gives you just a `Program.cs` with a single `GET /` endpoint and an `appsettings.json` with logging config. Keep `appsettings.json`, strip the sample endpoint.
- **No tests yet.** Test project is deliberately deferred. If at any point during this slice you find yourself wishing for a test scaffold, that's a signal to insert a SPEC-001.5 before continuing — don't bolt it in mid-slice.
