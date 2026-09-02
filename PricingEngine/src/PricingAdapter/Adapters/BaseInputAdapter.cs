using System.Globalization;
using System.Text.Json;
using PricingAdapter.Models;

namespace PricingAdapter.Adapters;

public abstract class BaseInputAdapter : IInputAdapter
{
    public abstract string SourceName { get; }

    public bool CanHandle(string sourceType)
    {
        return string.Equals(sourceType, SourceName, StringComparison.OrdinalIgnoreCase);
    }

    public abstract ProductoInput Map(JsonElement payload);

    protected static bool TryGetProperty(JsonElement element, string key, out JsonElement value)
    {
        foreach (var property in element.EnumerateObject())
        {
            if (string.Equals(property.Name, key, StringComparison.OrdinalIgnoreCase))
            {
                value = property.Value;
                return true;
            }
        }

        value = default;
        return false;
    }

    protected static string ReadString(JsonElement element, string key, string defaultValue = "")
    {
        if (TryGetProperty(element, key, out var value) && value.ValueKind != JsonValueKind.Null)
        {
            return value.ToString().Trim();
        }

        return defaultValue;
    }

    protected static decimal ReadDecimal(JsonElement element, string key, decimal defaultValue = 0m)
    {
        if (TryGetProperty(element, key, out var value) && value.ValueKind != JsonValueKind.Null)
        {
            if (decimal.TryParse(
                    value.ToString(),
                    NumberStyles.Number,
                    CultureInfo.InvariantCulture,
                    out var parsed))
            {
                return parsed;
            }
        }

        return defaultValue;
    }

    protected static int ReadInt(JsonElement element, string key, int defaultValue = 0)
    {
        if (TryGetProperty(element, key, out var value) && value.ValueKind != JsonValueKind.Null)
        {
            if (int.TryParse(value.ToString(), out var parsed))
            {
                return parsed;
            }
        }

        return defaultValue;
    }

    protected static string NormalizeSku(string sku)
    {
        return sku.Trim().ToUpperInvariant();
    }

    protected static DateTime GetFechaCaptura(JsonElement element)
    {
        if (element.TryGetProperty("fechaCaptura", out var value) && value.ValueKind != JsonValueKind.Null)
        {
            if (DateTime.TryParse(value.ToString(), out var fecha))
            {
                return fecha;
            }
        }

        return DateTime.UtcNow;
    }
}
