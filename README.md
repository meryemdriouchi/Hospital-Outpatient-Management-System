# Hospital Outpatient Management System

A full-stack **Hospital Outpatient Management System** built as a database practicum project. It covers the end-to-end outpatient workflow — patient registration, appointment scheduling, medical records, prescriptions, billing, and medicine inventory — backed by a relational MySQL schema with views, stored procedures, and triggers, and served through a Flask web application.

## Overview

The system supports five roles (**admin, doctor, receptionist, pharmacist, cashier**) and models a realistic outpatient clinic workflow:

1. A receptionist registers a patient and schedules an appointment with a doctor in a chosen department.
2. The doctor sees the patient, creates a medical record (chief complaint, diagnosis, treatment plan), and writes a prescription with one or more medicines.
3. A pharmacist dispenses the prescription, which automatically deducts stock from inventory.
4. A cashier generates a bill from the dispensed prescription (consultation fee + medicine total) and processes payment.
5. An admin reviews dashboards and reports: daily revenue, doctor workload, and low-stock alerts.

Database integrity is enforced primarily in MySQL itself — foreign keys, a trigger that blocks duplicate appointment bookings, a trigger that keeps prescription totals in sync, and stored procedures that encapsulate multi-step business logic (billing, dispensing, payment, cancellation).

## Tech Stack

| Layer            | Technology                          |
|-------------------|--------------------------------------|
| Database          | MySQL 8.0                           |
| Backend            | Python 3.10+, Flask 3.1              |
| DB Driver           | PyMySQL 1.2                         |
| Password hashing     | Werkzeug security (PBKDF2-SHA256)   |
| Frontend             | HTML5, Bootstrap 5, Bootstrap Icons |
| Session/auth          | Flask server-side sessions          |

## Database Schema Summary

10 tables, 10 indexes, 4 views, 8 stored procedures, and 3 triggers. See [`sql/schema.sql`](sql/schema.sql) for the full definitions.

| Table                  | Purpose                                                  |
|--------------------------|-----------------------------------------------------------|
| `departments`             | Hospital departments (Internal Medicine, Surgery, ...)    |
| `doctors`                  | Doctors, each assigned to one department                  |
| `patients`                  | Patient demographic and medical background info           |
| `users`                      | System login accounts (5 roles)                            |
| `appointments`                | Scheduled visits; unique per patient/doctor/date/slot       |
| `medical_records`               | Diagnosis and treatment notes per visit                     |
| `medicines`                       | Inventory: stock, pricing, reorder threshold                |
| `prescriptions`                     | One prescription per medical record                          |
| `prescription_details`                | Line items (medicine, quantity, dosage) — M:N junction table   |
| `bills`                                 | Consultation + medicine charges, payment status                |

**Views:** `view_today_appointments`, `view_unpaid_bills`, `view_low_stock`, `view_doctor_workload`

**Stored procedures:** `sp_generate_bill`, `sp_process_payment`, `sp_check_stock`, `sp_dispense_prescription`, `sp_patient_history`, `sp_daily_revenue`, `sp_cancel_appointment`, `sp_search_available_doctors`

**Triggers:** `trg_update_prescription_total` / `trg_update_prescription_total_update` (auto-recalculate prescription totals), `trg_check_duplicate_appointment` (blocks double-booking)

## Quick Start

### 1. Prerequisites

- MySQL 8.0+ installed and running
- Python 3.10+

### 2. Set up the database

```bash
mysql -u root -p < sql/schema.sql
mysql -u root -p hospital_outpatient_db < sql/seed_data.sql
```

This creates the `hospital_outpatient_db` database with all tables, views, procedures, and triggers, then loads demo data (departments, doctors, patients, users, medicines, appointments, medical records, prescriptions, and bills).

### 3. Configure the application

```bash
cp .env.example .env
```

Edit `.env` with your MySQL credentials:

```
SECRET_KEY=change-this-to-a-long-random-string
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=your-mysql-password
MYSQL_DB=hospital_outpatient_db
```

### 4. Install dependencies and run

```bash
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

The app runs at **http://localhost:5000**.

## Demo Accounts

All seeded users share the passwords below (hashed with PBKDF2-SHA256 in the database — never store plaintext passwords).

| Username      | Password       | Role          | Name                  |
|----------------|-----------------|----------------|-------------------------|
| `admin`         | `admin123`       | admin           | System Administrator     |
| `reception1`     | `reception123`     | receptionist     | Qian Fei                   |
| `reception2`      | `reception123`      | receptionist      | Sun Ya                       |
| `doctor1`           | `doctor123`           | doctor             | Wang Jianguo                  |
| `doctor2`            | `doctor123`            | doctor              | Liu Yang                        |
| `pharmacist1`         | `pharma123`             | pharmacist            | Feng Li                           |
| `cashier1`              | `cashier123`              | cashier                | Zhao Qian                           |

## Project Structure

```
Hospital Outpatient Management System/
├── app.py                     # Flask application: routes, auth, DB access
├── config.py                  # Configuration (reads env vars / .env)
├── requirements.txt           # Python dependencies
├── .env.example                # Environment variable template
├── sql/
│   ├── schema.sql               # Tables, indexes, views, procedures, triggers
│   └── seed_data.sql              # Demo data
├── static/
│   ├── css/style.css               # Custom styling (sidebar, cards, badges)
│   └── js/                           # (reserved for future assets)
├── templates/
│   ├── base.html                       # Sidebar layout + flash messages
│   ├── login.html                        # Login page
│   ├── dashboard.html                      # Stat cards + today's appointments
│   ├── patients.html / patient_detail.html   # Patient list / detail views
│   ├── appointments.html                       # Scheduling with AJAX doctor lookup
│   ├── medical_records.html                       # Diagnosis & treatment records
│   ├── prescriptions.html / prescription_detail.html  # Prescriptions + line items
│   ├── bills.html                                        # Billing & payments
│   ├── medicines.html                                      # Inventory management
│   └── reports.html                                          # Admin analytics
├── README.md
└── report.md                   # Practicum report (design process, tests, reflections)
```

## Routes

The application implements the routes specified in the practicum brief, plus a small number of additional routes needed to complete the workflow end-to-end (creating prescriptions, dispensing them, and generating bills from them) — these are called out below.

| Route | Method | Access | Notes |
|---|---|---|---|
| `/login` | GET/POST | public | |
| `/logout` | GET | logged in | |
| `/dashboard` | GET | logged in | |
| `/patients`, `/patients/add`, `/patients/<id>` | GET/POST | logged in | |
| `/appointments`, `/appointments/add`, `/appointments/cancel/<id>` | GET/POST | logged in | |
| `/api/doctors_by_dept/<dept_id>` | GET | logged in | AJAX JSON |
| `/medical_records`, `/medical_records/add` | GET/POST | doctor, admin (add) | |
| `/prescriptions`, `/prescriptions/<id>` | GET | logged in | |
| `/prescriptions/add` *(added)* | POST | doctor, admin | creates a prescription with medicine lines |
| `/prescriptions/<id>/dispense` *(added)* | POST | pharmacist, admin | calls `sp_dispense_prescription` |
| `/bills`, `/bills/pay/<id>` | GET/POST | cashier, admin (pay) | `pay` calls `sp_process_payment` |
| `/bills/generate/<prescription_id>` *(added)* | POST | cashier, admin | calls `sp_generate_bill` |
| `/medicines`, `/medicines/add` | GET/POST | pharmacist, admin (add) | |
| `/reports` | GET | admin only | calls `sp_daily_revenue` |

## Author

Built as a database practicum project.
Contact: meryemdriouchi1@gmail.com
