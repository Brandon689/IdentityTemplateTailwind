param (
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [Parameter(Mandatory=$true)]
    [ValidateSet("sqlite", "sqlserver", "postgres", "mysql")]
    [string]$DbProvider
)

# Create new webapp
Write-Host "Creating new webapp: $ProjectName"
dotnet new webapp -n $ProjectName

# Change to project directory
Set-Location -Path $ProjectName

# Add necessary packages
$packages = @(
    "Microsoft.AspNetCore.Identity.EntityFrameworkCore",
    "Microsoft.AspNetCore.Identity.UI",
    "Microsoft.EntityFrameworkCore.Tools",
    "Microsoft.VisualStudio.Web.CodeGeneration.Design"
)

# Add database provider specific package
switch ($DbProvider) {
    "sqlite" { $packages += "Microsoft.EntityFrameworkCore.Sqlite" }
    "sqlserver" { $packages += "Microsoft.EntityFrameworkCore.SqlServer" }
    "postgres" { $packages += "Npgsql.EntityFrameworkCore.PostgreSQL" }
    "mysql" { $packages += "Pomelo.EntityFrameworkCore.MySql" }
}
#mysql is not available i believe
foreach ($package in $packages) {
    Write-Host "Adding package: $package"
    dotnet add package $package --version "*-*"
}

# Create Data folder
New-Item -ItemType Directory -Path "Data" -Force

# Create ApplicationDbContext.cs file
$contextContent = @"
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace $ProjectName.Data;

public class ApplicationDbContext : IdentityDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }
}
"@

Set-Content -Path "Data\ApplicationDbContext.cs" -Value $contextContent

Write-Host "Created Data folder and ApplicationDbContext.cs file" -ForegroundColor Green

# Replace Program.cs contents
$dbContextSetup = switch ($DbProvider) {
    "Sqlite" { "options.UseSqlite(connectionString)" }
    "SqlServer" { "options.UseSqlServer(connectionString)" }
    "PostgreSQL" { "options.UseNpgsql(connectionString)" }
    "MySQL" { "options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString))" }
}

$programContent = @"
using $ProjectName.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    $dbContextSetup);

builder.Services.AddDefaultIdentity<IdentityUser>(options => options.SignIn.RequireConfirmedAccount = true)
    .AddEntityFrameworkStores<ApplicationDbContext>();
builder.Services.AddRazorPages();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapRazorPages();

app.Run();
"@

Set-Content -Path "Program.cs" -Value $programContent

Write-Host "Updated Program.cs" -ForegroundColor Green

# Replace appsettings.json contents
$connectionString = switch ($DbProvider) {
    "Sqlite" { "Data Source=app.db" }
    "SqlServer" { "Server=(localdb)\\mssqllocaldb;Database=$ProjectName;Trusted_Connection=True;MultipleActiveResultSets=true" }
    "PostgreSQL" { "Host=localhost;Database=$ProjectName;Username=your_username;Password=your_password" }
    "MySQL" { "Server=localhost;Database=$ProjectName;User=your_username;Password=your_password;" }
}

$appsettingsContent = @"
{
  "ConnectionStrings": {
    "DefaultConnection": "$connectionString"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@

Set-Content -Path "appsettings.json" -Value $appsettingsContent

Write-Host "Updated appsettings.json" -ForegroundColor Green

# Edit _Layout.cshtml
$layoutPath = "Pages\Shared\_Layout.cshtml"
$layoutContent = Get-Content -Path $layoutPath -Raw

# Find the closing </ul> tag within the navbar
$ulCloseIndex = $layoutContent.IndexOf("</ul>", $layoutContent.IndexOf('<ul class="navbar-nav flex-grow-1">'))

if ($ulCloseIndex -ne -1) {
    # Insert the partial tag after the closing </ul> tag
    $newContent = $layoutContent.Insert($ulCloseIndex + 6, "`r`n                        <partial name=`"_LoginPartial`" />")
    
    # Save the modified content back to the file
    Set-Content -Path $layoutPath -Value $newContent
    
    Write-Host "Updated _Layout.cshtml with _LoginPartial after </ul>" -ForegroundColor Green
} else {
    Write-Host "Could not find the appropriate </ul> in _Layout.cshtml. Manual edit may be required." -ForegroundColor Yellow
}


# Add migration and update database
Write-Host "Adding migration: CreateIdentitySchema"
dotnet ef migrations add CreateIdentitySchema

Write-Host "Updating database"
dotnet ef database update

# Generate Identity UI
$dbContextName = "$ProjectName.Data.ApplicationDbContext"
Write-Host "Generating Identity UI"
dotnet aspnet-codegenerator identity -dbProvider $DbProvider -dc $dbContextName

Write-Host "Script completed successfully!" -ForegroundColor Green
