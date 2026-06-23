using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.Models;
using WasteGlassRoute = WasteGlassAPI.Models.Route;

namespace WasteGlassAPI.Services;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(AppDbContext context)
    {
        await SeedSuppliersAsync(context);
        await SeedTodayRouteAsync(context);
        await RouteScheduler.RebalanceRoutesAsync(context);
    }

    private static async Task SeedSuppliersAsync(AppDbContext context)
    {
        var suppliers = new List<Supplier>
        {
            new Supplier
            {
                SupplierId = "SUP001",
                Name = "ABC Glass Supplier",
                Location = "Kandy Road",
                Latitude = 7.2906,
                Longitude = 80.6337,
                ExpectedKg = 30,
                BarcodeValue = "SUP001",
                Status = "Pending"
            },
            new Supplier
            {
                SupplierId = "SUP002",
                Name = "XYZ Glass Center",
                Location = "Matale Road",
                Latitude = 7.4675,
                Longitude = 80.6234,
                ExpectedKg = 25,
                BarcodeValue = "SUP002",
                Status = "Pending"
            },
            new Supplier
            {
                SupplierId = "SUP003",
                Name = "Green Glass Hub",
                Location = "Dambulla",
                Latitude = 7.8731,
                Longitude = 80.6511,
                ExpectedKg = 20,
                BarcodeValue = "SUP003",
                Status = "Pending"
            },
            new Supplier
            {
                SupplierId = "SUP004",
                Name = "City Bottle Depot",
                Location = "Peradeniya Road",
                Latitude = 7.2667,
                Longitude = 80.5967,
                ExpectedKg = 22,
                BarcodeValue = "SUP004",
                Status = "Pending"
            },
            new Supplier
            {
                SupplierId = "SUP005",
                Name = "Central Glass Recyclers",
                Location = "Katugastota",
                Latitude = 7.3333,
                Longitude = 80.6167,
                ExpectedKg = 18,
                BarcodeValue = "SUP005",
                Status = "Pending"
            }
        };

        foreach (var supplier in suppliers)
        {
            var exists = await context.Suppliers
                .AnyAsync(item => item.SupplierId == supplier.SupplierId);

            if (!exists)
            {
                context.Suppliers.Add(supplier);
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedTodayRouteAsync(AppDbContext context)
    {
        var today = DateTime.Today;
        var route = await context.Routes
            .Include(item => item.RouteStops)
            .FirstOrDefaultAsync(item => item.RouteDate.Date == today);

        if (route is null)
        {
            route = new WasteGlassRoute
            {
                RouteDate = today,
                DriverName = "Collector 01",
                Status = "Active"
            };

            context.Routes.Add(route);
            await context.SaveChangesAsync();
        }

        var routeStops = new[]
        {
            new { SupplierId = "SUP001", Sequence = 1 },
            new { SupplierId = "SUP002", Sequence = 2 },
            new { SupplierId = "SUP003", Sequence = 3 },
            new { SupplierId = "SUP004", Sequence = 4 },
            new { SupplierId = "SUP005", Sequence = 5 }
        };

        foreach (var stop in routeStops)
        {
            var exists = await context.RouteStops.AnyAsync(item =>
                item.RouteId == route.Id &&
                item.SupplierId == stop.SupplierId);

            if (!exists)
            {
                context.RouteStops.Add(new RouteStop
                {
                    RouteId = route.Id,
                    SupplierId = stop.SupplierId,
                    StopSequence = stop.Sequence,
                    Status = "Pending"
                });
            }
        }

        await context.SaveChangesAsync();
    }
}
