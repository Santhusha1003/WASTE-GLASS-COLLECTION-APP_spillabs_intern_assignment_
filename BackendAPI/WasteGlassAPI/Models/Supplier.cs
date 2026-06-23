namespace WasteGlassAPI.Models;

public class Supplier
{
    public int Id { get; set; }
    public string SupplierId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double ExpectedKg { get; set; }
    public string BarcodeValue { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}
