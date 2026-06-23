using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WasteGlassAPI.Data;

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
}
