using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.Models;
using WasteGlassAPI.Services;
using WasteGlassRoute = WasteGlassAPI.Models.Route;

namespace WasteGlassAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly AppDbContext _context;

    public AdminController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("suppliers")]
    public async Task<IActionResult> GetSuppliers()
    {
        var suppliers = await _context.Suppliers
            .OrderBy(item => item.SupplierId)
            .ToListAsync();

        return Ok(suppliers);
    }

    [HttpPut("suppliers/{supplierId}")]
    public async Task<IActionResult> UpdateSupplier(
        string supplierId,
        UpdateSupplierRequest request)
    {
        var normalizedSupplierId = supplierId.Trim().ToUpperInvariant();
        var supplier = await _context.Suppliers
            .FirstOrDefaultAsync(item => item.SupplierId == normalizedSupplierId);

        if (supplier is null)
        {
            return NotFound("Supplier not found.");
        }

        supplier.Name = request.Name.Trim();
        supplier.Location = request.Location.Trim();
        supplier.Latitude = request.Latitude;
        supplier.Longitude = request.Longitude;
        supplier.ExpectedKg = request.ExpectedKg;
        supplier.BarcodeValue = string.IsNullOrWhiteSpace(request.BarcodeValue)
            ? normalizedSupplierId
            : request.BarcodeValue.Trim().ToUpperInvariant();
        supplier.Status = request.Status.Trim();

        if (request.DistanceKm.HasValue)
        {
            var today = DateTime.Today;
            var routeStop = await _context.RouteStops
                .Include(item => item.Route)
                .FirstOrDefaultAsync(item =>
                    item.SupplierId == normalizedSupplierId &&
                    item.Route.RouteDate.Date == today);

            if (routeStop is not null)
            {
                routeStop.DistanceKm = request.DistanceKm.Value;
            }
        }

        await _context.SaveChangesAsync();

        return Ok(new { message = "Supplier updated successfully", supplierId = normalizedSupplierId });
    }

    [HttpDelete("suppliers/{supplierId}")]
    public async Task<IActionResult> DeleteSupplier(string supplierId)
    {
        var normalizedSupplierId = supplierId.Trim().ToUpperInvariant();
        var supplier = await _context.Suppliers
            .FirstOrDefaultAsync(item => item.SupplierId == normalizedSupplierId);

        if (supplier is null)
        {
            return NotFound("Supplier not found.");
        }

        var routeStops = await _context.RouteStops
            .Where(item => item.SupplierId == normalizedSupplierId)
            .ToListAsync();

        _context.RouteStops.RemoveRange(routeStops);
        _context.Suppliers.Remove(supplier);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Supplier deleted successfully", supplierId = normalizedSupplierId });
    }

    [HttpDelete("routes/today/stops/{supplierId}")]
    public async Task<IActionResult> RemoveSupplierFromTodayRoute(string supplierId)
    {
        var normalizedSupplierId = supplierId.Trim().ToUpperInvariant();
        var today = DateTime.Today;
        var route = await _context.Routes
            .FirstOrDefaultAsync(item => item.RouteDate.Date == today);

        if (route is null)
        {
            return NotFound("Today's route not found.");
        }

        var routeStops = await _context.RouteStops
            .Where(item =>
                item.RouteId == route.Id &&
                item.SupplierId == normalizedSupplierId)
            .ToListAsync();

        if (routeStops.Count == 0)
        {
            return NotFound("Route stop not found.");
        }

        _context.RouteStops.RemoveRange(routeStops);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Supplier removed from today's route", supplierId = normalizedSupplierId });
    }

    [HttpPost("add-supplier-to-route")]
    public async Task<IActionResult> AddSupplierToRoute(AddSupplierToRouteRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.SupplierId))
        {
            return BadRequest("Supplier ID is required.");
        }

        var supplierId = request.SupplierId.Trim().ToUpperInvariant();
        var supplier = await _context.Suppliers
            .FirstOrDefaultAsync(item => item.SupplierId == supplierId);

        if (supplier is null)
        {
            supplier = new Supplier
            {
                SupplierId = supplierId,
                Name = request.SupplierName.Trim(),
                Location = request.Location.Trim(),
                Latitude = 0,
                Longitude = 0,
                ExpectedKg = request.ExpectedKg,
                BarcodeValue = string.IsNullOrWhiteSpace(request.BarcodeValue)
                    ? supplierId
                    : request.BarcodeValue.Trim().ToUpperInvariant(),
                Status = "Pending"
            };

            _context.Suppliers.Add(supplier);
            await _context.SaveChangesAsync();
        }

        // Use the requested date (default today) as the starting point for placement
        var requestedDate = request.RouteDate.HasValue
            ? request.RouteDate.Value.Date
            : DateTime.Today;

        await RouteScheduler.NormalizeRouteOverflowAsync(_context);

        // Find the first available date on or after the requested date
        var targetDate = await RouteScheduler.FindAvailableRouteDateStartingFrom(
            _context, requestedDate);
        var route = await RouteScheduler.FindOrCreateRouteForDateAsync(_context, targetDate);

        var stopCount = await _context.RouteStops
            .CountAsync(item => item.RouteId == route.Id);
        var stopSequence = stopCount + 1;

        var routeStop = await _context.RouteStops.FirstOrDefaultAsync(item =>
            item.RouteId == route.Id &&
            item.SupplierId == supplierId);

        if (routeStop is null)
        {
            routeStop = new RouteStop
            {
                RouteId = route.Id,
                SupplierId = supplierId,
                StopSequence = stopSequence,
                DistanceKm = request.DistanceKm,
                Status = "Pending"
            };

            _context.RouteStops.Add(routeStop);
        }
        else
        {
            routeStop.StopSequence = stopSequence;
            routeStop.DistanceKm = request.DistanceKm;
        }

        await _context.SaveChangesAsync();
        await RouteScheduler.NormalizeRouteOverflowAsync(_context);

        return Ok(new
        {
            message = "Supplier added successfully",
            supplierId,
            routeId = route.Id,
            routeStopId = routeStop.Id,
            routeDate = route.RouteDate.ToString("yyyy-MM-dd"),
            stopSequence = routeStop.StopSequence
        });
    }

    [HttpPost("normalize-routes")]
    public async Task<IActionResult> NormalizeRoutes()
    {
        await RouteScheduler.NormalizeRouteOverflowAsync(_context);
        return Ok(new { message = "Routes normalized successfully" });
    }

    [HttpPost("reset-demo-data")]
    public async Task<IActionResult> ResetDemoData()
    {
        // Wipe everything so no stale statuses can bleed across dates
        _context.CollectionRecords.RemoveRange(await _context.CollectionRecords.ToListAsync());
        _context.RouteStops.RemoveRange(await _context.RouteStops.ToListAsync());
        _context.Routes.RemoveRange(await _context.Routes.ToListAsync());

        // Reset all supplier statuses to Pending
        var suppliers = await _context.Suppliers.ToListAsync();
        foreach (var supplier in suppliers)
        {
            supplier.Status = "Pending";
        }

        await EnsureDemoSuppliersAsync();
        await _context.SaveChangesAsync();

        // Create a fresh route for today only
        var todayRoute = new WasteGlassRoute
        {
            RouteDate = DateTime.Today,
            DriverName = "Collector 01",
            Status = "Active"
        };

        _context.Routes.Add(todayRoute);
        await _context.SaveChangesAsync();

        var demoStopSupplierIds = new[] { "SUP001", "SUP002", "SUP003", "SUP004", "SUP005" };

        for (var index = 0; index < demoStopSupplierIds.Length; index++)
        {
            _context.RouteStops.Add(new RouteStop
            {
                RouteId = todayRoute.Id,
                SupplierId = demoStopSupplierIds[index],
                StopSequence = index + 1,
                DistanceKm = index + 1,
                Status = "Pending"  // Always Pending — never inherit old status
            });
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Demo data reset successfully",
            routeId = todayRoute.Id,
            routeDate = todayRoute.RouteDate.ToString("yyyy-MM-dd"),
            stopCount = demoStopSupplierIds.Length
        });
    }

    [HttpPost("clear-all-trip-data")]
    public async Task<IActionResult> ClearAllTripData()
    {
        _context.CollectionRecords.RemoveRange(await _context.CollectionRecords.ToListAsync());
        _context.RouteStops.RemoveRange(await _context.RouteStops.ToListAsync());
        _context.Routes.RemoveRange(await _context.Routes.ToListAsync());

        var suppliers = await _context.Suppliers.ToListAsync();
        foreach (var supplier in suppliers)
        {
            supplier.Status = "Pending";
        }

        await _context.SaveChangesAsync();

        return Ok(new { message = "All trip data cleared. Suppliers reset to Pending." });
    }

    private async Task EnsureDemoSuppliersAsync()
    {
        var demoSuppliers = new List<Supplier>
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

        foreach (var demoSupplier in demoSuppliers)
        {
            var existingSupplier = await _context.Suppliers
                .FirstOrDefaultAsync(item => item.SupplierId == demoSupplier.SupplierId);

            if (existingSupplier is null)
            {
                _context.Suppliers.Add(demoSupplier);
                continue;
            }

            existingSupplier.Name = demoSupplier.Name;
            existingSupplier.Location = demoSupplier.Location;
            existingSupplier.Latitude = demoSupplier.Latitude;
            existingSupplier.Longitude = demoSupplier.Longitude;
            existingSupplier.ExpectedKg = demoSupplier.ExpectedKg;
            existingSupplier.BarcodeValue = demoSupplier.BarcodeValue;
            existingSupplier.Status = "Pending";
        }
    }
}

public class AddSupplierToRouteRequest
{
    public string SupplierId { get; set; } = string.Empty;
    public string SupplierName { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public double ExpectedKg { get; set; }
    public double DistanceKm { get; set; }
    public string BarcodeValue { get; set; } = string.Empty;
    /// <summary>Optional target date (yyyy-MM-dd). Defaults to today when null.</summary>
    public DateTime? RouteDate { get; set; }
}

public class UpdateSupplierRequest
{
    public string Name { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double ExpectedKg { get; set; }
    public double? DistanceKm { get; set; }
    public string BarcodeValue { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
