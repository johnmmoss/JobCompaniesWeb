using System.ComponentModel.DataAnnotations;

namespace JobCompaniesWeb.Entities;

public class Company
{
    public int Id { get; set; }

    [Required]
    [StringLength(500)]
    public string Name { get; set; } = string.Empty;

    [StringLength(500)]
    public string? CareersPageUrl { get; set; }
    
    [StringLength(500)]
    public string? WebsiteUrl { get; set; }

    [StringLength(2000)]
    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}