using System.Net.Mail;
using System.Net;
using Microsoft.AspNetCore.Identity.UI.Services;

namespace IdentityTemplateTailwind.Services;

public class EmailSender : IEmailSender
{
    private readonly IConfiguration _configuration;

    public EmailSender(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task SendEmailAsync(string email, string subject, string htmlMessage)
    {
        // SendEmailAsync(email, subject, htmlMessage);
        // integrate with a mail service. There are not any easy and free services, because of spam abuse.
        // its possible to get smtp credentials from gmail or outlook but it is locked down a lot for security and is not usable in production.
    }
}
