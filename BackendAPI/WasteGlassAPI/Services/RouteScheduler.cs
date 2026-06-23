using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassRoute = WasteGlassAPI.Models.Route;

namespace WasteGlassAPI.Services;

public static class RouteScheduler
{
    public static async Task<WasteGlassRoute> FindAvailableRouteAsync(AppDbContext context)
    {
        var routeDate = DateTime.Today;

        while (true)
        {
            var route = await FindOrCreateRouteAsync(context, routeDate);
            var stopCount = await context.RouteStops.CountAsync(item => item.RouteId == route.Id);

            if (stopCount < 5)
            {
                return route;
            }

            routeDate = routeDate.AddDays(1);
        }
    }

    public static async Task RebalanceRoutesAsync(AppDbContext context)
    {
        var today = DateTime.Today;
        var routes = await context.Routes
            .Include(route => route.RouteStops)
            .Where(route => route.RouteDate.Date >= today)
            .OrderBy(route => route.RouteDate)
            .ToListAsync();

        if (routes.Count == 0)
        {
            return;
        }

        var stops = routes
            .SelectMany(route => route.RouteStops
                .OrderBy(stop => stop.StopSequence)
                .ThenBy(stop => stop.Id)
                .Select(stop => new { RouteDate = route.RouteDate.Date, Stop = stop }))
            .OrderBy(item => item.RouteDate)
            .ThenBy(item => item.Stop.StopSequence)
            .ThenBy(item => item.Stop.Id)
            .Select(item => item.Stop)
            .ToList();

        for (var index = 0; index < stops.Count; index++)
        {
            var targetDate = today.AddDays(index / 5);
            var targetRoute = await FindOrCreateRouteAsync(context, targetDate);

            stops[index].RouteId = targetRoute.Id;
            stops[index].StopSequence = (index % 5) + 1;
        }

        await context.SaveChangesAsync();
    }

    private static async Task<WasteGlassRoute> FindOrCreateRouteAsync(
        AppDbContext context,
        DateTime routeDate)
    {
        var route = await context.Routes
            .FirstOrDefaultAsync(item => item.RouteDate.Date == routeDate.Date);

        if (route is not null)
        {
            return route;
        }

        route = new WasteGlassRoute
        {
            RouteDate = routeDate.Date,
            DriverName = "Collector 01",
            Status = "Active"
        };

        context.Routes.Add(route);
        await context.SaveChangesAsync();

        return route;
    }
}
