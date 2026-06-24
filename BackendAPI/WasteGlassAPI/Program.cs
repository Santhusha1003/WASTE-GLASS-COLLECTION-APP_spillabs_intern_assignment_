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

app.UseSwagger();
app.UseSwaggerUI();

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseCors(DevelopmentCorsPolicy);
app.MapControllers();

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    context.Database.Migrate();
    await DatabaseSeeder.SeedAsync(context);
}

app.Run();
