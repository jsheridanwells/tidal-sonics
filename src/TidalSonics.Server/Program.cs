using ModelContextProtocol.Server;

var builder = WebApplication.CreateBuilder(args);

    builder.Services
    .AddMcpServer()
    .WithHttpTransport(opt => opt.Stateless = true)
    .WithToolsFromAssembly();

var app = builder.Build();

app.MapMcp("/mcp");

app.Run();
