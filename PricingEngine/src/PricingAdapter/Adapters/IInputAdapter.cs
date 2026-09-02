using System.Text.Json;
using PricingAdapter.Models;

namespace PricingAdapter.Adapters;

public interface IInputAdapter
{
    string SourceName { get; }
    bool CanHandle(string sourceType);
    ProductoInput Map(JsonElement payload);
}
