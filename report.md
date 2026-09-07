# Hospital Outpatient Management System — Practicum Report

## I. Practicum Requirements

The goal of this practicum was to design and implement a relational database-backed information system for a hospital outpatient department, and to expose that database through a working web application. The system had to satisfy the following requirements:

1. **Model the full outpatient workflow** in a normalized relational schema: departments, doctors, patients, system users, appointments, medical records, medicines, prescriptions, prescription line items, and bills.
2. **Enforce data integrity at the database layer**, not only in application code — through primary/foreign keys, `NOT NULL`/`UNIQUE` constraints, `ENUM` domains, and triggers that reject invalid state transitions (e.g., duplicate appointment bookings).
3. **Encapsulate multi-step business logic in stored procedures** so that operations spanning multiple tables (generating a bill, dispensing a prescription and deducting stock, processing a payment) execute atomically and consistently regardless of which client calls them.
4. **Provide reporting views** for the most common read patterns (today's appointments, unpaid bills, low-stock medicines, doctor workload) so the application layer can query pre-joined, pre-filtered data instead of duplicating join logic everywhere.
5. **Build a functional multi-user web front end** with authentication, role-based access control (admin, doctor, receptionist, pharmacist, cashier), and CRUD screens for every entity in the schema.
6. **Demonstrate the system with realistic seed data** covering every table, including at least one full patient journey from registration through payment.

## II. Database Design Process

### 2.1 High-Level Design

The domain naturally decomposes into four functional areas, each owning a cluster of entities:

- **Organizational data** — `departments` and `doctors`. Every doctor belongs to exactly one department (1:N), and a department cannot be deleted while it still has doctors (`ON DELETE RESTRICT`) to avoid orphaning staff records.
- **People** — `patients` and `users`. Patients are clinical subjects; `users` are the people who operate the system (staff accounts with a role). These are intentionally kept separate: a patient is never a login account, and a staff login is never treated as clinical data. This keeps the authentication surface small and avoids conflating "who is being treated" with "who is operating the software."
- **Clinical workflow** — `appointments` → `medical_records` → `prescriptions` → `prescription_details`. This is a linear pipeline: an appointment is the entry point (a patient asks to see a doctor at a time slot); a completed appointment produces a medical record (the doctor's findings); a medical record may produce one or more prescriptions; each prescription is a set of medicine line items. The chain is expressed with foreign keys at every step so that a prescription can always be traced back to the clinical encounter that justified it.
- **Commercial workflow** — `medicines` (inventory) and `bills` (billing/payment). `medicines` is deliberately decoupled from the clinical pipeline except through `prescription_details`, so stock levels and pricing can be managed independently by pharmacy staff. `bills` sits at the end of the pipeline, generated from a prescription's medicine total plus the treating doctor's consultation fee.

The high-level entity-relationship shape is:

```
departments 1───N doctors
doctors 1───N appointments N───1 patients
appointments 1───0..1 medical_records
medical_records 1───N prescriptions
prescriptions 1───N prescription_details N───1 medicines
prescriptions 1───0..1 bills
patients 1───N bills
users 1───N appointments (created_by, optional)
```

### 2.2 Detailed Design

**Normalization.** All ten tables are in third normal form. The clearest normalization decision is `prescription_details` as a junction table resolving the M:N relationship between `prescriptions` and `medicines`: a prescription can contain many medicines, and a given medicine appears on many prescriptions over time, so quantity, dosage, and the *price at the time of prescribing* (`unit_price`, `subtotal`) are stored on the junction row rather than duplicated or looked up live from `medicines` — this preserves a historically accurate bill even if the medicine's catalog price changes later.

**Referential integrity policy.** Foreign keys use different `ON DELETE` behaviors depending on what the relationship means:
- `CASCADE` where the child record has no independent meaning without the parent (a patient's appointments, medical records, prescriptions, and bills all cascade-delete with the patient).
- `RESTRICT` where the parent is a reference/master entity that should not silently disappear out from under historical records (deleting a department with active doctors, or a doctor with any appointments/records/prescriptions, is blocked).
- `SET NULL` where the link is informational, not load-bearing (`appointments.created_by`, `medical_records.appointment_id`, `bills.prescription_id`) — losing the source user account or the originating appointment/prescription shouldn't destroy the record it produced.

**Derived data lives in the database, not the app.** `prescriptions.total_amount` is never computed by application code; it is maintained by `trg_update_prescription_total` / `trg_update_prescription_total_update`, which recompute it as `SUM(subtotal)` over `prescription_details` every time a line item is inserted or updated. This guarantees the total is always consistent even if a future client bypasses the Flask app and writes to the database directly.

**Preventing invalid state at insert time.** `trg_check_duplicate_appointment` runs `BEFORE INSERT` on `appointments` and raises `SIGNAL SQLSTATE '45000'` if the same patient already has a `scheduled` appointment with the same doctor at the same date and time slot. This constraint could not be expressed as a plain `UNIQUE` index because it must only apply when `status = 'scheduled'` (a cancelled or completed slot should not block rebooking).

**Indexing strategy.** Beyond primary/foreign keys, indexes were added on every column used as a filter or join predicate in the application's hottest queries: `appointment_date`/`patient_id`/`doctor_id` on `appointments` (dashboard "today" queries, patient history, doctor schedules), `patient_id`/`doctor_id` on `medical_records`, `patient_id` on `prescriptions`, `patient_id`/`payment_status` on `bills` (unpaid-bills view), and `category`/`stock_quantity` on `medicines` (inventory filtering and the low-stock view).

**Business logic in stored procedures.** Eight procedures encapsulate operations that would otherwise require several round-trips and careful client-side transaction handling: `sp_generate_bill` (fee lookup + insert), `sp_process_payment` (guarded update), `sp_check_stock` (availability check), `sp_dispense_prescription` (cursor-driven stock deduction across all line items inside an explicit transaction, rolled back on any shortfall), `sp_patient_history`, `sp_daily_revenue` (two result sets: summary + payment-method breakdown), `sp_cancel_appointment` (state-validated cancellation), and `sp_search_available_doctors`.

## III. Design or Program Implementation

**Backend architecture.** The Flask application (`app.py`) is a single-module app using a request-scoped PyMySQL connection stored on `flask.g` and closed in a `teardown_appcontext` handler. Three thin helpers — `query_all`, `query_one`, `execute` — cover simple reads/writes, and a fourth, `call_proc`, wraps `cursor.callproc()` and loops over `cursor.nextset()` to collect every result set a stored procedure returns (needed for `sp_daily_revenue`, which returns a summary row and a breakdown table in one call). Multi-statement operations that must be atomic from the application side — creating a prescription together with its line items — use an explicit `connection.begin()` / `commit()` / `rollback()` block rather than relying on the connection's default autocommit mode.

**Authentication and authorization.** Passwords are hashed with Werkzeug's PBKDF2-SHA256 (`generate_password_hash` / `check_password_hash`); no plaintext password is ever stored or logged. Two decorators implement access control: `login_required` (any authenticated session) and `role_required(roles)` (a session whose role is in an allowed list), stacked on routes such as `/medical_records/add` (doctor/admin), `/medicines/add` (pharmacist/admin), `/bills/pay/<id>` (cashier/admin), and `/reports` (admin only). Templates additionally hide UI affordances (buttons, forms) that a user's role would not be permitted to submit, so the UI never advertises actions a user cannot complete.

**Stored procedure integration.** Every stored procedure with a client-facing purpose is called somewhere in the app: `sp_cancel_appointment` from the appointments page, `sp_patient_history` from the patient detail page, `sp_dispense_prescription` from the prescriptions page, `sp_generate_bill` and `sp_process_payment` from the billing flow, and `sp_daily_revenue` from the reports page. `sp_check_stock` and `sp_search_available_doctors` are exposed for direct SQL testing and through a small `/api/check_stock/<medicine_id>/<qty>` JSON endpoint, demonstrating that the database layer's logic is reusable outside the specific screens that were built around it.

**Frontend implementation.** All templates extend a shared `base.html` that renders a dark Bootstrap 5 sidebar (built with Bootstrap Icons), flash-message alerts, and a `session`-aware navigation menu (the "Reports" link only renders when `session.role == 'admin'`). Status values across the app (`scheduled`, `completed`, `pending`, `paid`, etc.) are rendered through a single `badge_class` Jinja filter mapping each status string to a Bootstrap color, so the color-coding rule lives in one place instead of being repeated per template. The appointment scheduling modal loads doctors dynamically: selecting a department fires a `fetch()` call to `/api/doctors_by_dept/<dept_id>`, which returns active doctors in that department as JSON, avoiding a full page reload and preventing patients from being assigned to inactive or out-of-department doctors.

**Data flow example — from prescription to paid bill.** A doctor submits the "New Prescription" form (`POST /prescriptions/add`), which inserts a `prescriptions` row and one `prescription_details` row per medicine line inside a single transaction; each line insert fires the total-recalculation trigger. A pharmacist then dispenses it (`POST /prescriptions/<id>/dispense`), which calls `sp_dispense_prescription` — this locks and decrements `medicines.stock_quantity` for every line item inside the procedure's own transaction, and rejects the whole operation with a `SIGNAL`-raised error (surfaced to the user as a flash message) if any line item lacks sufficient stock. A cashier generates the bill (`POST /bills/generate/<prescription_id>`, calling `sp_generate_bill`), which reads the doctor's consultation fee and the prescription's trigger-maintained total to insert a `bills` row. Finally, `POST /bills/pay/<id>` calls `sp_process_payment`, which flips the bill to `paid` only if it is currently `unpaid`, guarding against double payment.

## IV. Test Results

| # | Test Case | Steps | Expected Result | Actual Result |
|---|---|---|---|---|
| 1 | Valid login | Log in as `admin` / `admin123` | Redirected to dashboard, session established | Pass |
| 2 | Invalid login | Log in with a wrong password | "Invalid username or password" flash, stays on login page | Pass |
| 3 | Patient registration | Submit "Register Patient" with a new ID card number | Patient inserted, appears at top of patient list | Pass |
| 4 | Duplicate ID card rejected | Register a second patient with an existing `id_card` | `UNIQUE` constraint violation caught, friendly error flashed, no row inserted | Pass |
| 5 | AJAX doctor loading | Open "Schedule Appointment", select a department | Doctor dropdown populates via `/api/doctors_by_dept/<id>` with only active doctors in that department | Pass |
| 6 | Duplicate appointment blocked | Book the same patient with the same doctor at the same date/time slot twice | Second insert raises `SIGNAL SQLSTATE '45000'` from `trg_check_duplicate_appointment`; Flask flashes the trigger's message | Pass |
| 7 | Appointment cancellation | Cancel a `scheduled` appointment, then attempt to cancel it again | First call succeeds via `sp_cancel_appointment`; second call raises "Only scheduled appointments can be cancelled" | Pass |
| 8 | Prescription total auto-calculation | Add two medicine lines to a new prescription | `prescriptions.total_amount` equals the sum of both `subtotal` values without the app computing it directly | Pass |
| 9 | Role-restricted route | Log in as `reception1` and `POST` to `/medicines/add` | Redirected to dashboard with "You do not have permission..." flash; no row inserted | Pass |
| 10 | Dispense deducts stock | Dispense a pending prescription for a medicine with sufficient stock | `medicines.stock_quantity` decreases by the prescribed quantity; `prescriptions.status` becomes `dispensed` | Pass |
| 11 | Dispense blocked on insufficient stock | Dispense a prescription requesting more units than currently in stock | `sp_dispense_prescription` rolls back all deductions and raises "Insufficient stock..."; stock levels unchanged | Pass |
| 12 | Payment idempotency | Pay a bill via `/bills/pay/<id>`, then submit payment again for the same bill | First call marks it `paid`; second call raises "Bill not found or already paid" and the row is unaffected | Pass |

## V. Problems and Discussion

**Multi-statement procedures and result sets over PyMySQL.** `sp_daily_revenue` returns two independent `SELECT` result sets (a summary row and a payment-method breakdown). PyMySQL's cursor does not automatically advance between them — `cursor.fetchall()` only returns the first — so the `call_proc` helper explicitly loops with `cursor.nextset()` until it returns `False`, collecting every result set into a list. Without this, the reports page would silently show only the summary and drop the breakdown table.

**Choosing between triggers and application code for the running total.** Early on, `prescriptions.total_amount` was going to be computed in Python immediately after inserting all line items. This was rejected in favor of `AFTER INSERT`/`AFTER UPDATE` triggers on `prescription_details` because a total computed only by the application is trivially made stale by any other client (a future admin tool, a direct SQL fix, a second procedure) that touches `prescription_details` without also remembering to update the parent row. Moving the recalculation into a trigger makes it structurally impossible for the total to drift out of sync with its line items.

**Race conditions during stock deduction.** `sp_dispense_prescription` loops through every medicine line and must ensure that if *any* line lacks sufficient stock, *none* of the deductions for that prescription are applied. This required an explicit `START TRANSACTION` inside the procedure (rather than relying on the client's autocommit setting), a `SELECT ... FOR UPDATE` on each medicine row to avoid a lost-update race with a concurrent dispense of a different prescription touching the same medicine, and an `EXIT HANDLER FOR SQLEXCEPTION` that rolls back and re-signals so the caller still sees a meaningful error message instead of a bare rollback.

**Deciding what belongs in the fixed route list versus what the workflow actually needed.** The originally specified route list covers listing and viewing prescriptions but not creating or dispensing them, and covers paying a bill but not generating one. Building the app strictly to that list would leave `sp_generate_bill` and `sp_dispense_prescription` unreachable from the UI. Three additional routes (`POST /prescriptions/add`, `POST /prescriptions/<id>/dispense`, `POST /bills/generate/<prescription_id>`) were added, following the same naming conventions as the specified routes, so the full patient-to-payment journey is actually clickable end to end rather than only testable directly in SQL.

## VI. Summary and Reflections

This practicum reinforced that a relational schema is more than a container for rows — the constraints, triggers, and stored procedures are where the actual business rules of an outpatient clinic (no double-booking, prescription totals must reconcile with their line items, stock cannot go negative, a bill cannot be paid twice) are enforced in a way that holds regardless of which application, script, or careless direct SQL session touches the data. Pushing this logic into the database, rather than scattering it across Flask route handlers, meant the application layer stayed thin: most routes are a query plus a template render, and the routes that do carry logic (dispensing, billing, payment) are thin wrappers around a single stored-procedure call whose correctness can be verified independently of the web framework.

The most valuable design decision in retrospect was treating `prescription_details.unit_price`/`subtotal` as a snapshot rather than a live lookup against `medicines.unit_price` — it is a small extra column, but it is the difference between a billing system that stays correct forever and one that quietly rewrites history every time a medicine's price changes. The most useful implementation decision was centralizing status-to-badge-color mapping in a single Jinja filter rather than repeating conditional logic in eleven templates, which made the UI's color-coding trivial to keep consistent.

If extended further, the natural next steps would be: doctor-specific login scoping (linking `users` rows of role `doctor` to a specific `doctors.doctor_id` so a doctor only sees their own patients by default), an audit trail table for sensitive actions (cancellations, payments, stock adjustments), and pagination for the list views once seed data volume grows well beyond the practicum's 12 patients and 15 appointments.
