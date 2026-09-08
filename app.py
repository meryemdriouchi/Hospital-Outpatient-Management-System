import pymysql
import pymysql.cursors
from datetime import date, datetime
from functools import wraps

from flask import (
    Flask, render_template, request, redirect, url_for,
    session, flash, jsonify, g, abort
)
from werkzeug.security import generate_password_hash, check_password_hash

from config import Config

app = Flask(__name__)
app.config.from_object(Config)


# ----------------------------------------------------------------------------
# Database helpers
# ----------------------------------------------------------------------------

def get_db():
    if "db" not in g:
        g.db = pymysql.connect(
            host=app.config["MYSQL_HOST"],
            port=app.config["MYSQL_PORT"],
            user=app.config["MYSQL_USER"],
            password=app.config["MYSQL_PASSWORD"],
            database=app.config["MYSQL_DB"],
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=True,
            charset="utf8mb4",
        )
    return g.db


@app.teardown_appcontext
def close_db(exception=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def query_all(sql, params=None):
    db = get_db()
    cur = db.cursor()
    try:
        cur.execute(sql, params or ())
        return cur.fetchall()
    finally:
        cur.close()


def query_one(sql, params=None):
    rows = query_all(sql, params)
    return rows[0] if rows else None


def execute(sql, params=None):
    db = get_db()
    cur = db.cursor()
    try:
        cur.execute(sql, params or ())
        db.commit()
        return cur.lastrowid
    finally:
        cur.close()


def call_proc(proc_name, params=None):
    """Call a stored procedure and return a list of its result sets
    (each result set is a list of dict rows, possibly empty)."""
    db = get_db()
    cur = db.cursor()
    try:
        cur.callproc(proc_name, params or ())
        result_sets = [cur.fetchall()]
        while cur.nextset():
            result_sets.append(cur.fetchall())
        db.commit()
        return result_sets
    finally:
        cur.close()


def sql_error_message(exc):
    if exc.args and len(exc.args) > 1:
        return str(exc.args[1])
    return str(exc)


# ----------------------------------------------------------------------------
# Auth decorators
# ----------------------------------------------------------------------------

def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            flash("Please log in to continue.", "warning")
            return redirect(url_for("login", next=request.path))
        return view(*args, **kwargs)
    return wrapped


def role_required(allowed_roles):
    def decorator(view):
        @wraps(view)
        def wrapped(*args, **kwargs):
            if "user_id" not in session:
                flash("Please log in to continue.", "warning")
                return redirect(url_for("login", next=request.path))
            if session.get("role") not in allowed_roles:
                flash("You do not have permission to perform this action.", "danger")
                return redirect(url_for("dashboard"))
            return view(*args, **kwargs)
        return wrapped
    return decorator


# ----------------------------------------------------------------------------
# Template filters / globals
# ----------------------------------------------------------------------------

STATUS_BADGE_MAP = {
    "scheduled": "primary",
    "completed": "success",
    "cancelled": "danger",
    "no_show": "secondary",
    "pending": "warning",
    "dispensed": "success",
    "paid": "success",
    "unpaid": "danger",
    "refunded": "secondary",
}


@app.template_filter("badge_class")
def badge_class(status):
    return STATUS_BADGE_MAP.get(status, "secondary")


@app.template_filter("money")
def money(value):
    if value is None:
        return "0.00"
    return f"{float(value):,.2f}"


@app.template_filter("dt")
def format_dt(value, fmt="%Y-%m-%d"):
    if value is None:
        return "-"
    return value.strftime(fmt)


@app.context_processor
def inject_globals():
    return {"current_year": datetime.now().year}


# ----------------------------------------------------------------------------
# Time slots (08:00-12:00 and 14:00-18:00, 30-minute increments)
# ----------------------------------------------------------------------------

def generate_time_slots():
    slots = []
    for start_hour, end_hour in [(8, 12), (14, 18)]:
        h, m = start_hour, 0
        while (h, m) < (end_hour, 0):
            sh, sm = h, m
            m += 30
            if m >= 60:
                h += 1
                m = 0
            slots.append(f"{sh:02d}:{sm:02d}-{h:02d}:{m:02d}")
    return slots


TIME_SLOTS = generate_time_slots()


# ----------------------------------------------------------------------------
# Index / Auth routes
# ----------------------------------------------------------------------------

@app.route("/")
def index():
    if "user_id" in session:
        return redirect(url_for("dashboard"))
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")

        user = query_one(
            "SELECT * FROM users WHERE username=%s AND is_active=TRUE", (username,)
        )
        if user and check_password_hash(user["password_hash"], password):
            session.clear()
            session["user_id"] = user["user_id"]
            session["username"] = user["username"]
            session["role"] = user["role"]
            session["real_name"] = user["real_name"]
            execute("UPDATE users SET last_login=NOW() WHERE user_id=%s", (user["user_id"],))
            flash(f"Welcome back, {user['real_name']}!", "success")
            next_url = request.args.get("next")
            return redirect(next_url or url_for("dashboard"))

        flash("Invalid username or password.", "danger")

    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    flash("You have been logged out.", "info")
    return redirect(url_for("login"))


# ----------------------------------------------------------------------------
# Dashboard
# ----------------------------------------------------------------------------

@app.route("/dashboard")
@login_required
def dashboard():
    stats = {
        "total_patients": query_one("SELECT COUNT(*) AS c FROM patients")["c"],
        "total_doctors": query_one("SELECT COUNT(*) AS c FROM doctors WHERE is_active=TRUE")["c"],
        "today_appointments": query_one(
            "SELECT COUNT(*) AS c FROM appointments WHERE appointment_date=CURDATE()"
        )["c"],
        "unpaid_bills": query_one(
            "SELECT COUNT(*) AS c FROM bills WHERE payment_status='unpaid'"
        )["c"],
        "low_stock": query_one("SELECT COUNT(*) AS c FROM view_low_stock")["c"],
        "today_revenue": query_one(
            "SELECT COALESCE(SUM(final_amount),0) AS c FROM bills "
            "WHERE payment_status='paid' AND DATE(paid_at)=CURDATE()"
        )["c"],
    }
    today_appts = query_all("SELECT * FROM view_today_appointments ORDER BY time_slot")
    return render_template("dashboard.html", stats=stats, today_appts=today_appts)


# ----------------------------------------------------------------------------
# Patients
# ----------------------------------------------------------------------------

@app.route("/patients")
@login_required
def patients():
    rows = query_all("SELECT * FROM patients ORDER BY patient_id DESC")
    return render_template("patients.html", patients=rows)


@app.route("/patients/add", methods=["POST"])
@login_required
def add_patient():
    form = request.form
    try:
        execute(
            """INSERT INTO patients
               (patient_name, gender, birth_date, id_card, phone, address, blood_type, allergy_history)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
            (
                form.get("patient_name"),
                form.get("gender"),
                form.get("birth_date") or None,
                form.get("id_card") or None,
                form.get("phone"),
                form.get("address"),
                form.get("blood_type"),
                form.get("allergy_history"),
            ),
        )
        flash("Patient registered successfully.", "success")
    except pymysql.MySQLError:
        flash("A patient with that ID card number already exists.", "danger")
    return redirect(url_for("patients"))


@app.route("/patients/<int:patient_id>")
@login_required
def patient_detail(patient_id):
    patient = query_one("SELECT * FROM patients WHERE patient_id=%s", (patient_id,))
    if not patient:
        abort(404)

    appointments_history = query_all(
        """SELECT a.*, d.doctor_name, dep.dept_name
           FROM appointments a
           JOIN doctors d ON a.doctor_id = d.doctor_id
           JOIN departments dep ON d.dept_id = dep.dept_id
           WHERE a.patient_id=%s
           ORDER BY a.appointment_date DESC""",
        (patient_id,),
    )

    history_sets = call_proc("sp_patient_history", (patient_id,))
    medical_history = history_sets[0] if history_sets else []

    return render_template(
        "patient_detail.html",
        patient=patient,
        appointments=appointments_history,
        history=medical_history,
    )


# ----------------------------------------------------------------------------
# Appointments
# ----------------------------------------------------------------------------

@app.route("/appointments")
@login_required
def appointments():
    rows = query_all(
        """SELECT a.*, p.patient_name, d.doctor_name, dep.dept_name
           FROM appointments a
           JOIN patients p ON a.patient_id = p.patient_id
           JOIN doctors d ON a.doctor_id = d.doctor_id
           JOIN departments dep ON d.dept_id = dep.dept_id
           ORDER BY a.appointment_date DESC, a.time_slot"""
    )
    patients_list = query_all("SELECT patient_id, patient_name FROM patients ORDER BY patient_name")
    departments_list = query_all("SELECT dept_id, dept_name FROM departments ORDER BY dept_name")
    return render_template(
        "appointments.html",
        appointments=rows,
        patients=patients_list,
        departments=departments_list,
        time_slots=TIME_SLOTS,
        today=date.today().isoformat(),
    )


@app.route("/appointments/add", methods=["POST"])
@login_required
def add_appointment():
    form = request.form
    try:
        execute(
            """INSERT INTO appointments
               (patient_id, doctor_id, appointment_date, time_slot, symptoms, created_by)
               VALUES (%s,%s,%s,%s,%s,%s)""",
            (
                form.get("patient_id"),
                form.get("doctor_id"),
                form.get("appointment_date"),
                form.get("time_slot"),
                form.get("symptoms"),
                session["user_id"],
            ),
        )
        flash("Appointment scheduled successfully.", "success")
    except pymysql.MySQLError as e:
        flash(sql_error_message(e), "danger")
    return redirect(url_for("appointments"))


@app.route("/appointments/cancel/<int:appointment_id>", methods=["POST"])
@login_required
def cancel_appointment(appointment_id):
    try:
        call_proc("sp_cancel_appointment", (appointment_id,))
        flash("Appointment cancelled.", "success")
    except pymysql.MySQLError as e:
        flash(sql_error_message(e), "danger")
    return redirect(url_for("appointments"))


@app.route("/api/doctors_by_dept/<int:dept_id>")
@login_required
def api_doctors_by_dept(dept_id):
    rows = query_all(
        """SELECT doctor_id, doctor_name, title, fee
           FROM doctors WHERE dept_id=%s AND is_active=TRUE
           ORDER BY doctor_name""",
        (dept_id,),
    )
    for row in rows:
        row["fee"] = float(row["fee"]) if row["fee"] is not None else 0.0
    return jsonify(rows)


@app.route("/api/check_stock/<int:medicine_id>/<int:qty>")
@login_required
def api_check_stock(medicine_id, qty):
    result_sets = call_proc("sp_check_stock", (medicine_id, qty))
    row = result_sets[0][0] if result_sets and result_sets[0] else {"is_available": False, "current_stock": 0}
    row["is_available"] = bool(row["is_available"])
    return jsonify(row)


# ----------------------------------------------------------------------------
# Medical records
# ----------------------------------------------------------------------------

@app.route("/medical_records")
@login_required
def medical_records():
    rows = query_all(
        """SELECT mr.*, p.patient_name, d.doctor_name
           FROM medical_records mr
           JOIN patients p ON mr.patient_id = p.patient_id
           JOIN doctors d ON mr.doctor_id = d.doctor_id
           ORDER BY mr.visit_date DESC"""
    )
    patients_list = query_all("SELECT patient_id, patient_name FROM patients ORDER BY patient_name")
    doctors_list = query_all("SELECT doctor_id, doctor_name FROM doctors WHERE is_active=TRUE ORDER BY doctor_name")
    appointments_list = query_all(
        """SELECT appointment_id, appointment_date, patient_id, doctor_id
           FROM appointments ORDER BY appointment_date DESC LIMIT 50"""
    )
    return render_template(
        "medical_records.html",
        records=rows,
        patients=patients_list,
        doctors=doctors_list,
        appointments=appointments_list,
    )


@app.route("/medical_records/add", methods=["POST"])
@login_required
@role_required(["doctor", "admin"])
def add_medical_record():
    form = request.form
    appointment_id = form.get("appointment_id") or None

    record_id = execute(
        """INSERT INTO medical_records
           (patient_id, doctor_id, appointment_id, chief_complaint, diagnosis, treatment_plan, notes)
           VALUES (%s,%s,%s,%s,%s,%s,%s)""",
        (
            form.get("patient_id"),
            form.get("doctor_id"),
            appointment_id,
            form.get("chief_complaint"),
            form.get("diagnosis"),
            form.get("treatment_plan"),
            form.get("notes"),
        ),
    )
    if appointment_id:
        execute(
            "UPDATE appointments SET status='completed' WHERE appointment_id=%s AND status='scheduled'",
            (appointment_id,),
        )
    flash(f"Medical record #{record_id} created.", "success")
    return redirect(url_for("medical_records"))


# ----------------------------------------------------------------------------
# Prescriptions
# ----------------------------------------------------------------------------

@app.route("/prescriptions")
@login_required
def prescriptions():
    rows = query_all(
        """SELECT pr.*, p.patient_name, d.doctor_name,
                  (SELECT COUNT(*) FROM bills b WHERE b.prescription_id = pr.prescription_id) AS has_bill
           FROM prescriptions pr
           JOIN patients p ON pr.patient_id = p.patient_id
           JOIN doctors d ON pr.doctor_id = d.doctor_id
           ORDER BY pr.prescription_date DESC"""
    )
    records_list = query_all(
        """SELECT mr.record_id, mr.visit_date, mr.diagnosis, mr.patient_id, mr.doctor_id,
                  p.patient_name, d.doctor_name
           FROM medical_records mr
           JOIN patients p ON mr.patient_id = p.patient_id
           JOIN doctors d ON mr.doctor_id = d.doctor_id
           ORDER BY mr.visit_date DESC LIMIT 50"""
    )
    medicines_list = query_all(
        """SELECT medicine_id, medicine_name, unit_price, stock_quantity
           FROM medicines WHERE is_active=TRUE ORDER BY medicine_name"""
    )
    return render_template(
        "prescriptions.html", prescriptions=rows, records=records_list, medicines=medicines_list
    )


@app.route("/prescriptions/<int:prescription_id>")
@login_required
def prescription_detail(prescription_id):
    presc = query_one(
        """SELECT pr.*, p.patient_name, d.doctor_name
           FROM prescriptions pr
           JOIN patients p ON pr.patient_id = p.patient_id
           JOIN doctors d ON pr.doctor_id = d.doctor_id
           WHERE pr.prescription_id=%s""",
        (prescription_id,),
    )
    if not presc:
        abort(404)

    details = query_all(
        """SELECT pd.*, m.medicine_name, m.category
           FROM prescription_details pd
           JOIN medicines m ON pd.medicine_id = m.medicine_id
           WHERE pd.prescription_id=%s""",
        (prescription_id,),
    )
    bill = query_one("SELECT * FROM bills WHERE prescription_id=%s", (prescription_id,))
    return render_template("prescription_detail.html", prescription=presc, details=details, bill=bill)


@app.route("/prescriptions/add", methods=["POST"])
@login_required
@role_required(["doctor", "admin"])
def add_prescription():
    form = request.form
    record_id = form.get("record_id")
    record = query_one("SELECT * FROM medical_records WHERE record_id=%s", (record_id,))
    if not record:
        flash("Medical record not found.", "danger")
        return redirect(url_for("prescriptions"))

    medicine_ids = request.form.getlist("medicine_id[]")
    quantities = request.form.getlist("quantity[]")
    dosages = request.form.getlist("dosage[]")
    lines = [
        (mid, qty, dosage)
        for mid, qty, dosage in zip(medicine_ids, quantities, dosages)
        if mid and qty
    ]
    if not lines:
        flash("Add at least one medicine line to the prescription.", "warning")
        return redirect(url_for("prescriptions"))

    db = get_db()
    cur = db.cursor()
    try:
        db.begin()
        cur.execute(
            """INSERT INTO prescriptions (record_id, patient_id, doctor_id, status, total_amount)
               VALUES (%s,%s,%s,'pending',0.00)""",
            (record_id, record["patient_id"], record["doctor_id"]),
        )
        prescription_id = cur.lastrowid

        for mid, qty, dosage in lines:
            qty = int(qty)
            cur.execute("SELECT unit_price FROM medicines WHERE medicine_id=%s", (mid,))
            medicine = cur.fetchone()
            if not medicine:
                raise ValueError(f"Medicine #{mid} not found")
            unit_price = medicine["unit_price"]
            subtotal = unit_price * qty
            cur.execute(
                """INSERT INTO prescription_details
                   (prescription_id, medicine_id, quantity, dosage, unit_price, subtotal)
                   VALUES (%s,%s,%s,%s,%s,%s)""",
                (prescription_id, mid, qty, dosage, unit_price, subtotal),
            )
        db.commit()
        flash(f"Prescription #{prescription_id} created successfully.", "success")
    except Exception as e:
        db.rollback()
        flash(f"Failed to create prescription: {e}", "danger")
    finally:
        cur.close()

    return redirect(url_for("prescriptions"))


@app.route("/prescriptions/<int:prescription_id>/dispense", methods=["POST"])
@login_required
@role_required(["pharmacist", "admin"])
def dispense_prescription(prescription_id):
    try:
        call_proc("sp_dispense_prescription", (prescription_id,))
        flash("Prescription dispensed and stock updated.", "success")
    except pymysql.MySQLError as e:
        flash(sql_error_message(e), "danger")
    return redirect(url_for("prescriptions"))


# ----------------------------------------------------------------------------
# Bills
# ----------------------------------------------------------------------------

@app.route("/bills")
@login_required
def bills():
    rows = query_all(
        """SELECT b.*, p.patient_name
           FROM bills b
           JOIN patients p ON b.patient_id = p.patient_id
           ORDER BY b.bill_date DESC"""
    )
    return render_template("bills.html", bills=rows)


@app.route("/bills/generate/<int:prescription_id>", methods=["POST"])
@login_required
@role_required(["cashier", "admin"])
def generate_bill(prescription_id):
    try:
        call_proc("sp_generate_bill", (prescription_id, session["user_id"]))
        flash("Bill generated successfully.", "success")
    except pymysql.MySQLError as e:
        flash(sql_error_message(e), "danger")
    return redirect(url_for("prescriptions"))


@app.route("/bills/pay/<int:bill_id>", methods=["POST"])
@login_required
@role_required(["cashier", "admin"])
def pay_bill(bill_id):
    payment_method = request.form.get("payment_method", "cash")
    try:
        call_proc("sp_process_payment", (bill_id, payment_method))
        flash("Payment processed successfully.", "success")
    except pymysql.MySQLError as e:
        flash(sql_error_message(e), "danger")
    return redirect(url_for("bills"))


# ----------------------------------------------------------------------------
# Medicines
# ----------------------------------------------------------------------------

@app.route("/medicines")
@login_required
def medicines():
    rows = query_all("SELECT * FROM medicines ORDER BY medicine_name")
    return render_template("medicines.html", medicines=rows)


@app.route("/medicines/add", methods=["POST"])
@login_required
@role_required(["pharmacist", "admin"])
def add_medicine():
    form = request.form
    execute(
        """INSERT INTO medicines
           (medicine_name, generic_name, category, specification, manufacturer,
            unit_price, stock_quantity, min_stock, expiry_date)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
        (
            form.get("medicine_name"),
            form.get("generic_name"),
            form.get("category"),
            form.get("specification"),
            form.get("manufacturer"),
            form.get("unit_price") or 0,
            form.get("stock_quantity") or 0,
            form.get("min_stock") or 10,
            form.get("expiry_date") or None,
        ),
    )
    flash("Medicine added to inventory.", "success")
    return redirect(url_for("medicines"))


# ----------------------------------------------------------------------------
# Reports (admin only)
# ----------------------------------------------------------------------------

@app.route("/reports")
@login_required
@role_required(["admin"])
def reports():
    report_date = request.args.get("date") or date.today().isoformat()

    revenue_sets = call_proc("sp_daily_revenue", (report_date,))
    revenue_summary = (
        revenue_sets[0][0] if revenue_sets and revenue_sets[0] else {"total_bills": 0, "total_revenue": 0}
    )
    revenue_breakdown = revenue_sets[1] if len(revenue_sets) > 1 else []

    workload = query_all("SELECT * FROM view_doctor_workload LIMIT 50")
    low_stock = query_all("SELECT * FROM view_low_stock")

    return render_template(
        "reports.html",
        report_date=report_date,
        revenue_summary=revenue_summary,
        revenue_breakdown=revenue_breakdown,
        workload=workload,
        low_stock=low_stock,
    )


# ----------------------------------------------------------------------------
# Database explorer (admin only, read-only)
# ----------------------------------------------------------------------------

TABLE_PAGE_SIZE = 50


def get_catalog_entries():
    """Return {name, type} for every table/view in the app's own database,
    straight from information_schema. Used to whitelist identifiers before
    they're interpolated into SQL (table/view names can't be parameterized)."""
    return query_all(
        """SELECT TABLE_NAME AS name, TABLE_TYPE AS type
           FROM information_schema.tables
           WHERE TABLE_SCHEMA = %s
           ORDER BY TABLE_TYPE, TABLE_NAME""",
        (app.config["MYSQL_DB"],),
    )


@app.route("/admin/tables")
@login_required
@role_required(["admin"])
def admin_tables():
    entries = get_catalog_entries()
    tables = []
    for entry in entries:
        count = query_one(f"SELECT COUNT(*) AS c FROM `{entry['name']}`")["c"]
        tables.append({"name": entry["name"], "type": entry["type"], "count": count})
    return render_template("admin_tables.html", tables=tables)


@app.route("/admin/tables/<table_name>")
@login_required
@role_required(["admin"])
def admin_table_detail(table_name):
    valid_names = {entry["name"] for entry in get_catalog_entries()}
    if table_name not in valid_names:
        abort(404)

    columns = [
        row["name"]
        for row in query_all(
            """SELECT COLUMN_NAME AS name
               FROM information_schema.columns
               WHERE TABLE_SCHEMA = %s AND TABLE_NAME = %s
               ORDER BY ORDINAL_POSITION""",
            (app.config["MYSQL_DB"], table_name),
        )
    ]

    total = query_one(f"SELECT COUNT(*) AS c FROM `{table_name}`")["c"]
    total_pages = max((total + TABLE_PAGE_SIZE - 1) // TABLE_PAGE_SIZE, 1)

    try:
        page = int(request.args.get("page", 1))
    except ValueError:
        page = 1
    page = min(max(page, 1), total_pages)
    offset = (page - 1) * TABLE_PAGE_SIZE

    rows = query_all(
        f"SELECT * FROM `{table_name}` LIMIT %s OFFSET %s", (TABLE_PAGE_SIZE, offset)
    )

    return render_template(
        "admin_table_detail.html",
        table_name=table_name,
        columns=columns,
        rows=rows,
        page=page,
        total_pages=total_pages,
        total=total,
        page_size=TABLE_PAGE_SIZE,
    )


# ----------------------------------------------------------------------------
# Error handlers
# ----------------------------------------------------------------------------

@app.errorhandler(404)
def not_found(e):
    return render_template("404.html"), 404


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
