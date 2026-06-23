using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.Models;
using WasteGlassAPI.Services;

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
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                ExpectedKg = request.ExpectedKg,
                BarcodeValue = string.IsNullOrWhiteSpace(request.BarcodeValue)
                    ? supplierId
                    : request.BarcodeValue.Trim().ToUpperInvariant(),
                Status = "Pending"
            };

            _context.Suppliers.Add(supplier);
            await _context.SaveChangesAsync();
        }

        await RouteScheduler.RebalanceRoutesAsync(_context);

        var route = await RouteScheduler.FindAvailableRouteAsync(_context);
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
                Status = "Pending"
            };

            _context.RouteStops.Add(routeStop);
        }
        else
        {
            routeStop.StopSequence = stopSequence;
        }

        await _context.SaveChangesAsync();

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

}

public class AddSupplierToRouteRequest
{
    public string SupplierId { get; set; } = string.Empty;
    public string SupplierName { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double ExpectedKg { get; set; }
    public string BarcodeValue { get; set; } = string.Empty;
}

public class UpdateSupplierRequest
{
    public string Name { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double ExpectedKg { get; set; }
    public string BarcodeValue { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
