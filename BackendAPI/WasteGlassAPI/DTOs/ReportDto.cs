namespace WasteGlassAPI.DTOs;

public class ReportDto
{
    public double TotalCollected { get; set; }
    public double TotalExpected { get; set; }
    public List<SupplierSummaryDto> SupplierSummaries { get; set; } = [];
    public List<ShortfallDto> Shortfalls { get; set; } = [];
}

public class SupplierSummaryDto
{
    public string SupplierId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public double ExpectedKg { get; set; }
    public double CollectedKg { get; set; }
    public string Status { get; set; } = string.Empty;
}

public class ShortfallDto
{
    public string SupplierId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public double ExpectedKg { get; set; }
    public double CollectedKg { get; set; }
    public double ShortfallKg { get; set; }
}
