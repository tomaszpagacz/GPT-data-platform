using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection;
using LocationIntelligence.Services;

[assembly: FunctionsStartup(typeof(LocationIntelligence.Startup))]

namespace LocationIntelligence
{
    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder builder)
        {
            builder.Services.AddHttpClient<IAzureMapsService, AzureMapsService>();
        }
    }
}