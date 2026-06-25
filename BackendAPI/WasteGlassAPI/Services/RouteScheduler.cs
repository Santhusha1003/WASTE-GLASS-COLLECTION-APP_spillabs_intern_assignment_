using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassRoute = WasteGlassAPI.Models.Route;

namespace WasteGlassAPI.Services;

public class RouteScheduler
{
    private const int MaxStopsPerRoute = 5;
    public const double DepotLatitude = 7.2906;
    public const double DepotLongitude = 80.6337;
    private const double EarthRadiusKm = 6371;
    private readonly AppDbContext _context;

    public RouteScheduler(AppDbContext context)
    {
        _context = context;
    }

    public double CalculateHaversineDistance(
        double lat1,
        double lon1,
        double lat2,
        double lon2)
    {
        var latitudeDelta = DegreesToRadians(lat2 - lat1);
        var longitudeDelta = DegreesToRadians(lon2 - lon1);
        var latitude1 = DegreesToRadians(lat1);
        var latitude2 = DegreesToRadians(lat2);

        var a = Math.Pow(Math.Sin(latitudeDelta / 2), 2)
            + Math.Cos(latitude1)
            * Math.Cos(latitude2)
            * Math.Pow(Math.Sin(longitudeDelta / 2), 2);
        a = Math.Clamp(a, 0, 1);

        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return Math.Round(EarthRadiusKm * c, 1);
    }

    // Nearest-neighbor Dijkstra-style ordering using Haversine edge weights.
    public async Task OptimizeRouteAsync(int routeId)
    {
        var route = await _context.Routes
            .Include(item => item.RouteStops)
            .ThenInclude(stop => stop.Supplier)
            .FirstOrDefaultAsync(item => item.Id == routeId);

        if (route is null || route.RouteStops.Count == 0)
        {
            return;
        }

        var unvisited = route.RouteStops.ToList();
        var currentLatitude = DepotLatitude;
        var currentLongitude = DepotLongitude;
        var sequence = 1;

        while (unvisited.Count > 0)
        {
            var nearest = unvisited
                .Select(stop => new
                {
                    Stop = stop,
                    DistanceKm = HasValidCoordinates(stop.Supplier)
                        ? CalculateHaversineDistance(
                            currentLatitude,
                            currentLongitude,
                            stop.Supplier.Latitude,
                            stop.Supplier.Longitude)
                        : 0.0
                })
                .OrderBy(candidate => candidate.DistanceKm)
                .ThenBy(candidate => candidate.Stop.Id)
                .First();

            var selectedStop = nearest.Stop;
            selectedStop.StopSequence = sequence++;
            selectedStop.DistanceKm = nearest.DistanceKm;

            Console.WriteLine(
                $"Distance for {selectedStop.SupplierId}: {selectedStop.DistanceKm}");

            if (HasValidCoordinates(selectedStop.Supplier))
            {
                currentLatitude = selectedStop.Supplier.Latitude;
                currentLongitude = selectedStop.Supplier.Longitude;
            }

            unvisited.Remove(selectedStop);
        }

        await _context.SaveChangesAsync();
    }

    private static bool HasValidCoordinates(WasteGlassAPI.Models.Supplier supplier)
    {
        return supplier.Latitude is >= -90 and <= 90
            && supplier.Longitude is >= -180 and <= 180
            && supplier.Latitude != 0
            && supplier.Longitude != 0;
    }

    private static double DegreesToRadians(double degrees)
    {
        return degrees * Math.PI / 180;
    }

    private static async Task OptimizeRouteAsync(AppDbContext context, int routeId)
    {
        await new RouteScheduler(context).OptimizeRouteAsync(routeId);
    }

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
        var routes = await context.Routes
            .Include(route => route.RouteStops)
            .Where(route => route.RouteDate.Date >= today)
            .OrderBy(route => route.RouteDate)
            .ToListAsync();

        var affectedRouteIds = new HashSet<int>();

        foreach (var route in routes)
        {
            var overflow = route.RouteStops
                .OrderBy(stop => stop.StopSequence)
                .ThenBy(stop => stop.Id)
                .Skip(MaxStopsPerRoute)
                .ToList();

            foreach (var stop in overflow)
            {
                var targetDate = route.RouteDate.Date.AddDays(1);
                WasteGlassRoute targetRoute;

                while (true)
                {
                    targetRoute = await FindOrCreateRouteAsync(context, targetDate);
                    var targetStopCount = await context.RouteStops
                        .CountAsync(item => item.RouteId == targetRoute.Id);
                    var pendingMoves = context.ChangeTracker.Entries<Models.RouteStop>()
                        .Count(entry => entry.Entity.RouteId == targetRoute.Id
                            && entry.State != EntityState.Deleted);

                    if (Math.Max(targetStopCount, pendingMoves) < MaxStopsPerRoute)
                    {
                        break;
                    }

                    targetDate = targetDate.AddDays(1);
                }

                stop.RouteId = targetRoute.Id;
                stop.StopSequence = await context.RouteStops
                    .CountAsync(item => item.RouteId == targetRoute.Id) + 1;
                affectedRouteIds.Add(route.Id);
                affectedRouteIds.Add(targetRoute.Id);
                await context.SaveChangesAsync();
            }
        }

        foreach (var routeId in affectedRouteIds)
        {
            await OptimizeRouteAsync(context, routeId);
        }

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
