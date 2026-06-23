using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Models;
using WasteGlassRoute = WasteGlassAPI.Models.Route;

namespace WasteGlassAPI.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Supplier> Suppliers { get; set; } = null!;
    public DbSet<CollectionRecord> CollectionRecords { get; set; } = null!;
    public DbSet<WasteGlassRoute> Routes { get; set; } = null!;
    public DbSet<RouteStop> RouteStops { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Supplier>()
            .HasIndex(supplier => supplier.SupplierId)
            .IsUnique();

        modelBuilder.Entity<Supplier>()
            .Property(supplier => supplier.SupplierId)
            .IsRequired();

        modelBuilder.Entity<CollectionRecord>()
            .Property(record => record.SupplierId)
            .IsRequired();

        modelBuilder.Entity<WasteGlassRoute>()
            .HasMany(route => route.RouteStops)
            .WithOne(routeStop => routeStop.Route)
            .HasForeignKey(routeStop => routeStop.RouteId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<RouteStop>()
            .HasOne(routeStop => routeStop.Supplier)
            .WithMany()
            .HasForeignKey(routeStop => routeStop.SupplierId)
            .HasPrincipalKey(supplier => supplier.SupplierId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<RouteStop>()
            .Property(routeStop => routeStop.SupplierId)
            .IsRequired();
    }
}
