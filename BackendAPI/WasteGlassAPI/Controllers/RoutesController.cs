using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.Services;
using WasteGlassRoute = WasteGlassAPI.Models.Route;

namespace WasteGlassAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class RoutesController : ControllerBase
{
    private readonly AppDbContext _context;

    public RoutesController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("today")]
    public async Task<IActionResult> GetTodayRoute()
    {
        await RouteScheduler.RebalanceRoutesAsync(_context);

        var today = DateTime.Today;
        var route = await _context.Routes
            .Include(item => item.RouteStops)
            .ThenInclude(stop => stop.Supplier)
            .FirstOrDefaultAsync(item => item.RouteDate.Date == today);

        if (route is null)
        {
            return NotFound("No active route found for today.");
        }

        return Ok(BuildRouteResponse(route));
    }

    [HttpGet("date/{date}")]
    public async Task<IActionResult> GetRouteByDate(string date)
    {
        if (!DateTime.TryParse(date, out var routeDate))
        {
            return BadRequest("Invalid date. Use YYYY-MM-DD.");
        }

        await RouteScheduler.RebalanceRoutesAsync(_context);

        var route = await _context.Routes
            .Include(item => item.RouteStops)
            .ThenInclude(stop => stop.Supplier)
            .FirstOrDefaultAsync(item => item.RouteDate.Date == routeDate.Date);

        if (route is null)
        {
            return NotFound("No route found for selected date.");
        }

        return Ok(BuildRouteResponse(route));
    }

    private static object BuildRouteResponse(WasteGlassRoute route)
    {
        return new
        {
            routeId = route.Id,
            routeDate = route.RouteDate,
            driverName = route.DriverName,
            status = route.Status,
            stops = route.RouteStops
                .OrderBy(stop => stop.StopSequence)
                .Select(stop => new
                {
                    stopSequence = stop.StopSequence,
                    supplierId = stop.SupplierId,
                    name = stop.Supplier.Name,
                    location = stop.Supplier.Location,
                    latitude = stop.Supplier.Latitude,
                    longitude = stop.Supplier.Longitude,
                    expectedKg = stop.Supplier.ExpectedKg,
                    barcodeValue = stop.Supplier.BarcodeValue,
                    status = stop.Status
                })
        };
    }
}
