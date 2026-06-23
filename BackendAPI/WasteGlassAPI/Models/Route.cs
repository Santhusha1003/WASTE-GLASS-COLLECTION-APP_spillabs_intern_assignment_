namespace WasteGlassAPI.Models;

public class Route
{
    public int Id { get; set; }
    public DateTime RouteDate { get; set; }
    public string DriverName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public List<RouteStop> RouteStops { get; set; } = [];
}
