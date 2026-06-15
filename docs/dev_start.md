# Local dev workflow

## Inner loop — fast tool iteration (no claude.ai)

```bash
# Terminal 1
cd src/TidalSonics.Server && dotnet watch run

# Terminal 2
npx @modelcontextprotocol/inspector
# Connect to http://localhost:3001/mcp over Streamable HTTP
```

Edit code → `dotnet watch` rebuilds → Inspector reconnects. Use this for tool logic.

## Outer loop — claude.ai end-to-end

```bash
# Terminal 1
cd src/TidalSonics.Server && dotnet watch run

# Terminal 2
devtunnel host tidal-sonics-jsw
# Tunnel URL: https://tidal-sonics-jsw-3001.use.devtunnels.ms/mcp
# Inspect traffic: https://tidal-sonics-jsw-3001-inspect.use.devtunnels.ms
```

In claude.ai: new conversation → enable **TIDAL Sonics (dev)** connector. Use this for conversation flow and tool description iteration.

## Notes

- **Tool names are lowercased** by the MCP .NET SDK. A method named `Hello` registers as `hello`. Applies to every tool you add.
- **claude.ai "Network error" on tool calls** means the connector session is stale. Fix: Settings → Connectors → remove and re-add TIDAL Sonics (dev).
- **`dotnet watch` rebuilds** briefly drop the connection. claude.ai recovers on the next tool call — ignore transient red badges.
