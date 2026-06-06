using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using JobCompaniesWeb;
using JobCompaniesWeb.Entities;

namespace JobCompaniesWeb.Pages.Companies
{
    public class IndexModel : PageModel
    {
        private readonly JobCompaniesWeb.JobCompaniesDbContext _context;

        public IndexModel(JobCompaniesWeb.JobCompaniesDbContext context)
        {
            _context = context;
        }

        public IList<Company> Company { get;set; } = default!;

        public async Task OnGetAsync()
        {
            Company = await _context.Companies.ToListAsync();
        }
    }
}
