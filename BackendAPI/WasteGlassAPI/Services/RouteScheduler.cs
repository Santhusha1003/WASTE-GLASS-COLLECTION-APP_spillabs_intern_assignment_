using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassRoute = WasteGlassAPI.Models.Route;

namespace WasteGlassAPI.Services;

public static class RouteScheduler
{
    private const int MaxStopsPerRoute = 5;

    public static async Task<WasteGlassRoute> GetAvailableRouteAsync(AppDbContext context)
    {
        var routeDate = await FindAvailableRouteDateStartingFrom(context, DateTime.Today);
        return await FindOrCreateRouteAsync(context, routeDate);
    }

    public static async Task<DateTime> FindAvailableRouteDateStartingFrom(
        AppDbContext context,
        DateTime startDate)
    {
        await NormalizeRouteOverflowAsync(context);

        var routeDate = startDate.Date;

        while (true)
        {
            var route = await FindOrCreateRouteAsync(context, routeDate);
            var stopCount = await context.RouteStops.CountAsync(item => item.RouteId == route.Id);

            if (stopCount < MaxStopsPerRoute)
            {
                return routeDate;
            }

            routeDate = routeDate.AddDays(1);
        }
    }

    public static Task<WasteGlassRoute> FindAvailableRouteAsync(AppDbContext context)
    {
        return GetAvailableRouteAsync(context);
    }

    public static async Task NormalizeRouteOverflowAsync(AppDbContext context)
    {
        var today = DateTime.Today;

        // Only normalize stops from today onwards — never touch past routes
        var stops = await context.RouteStops
            .Include(stop => stop.Route)
            .Where(stop => stop.Route.RouteDate.Date >= today)
            .OrderBy(stop => stop.Route.RouteDate)
            .ThenBy(stop => stop.StopSequence)
            .ThenBy(stop => stop.Id)
            .ToListAsync();

        if (stops.Count == 0)
        {
            return;
        }

        for (var index = 0; index < stops.Count; index++)
        {
            var targetDate = today.AddDays(index / MaxStopsPerRoute);
            var targetRoute = await FindOrCreateRouteAsync(context, targetDate);

            stops[index].RouteId = targetRoute.Id;
            stops[index].StopSequence = (index % MaxStopsPerRoute) + 1;
        }

        await context.SaveChangesAsync();
        context.ChangeTracker.Clear();
    }

    public static Task NormalizeRouteStopsAsync(AppDbContext context)
    {
        return NormalizeRouteOverflowAsync(context);
    }

    public static Task RebalanceRoutesAsync(AppDbContext context)
    {
        return NormalizeRouteOverflowAsync(context);
    }

    /// <summary>Public accessor used by AdminController for date-targeted route creation.</summary>
    public static Task<WasteGlassRoute> FindOrCreateRouteForDateAsync(
        AppDbContext context,
        DateTime routeDate)
    {
        return FindOrCreateRouteAsync(context, routeDate);
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
