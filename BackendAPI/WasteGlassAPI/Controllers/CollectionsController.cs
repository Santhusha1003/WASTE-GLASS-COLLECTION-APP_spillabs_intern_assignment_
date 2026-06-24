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

        var record = new CollectionRecord
        {
            SupplierId = request.SupplierId.Trim().ToUpperInvariant(),
            ClearKg = request.ClearKg,
            ColoredKg = request.ColoredKg,
            Condition = request.Condition.Trim(),
            Timestamp = request.Timestamp == default ? DateTime.UtcNow : request.Timestamp
        };

        _context.CollectionRecords.Add(record);

        // Update only today's matching RouteStop; past and future stops are untouched.
        var today = DateTime.Today;
        var routeStop = await _context.RouteStops
            .Include(item => item.Route)
            .FirstOrDefaultAsync(item =>
                item.SupplierId == record.SupplierId &&
                item.Route.RouteDate.Date == today);

        if (routeStop is not null)
        {
            routeStop.Status = "Collected";

            var supplier = await _context.Suppliers
                .FirstOrDefaultAsync(item => item.SupplierId == record.SupplierId);
            if (supplier is not null)
            {
                supplier.Status = "Collected";
            }
        }

        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetCollections), new { id = record.Id }, record);
    }
}
