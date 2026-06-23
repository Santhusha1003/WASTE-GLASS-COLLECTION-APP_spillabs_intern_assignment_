namespace WasteGlassAPI.DTOs;

public class CollectionRecordCreateDto
{
    public string SupplierId { get; set; } = string.Empty;
    public double ClearKg { get; set; }
    public double ColoredKg { get; set; }
    public string Condition { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
}
