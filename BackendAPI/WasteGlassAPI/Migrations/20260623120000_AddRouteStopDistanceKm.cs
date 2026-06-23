using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace WasteGlassAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddRouteStopDistanceKm : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "DistanceKm",
                table: "RouteStops",
                type: "REAL",
                nullable: false,
                defaultValue: 0.0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DistanceKm",
                table: "RouteStops");
        }
    }
}
