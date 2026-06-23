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
        var suppliers = await _context.Suppliers
            .OrderBy(supplier => supplier.SupplierId)
            .ToListAsync();

        var records = await _context.CollectionRecords.ToListAsync();

        var supplierSummaries = suppliers.Select(supplier =>
        {
            var collectedKg = records
                .Where(record => record.SupplierId == supplier.SupplierId)
                .Sum(record => record.ClearKg + record.ColoredKg);

            return new SupplierSummaryDto
            {
                SupplierId = supplier.SupplierId,
                Name = supplier.Name,
                ExpectedKg = supplier.ExpectedKg,
                CollectedKg = collectedKg,
                Status = collectedKg > 0 ? "Collected" : supplier.Status
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
