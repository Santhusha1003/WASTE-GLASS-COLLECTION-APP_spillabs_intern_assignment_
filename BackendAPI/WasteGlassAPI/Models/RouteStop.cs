namespace WasteGlassAPI.Models;

public class RouteStop
{
    public int Id { get; set; }
    public int RouteId { get; set; }
    public Route Route { get; set; } = null!;
    public string SupplierId { get; set; } = string.Empty;
    public Supplier Supplier { get; set; } = null!;
    public int StopSequence { get; set; }
    public string Status { get; set; } = string.Empty;
}
