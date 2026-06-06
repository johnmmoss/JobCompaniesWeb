using JobCompaniesWeb.Entities;
using Microsoft.EntityFrameworkCore;

namespace JobCompaniesWeb;

public class JobCompaniesDbContext : DbContext
{
    public JobCompaniesDbContext(DbContextOptions<JobCompaniesDbContext> options) : base(options) { }

    public DbSet<Company> Companies => Set<Company>();
}
