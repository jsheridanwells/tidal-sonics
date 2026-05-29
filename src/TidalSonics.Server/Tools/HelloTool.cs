
using System.ComponentModel;
using ModelContextProtocol.Server;

[McpServerToolType]
public static class HelloTool
{
    [McpServerTool, Description("returns a friendly greeting. use to verify server wiring.")]
    public static string Hello([Description("name to greet")] string name)
        => $"Hello, {name}! Tidal Sonics is Boomin'";
}
