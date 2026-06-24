using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.Models;
using WasteGlassAPI.Services;

namespace WasteGlassAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SuppliersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly RouteScheduler _routeScheduler;

    public SuppliersController(AppDbContext context, RouteScheduler routeScheduler)
    {
        _context = context;
        _routeScheduler = routeScheduler;
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

        await _context.SaveChangesAsync();

        var routeIds = await _context.RouteStops
            .Where(item => item.SupplierId == normalizedSupplierId)
            .Select(item => item.RouteId)
            .Distinct()
            .ToListAsync();
        foreach (var routeId in routeIds)
        {
            await _routeScheduler.OptimizeRouteAsync(routeId);
        }

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
                supplier.Status
            }
        });
    }
}
