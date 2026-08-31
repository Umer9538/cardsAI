import type { Env } from "./env.js";

/**
 * Transactional email, over HTTP.
 *
 * This is the one deliberate behaviour change in the port. The Cloud Function
 * sent mail over plain SMTP with nodemailer, chosen so any provider would work
 * and switching would be a secret change rather than a code change. Workers
 * cannot do that: there is no nodemailer, and raw SMTP is not something to
 * attempt from the edge.
 *
 * The spirit is kept by putting the entire provider surface in this one
 * function. Brevo is the default because it was already the suggested provider
 * and its free tier (300/day, no expiry) is unchanged over HTTP. Swapping to
 * Resend, Postmark or Mailgun means editing the fetch below and nothing else.
 */

interface Mail {
  to: string;
  subject: string;
  text: string;
  html: string;
}

/** Splits `"Carbsai <no-reply@x>"` into its parts; a bare address also works. */
function sender(from: string): { name: string; email: string } {
  const match = /^\s*(.*?)\s*<([^>]+)>\s*$/.exec(from);
  if (match) return { name: match[1] || "Carbsai", email: match[2] };
  return { name: "Carbsai", email: from.trim() };
}

export async function sendEmail(env: Env, mail: Mail): Promise<void> {
  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": env.EMAIL_API_KEY,
      "content-type": "application/json",
      accept: "application/json",
    },
    body: JSON.stringify({
      sender: sender(env.EMAIL_FROM),
      to: [{ email: mail.to }],
      subject: mail.subject,
      textContent: mail.text,
      htmlContent: mail.html,
    }),
  });

  if (!response.ok) {
    // The body can name the account or the domain, so it is logged rather than
    // returned. The caller turns this into a sentence the user can act on.
    throw new Error(`email send failed ${response.status}: ${await response.text()}`);
  }
}
