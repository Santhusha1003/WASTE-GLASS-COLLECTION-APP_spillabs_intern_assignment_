using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.Services;

var builder = WebApplication.CreateBuilder(args);

const string DevelopmentCorsPolicy = "DevelopmentCorsPolicy";

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddScoped<RouteScheduler>();

builder.Services.AddCors(options =>
{
    options.AddPolicy(DevelopmentCorsPolicy, policy =>
    {
        policy
            .SetIsOriginAllowed(origin =>
                origin == "http://localhost:3000" ||
                origin == "http://localhost:5000" ||
                builder.Environment.IsDevelopment())
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

var port = Environment.GetEnvironmentVariable("PORT") ?? "10000";
app.Urls.Clear();
app.Urls.Add($"http://0.0.0.0:{port}");

app.UseSwagger();
app.UseSwaggerUI();

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseCors(DevelopmentCorsPolicy);
app.MapControllers();

try
{
    using var scope = app.Services.CreateScope();
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await context.Database.EnsureCreatedAsync();

    // EnsureCreated does not evolve an existing SQLite database. Add the
    // collection route date for existing local/Render databases; new databases
    // receive it directly from the EF model.
    try
    {
        await context.Database.ExecuteSqlRawAsync(
            "ALTER TABLE CollectionRecords ADD COLUMN RouteDate TEXT NOT NULL DEFAULT '0001-01-01 00:00:00'");
    }
    catch (Microsoft.Data.Sqlite.SqliteException ex) when (ex.SqliteErrorCode == 1 &&
        ex.Message.Contains("duplicate column name", StringComparison.OrdinalIgnoreCase))
    {
        // Column already exists.
    }

    await context.Database.ExecuteSqlRawAsync("""
        UPDATE CollectionRecords
        SET RouteDate = substr(Timestamp, 1, 10) || ' 00:00:00'
        WHERE RouteDate = '0001-01-01 00:00:00'
           OR RouteDate = '0001-01-01T00:00:00'
        """);

    await DatabaseSeeder.SeedAsync(context);
}
catch (Exception ex)
{
    Console.WriteLine("Database startup/seed error:");
    Console.WriteLine(ex);
}

app.Run();
