using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.Models;

namespace WasteGlassAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SuppliersController : ControllerBase
{
    private readonly AppDbContext _context;

    public SuppliersController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetSuppliers()
    {
        var suppliers = await _context.Suppliers
            .OrderBy(supplier => supplier.SupplierId)
            .ToListAsync();

        return Ok(suppliers);
    }

    [HttpGet("today")]
    public async Task<IActionResult> GetTodaySuppliers()
    {
        var suppliers = await _context.Suppliers
            .OrderBy(supplier => supplier.SupplierId)
            .ToListAsync();

        return Ok(suppliers);
    }

    [HttpPut("{supplierId}")]
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

        RouteStop? routeStop = null;
        if (request.DistanceKm.HasValue)
        {
            var today = DateTime.Today;
            routeStop = await _context.RouteStops
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

        return Ok(new
        {
            message = "Supplier updated successfully",
            supplier = new
            {
                supplier.SupplierId,
                supplier.Name,
                supplier.Location,
                supplier.Latitude,
                supplier.Longitude,
                supplier.ExpectedKg,
                supplier.BarcodeValue,
                supplier.Status,
                distanceKm = routeStop?.DistanceKm
            }
        });
    }
}
