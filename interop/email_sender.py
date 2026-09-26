"""Send plain-text email over SMTP. The only non-Jac source file (see interop/README.md).

Configured by environment: SMTP_HOST, SMTP_PORT (default 587), SMTP_USER,
SMTP_PASSWORD, SMTP_FROM. With no SMTP_HOST, send() does nothing and returns False.
"""

import os
import smtplib
from email.message import EmailMessage


def configured() -> bool:
    return bool(os.environ.get("SMTP_HOST"))


def send(to: str, subject: str, body: str) -> bool:
    if not configured():
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
