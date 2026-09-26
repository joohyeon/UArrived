# interop/ — the ONLY place non-Jac source code is allowed

Small Python (or other) shims for things Jac cannot do directly (e.g. a third-party SDK). Keep each
file tiny and wrap it behind a Jac interface. Everything here counts *against* the 40% Jac floor.
