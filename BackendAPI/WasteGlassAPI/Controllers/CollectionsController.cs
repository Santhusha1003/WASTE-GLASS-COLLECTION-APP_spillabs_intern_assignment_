using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.DTOs;
using WasteGlassAPI.Models;

namespace WasteGlassAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CollectionsController : ControllerBase
{
    private readonly AppDbContext _context;

    public CollectionsController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetCollections()
    {
        var records = await _context.CollectionRecords
            .OrderByDescending(record => record.Timestamp)
            .ToListAsync();

        return Ok(records);
    }

    [HttpPost]
    public async Task<IActionResult> CreateCollection(CollectionRecordCreateDto request)
    {
        if (string.IsNullOrWhiteSpace(request.SupplierId))
        {
            return BadRequest("supplierId is required.");
        }

        if (string.IsNullOrWhiteSpace(request.Condition))
        {
            return BadRequest("condition is required.");
        }

        var supplierId = request.SupplierId.Trim().ToUpperInvariant();
        var today = DateTime.Today.Date;
        var todayRoute = await _context.Routes
            .FirstOrDefaultAsync(route => route.RouteDate.Date == today);

        if (todayRoute is null)
        {
            return NotFound("No route found for today.");
        }

        var routeStop = await _context.RouteStops
            .FirstOrDefaultAsync(stop =>
                stop.RouteId == todayRoute.Id &&
                stop.SupplierId == supplierId);

        if (routeStop is null)
        {
            return NotFound($"Supplier {supplierId} is not a stop on today's route.");
        }

        var record = new CollectionRecord
        {
            SupplierId = supplierId,
            ClearKg = request.ClearKg,
            ColoredKg = request.ColoredKg,
            Condition = request.Condition.Trim(),
            Timestamp = request.Timestamp == default ? DateTime.UtcNow : request.Timestamp,
            RouteDate = today
        };

        _context.CollectionRecords.Add(record);
        routeStop.Status = "Collected";

        await _context.SaveChangesAsync();

        return Ok(new
        {
            success = true,
            supplierId,
            status = "Collected",
            message = "Collection saved successfully"
        });
    }
}
