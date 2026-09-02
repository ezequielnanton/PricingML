namespace PricingApi.Models;

public class EstrategiaReglaDto
{
    public int EstrategiaReglaID { get; set; }
    public int EstrategiaID { get; set; }
    public int ReglaID { get; set; }
    public int Prioridad { get; set; }
    public string? ParametrosJSON { get; set; }
    public bool Activa { get; set; } = true;
}