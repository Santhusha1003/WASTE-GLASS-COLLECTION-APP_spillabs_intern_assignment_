using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;
using WasteGlassAPI.DTOs;

namespace WasteGlassAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReportController : ControllerBase
{
    private readonly AppDbContext _context;

    public ReportController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<ReportDto>> GetReport()
    {
        var today = DateTime.Today;
        var route = await _context.Routes
            .AsNoTracking()
            .Include(item => item.RouteStops)
                .ThenInclude(routeStop => routeStop.Supplier)
            .FirstOrDefaultAsync(item => item.RouteDate.Date == today);

        if (route is null)
        {
            return Ok(new ReportDto());
        }

        var records = await _context.CollectionRecords
            .AsNoTracking()
            .Where(record => record.RouteDate.Date == today)
            .ToListAsync();

        var supplierSummaries = route.RouteStops
            .OrderBy(routeStop => routeStop.StopSequence)
            .Where(routeStop => routeStop.Supplier is not null)
            .Select(routeStop =>
            {
                var supplier = routeStop.Supplier;
                var collectedKg = records
                    .Where(record => record.SupplierId == routeStop.SupplierId)
                    .Sum(record => record.ClearKg + record.ColoredKg);

                // Status from RouteStop, not global Supplier.Status
                var status = string.Equals(
                        routeStop.Status,
                        "Collected",
                        StringComparison.OrdinalIgnoreCase) ? "Collected"
                    : collectedKg > 0 ? "Collected"
                    : "Pending";

                return new SupplierSummaryDto
                {
                    SupplierId = routeStop.SupplierId,
                    Name = supplier.Name,
                    ExpectedKg = supplier.ExpectedKg,
                    CollectedKg = collectedKg,
                    Status = status
                };
            }).ToList();

        var shortfalls = supplierSummaries
            .Where(summary => summary.CollectedKg < summary.ExpectedKg)
            .Select(summary => new ShortfallDto
            {
                SupplierId = summary.SupplierId,
                Name = summary.Name,
                ExpectedKg = summary.ExpectedKg,
                CollectedKg = summary.CollectedKg,
                ShortfallKg = summary.ExpectedKg - summary.CollectedKg
            })
            .ToList();

        var report = new ReportDto
        {
            TotalCollected = supplierSummaries.Sum(summary => summary.CollectedKg),
            TotalExpected = supplierSummaries.Sum(summary => summary.ExpectedKg),
            SupplierSummaries = supplierSummaries,
            Shortfalls = shortfalls
        };

        return Ok(report);
    }
}
