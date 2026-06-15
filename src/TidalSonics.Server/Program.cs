var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

builder.Services
    .AddMcpServer()
    .WithHttpTransport(opt => opt.Stateless = true)
    .WithToolsFromAssembly();

var app = builder.Build();

app.UseCors();
app.MapMcp("/mcp");

app.Run();
