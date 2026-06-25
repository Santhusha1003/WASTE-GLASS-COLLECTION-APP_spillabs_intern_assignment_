namespace WasteGlassAPI.Models;

public class CollectionRecord
{
    public int Id { get; set; }
    public string SupplierId { get; set; } = string.Empty;
    public double ClearKg { get; set; }
    public double ColoredKg { get; set; }
    public string Condition { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
    public DateTime RouteDate { get; set; }
}
