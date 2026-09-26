"""Send plain-text email over SMTP. The only non-Jac source file (see interop/README.md).

Configured by environment: SMTP_HOST, SMTP_PORT (default 587), SMTP_USER,
SMTP_PASSWORD, SMTP_FROM. With no SMTP_HOST, send() does nothing and returns False.
UARRIVED_EMAIL_OUTBOX=<path> writes each email as a JSON line to that file instead
(demos and tests); it takes precedence over SMTP.
"""

import json
import os
import smtplib
from email.message import EmailMessage


def configured() -> bool:
    return bool(os.environ.get("UARRIVED_EMAIL_OUTBOX") or os.environ.get("SMTP_HOST"))


def send(to: str, subject: str, body: str) -> bool:
    outbox = os.environ.get("UARRIVED_EMAIL_OUTBOX")
    if outbox:
        with open(outbox, "a", encoding="utf-8") as f:
            f.write(json.dumps({"to": to, "subject": subject, "body": body}) + "\n")
        return True
    if not os.environ.get("SMTP_HOST"):
        return False
    msg = EmailMessage()
    msg["From"] = os.environ.get("SMTP_FROM", os.environ.get("SMTP_USER", ""))
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)
    port = int(os.environ.get("SMTP_PORT", "587"))
    with smtplib.SMTP(os.environ["SMTP_HOST"], port, timeout=15) as smtp:
        smtp.starttls()
        if os.environ.get("SMTP_USER"):
            smtp.login(os.environ["SMTP_USER"], os.environ.get("SMTP_PASSWORD", ""))
        smtp.send_message(msg)
    return True
