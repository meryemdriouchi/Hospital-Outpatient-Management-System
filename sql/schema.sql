-- ============================================================================
-- Hospital Outpatient Management System
-- Database Schema: Tables, Indexes, Views, Stored Procedures, Triggers
-- Target: MySQL 8.0+
--
-- Usage:
--   mysql -u root -p < sql/schema.sql
--   (or)  SOURCE sql/schema.sql;   -- from inside the mysql client
-- ============================================================================

DROP DATABASE IF EXISTS hospital_outpatient_db;
CREATE DATABASE hospital_outpatient_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE hospital_outpatient_db;

-- ----------------------------------------------------------------------------
-- 1. TABLES
-- ----------------------------------------------------------------------------

-- 1.1 departments
CREATE TABLE departments (
    dept_id       INT AUTO_INCREMENT PRIMARY KEY,
    dept_name     VARCHAR(50)  NOT NULL UNIQUE,
    dept_location VARCHAR(100),
    phone         VARCHAR(20),
    description   TEXT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 1.2 doctors
CREATE TABLE doctors (
    doctor_id   INT AUTO_INCREMENT PRIMARY KEY,
    doctor_name VARCHAR(50) NOT NULL,
    gender      CHAR(1),
    title       VARCHAR(30),
    dept_id     INT NOT NULL,
    phone       VARCHAR(20),
    email       VARCHAR(100),
    specialty   VARCHAR(200),
    fee         DECIMAL(10,2) DEFAULT 0.00,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_doctors_dept FOREIGN KEY (dept_id)
        REFERENCES departments(dept_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 1.3 patients
CREATE TABLE patients (
    patient_id      INT AUTO_INCREMENT PRIMARY KEY,
    patient_name    VARCHAR(50) NOT NULL,
    gender          CHAR(1),
    birth_date      DATE,
    id_card         VARCHAR(18) UNIQUE,
    phone           VARCHAR(20),
    address         VARCHAR(200),
    blood_type      VARCHAR(5),
    allergy_history TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 1.4 users (system login accounts)
CREATE TABLE users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(30) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('admin','doctor','receptionist','pharmacist','cashier') DEFAULT 'receptionist',
    real_name     VARCHAR(50),
    phone         VARCHAR(20),
    is_active     BOOLEAN DEFAULT TRUE,
    last_login    DATETIME,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 1.5 appointments
CREATE TABLE appointments (
    appointment_id   INT AUTO_INCREMENT PRIMARY KEY,
    patient_id       INT NOT NULL,
    doctor_id        INT NOT NULL,
    appointment_date DATE NOT NULL,
    time_slot        VARCHAR(20) NOT NULL,
    status           ENUM('scheduled','completed','cancelled','no_show') DEFAULT 'scheduled',
    symptoms         TEXT,
    created_by       INT,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_appointments_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_created_by FOREIGN KEY (created_by)
        REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 1.6 medical_records
CREATE TABLE medical_records (
    record_id        INT AUTO_INCREMENT PRIMARY KEY,
    patient_id        INT NOT NULL,
    doctor_id         INT NOT NULL,
    appointment_id     INT,
    visit_date         DATETIME DEFAULT CURRENT_TIMESTAMP,
    chief_complaint    TEXT,
    diagnosis          TEXT,
    treatment_plan      TEXT,
    notes               TEXT,
    CONSTRAINT fk_records_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_records_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT,
    CONSTRAINT fk_records_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 1.7 medicines
CREATE TABLE medicines (
    medicine_id    INT AUTO_INCREMENT PRIMARY KEY,
    medicine_name  VARCHAR(100) NOT NULL,
    generic_name   VARCHAR(100),
    category       VARCHAR(50),
    specification  VARCHAR(100),
    manufacturer   VARCHAR(100),
    unit_price     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    stock_quantity INT DEFAULT 0,
    min_stock      INT DEFAULT 10,
    expiry_date    DATE,
    is_active      BOOLEAN DEFAULT TRUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 1.8 prescriptions
CREATE TABLE prescriptions (
    prescription_id    INT AUTO_INCREMENT PRIMARY KEY,
    record_id          INT NOT NULL,
    patient_id         INT NOT NULL,
    doctor_id          INT NOT NULL,
    prescription_date  DATETIME DEFAULT CURRENT_TIMESTAMP,
    status              ENUM('pending','dispensed','cancelled') DEFAULT 'pending',
    total_amount        DECIMAL(10,2) DEFAULT 0.00,
    CONSTRAINT fk_presc_record FOREIGN KEY (record_id)
        REFERENCES medical_records(record_id) ON DELETE CASCADE,
    CONSTRAINT fk_presc_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_presc_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 1.9 prescription_details (junction table, M:N between prescriptions & medicines)
CREATE TABLE prescription_details (
    detail_id       INT AUTO_INCREMENT PRIMARY KEY,
    prescription_id INT NOT NULL,
    medicine_id     INT NOT NULL,
    quantity        INT NOT NULL DEFAULT 1,
    dosage          VARCHAR(100),
    unit_price      DECIMAL(10,2) NOT NULL,
    subtotal        DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_details_prescription FOREIGN KEY (prescription_id)
        REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    CONSTRAINT fk_details_medicine FOREIGN KEY (medicine_id)
        REFERENCES medicines(medicine_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 1.10 bills
CREATE TABLE bills (
    bill_id          INT AUTO_INCREMENT PRIMARY KEY,
    patient_id        INT NOT NULL,
    prescription_id    INT,
    bill_date          DATETIME DEFAULT CURRENT_TIMESTAMP,
    consultation_fee   DECIMAL(10,2) DEFAULT 0.00,
    medicine_fee        DECIMAL(10,2) DEFAULT 0.00,
    other_fee           DECIMAL(10,2) DEFAULT 0.00,
    total_amount         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    discount             DECIMAL(10,2) DEFAULT 0.00,
    final_amount          DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    payment_status         ENUM('unpaid','paid','refunded') DEFAULT 'unpaid',
    payment_method          VARCHAR(20),
    paid_at                 DATETIME,
    CONSTRAINT fk_bills_patient FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_bills_prescription FOREIGN KEY (prescription_id)
        REFERENCES prescriptions(prescription_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- 2. INDEXES
-- ----------------------------------------------------------------------------

CREATE INDEX idx_appointments_date    ON appointments(appointment_date);
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor  ON appointments(doctor_id);

CREATE INDEX idx_medical_records_patient ON medical_records(patient_id);
CREATE INDEX idx_medical_records_doctor  ON medical_records(doctor_id);

CREATE INDEX idx_prescriptions_patient ON prescriptions(patient_id);

CREATE INDEX idx_bills_patient ON bills(patient_id);
CREATE INDEX idx_bills_status  ON bills(payment_status);

CREATE INDEX idx_medicines_category ON medicines(category);
CREATE INDEX idx_medicines_stock    ON medicines(stock_quantity);

-- ----------------------------------------------------------------------------
-- 3. VIEWS
-- ----------------------------------------------------------------------------

-- 3.1 Today's appointments, with patient / doctor / department details
CREATE OR REPLACE VIEW view_today_appointments AS
SELECT
    a.appointment_id,
    a.appointment_date,
    a.time_slot,
    a.status,
    a.symptoms,
    p.patient_id,
    p.patient_name,
    p.phone       AS patient_phone,
    p.gender      AS patient_gender,
    d.doctor_id,
    d.doctor_name,
    d.title,
    dep.dept_id,
    dep.dept_name
FROM appointments a
JOIN patients p     ON a.patient_id = p.patient_id
JOIN doctors d      ON a.doctor_id = d.doctor_id
JOIN departments dep ON d.dept_id = dep.dept_id
WHERE a.appointment_date = CURDATE();

-- 3.2 Unpaid bills, with patient details
CREATE OR REPLACE VIEW view_unpaid_bills AS
SELECT
    b.bill_id,
    b.bill_date,
    b.total_amount,
    b.discount,
    b.final_amount,
    b.payment_status,
    p.patient_id,
    p.patient_name,
    p.phone
FROM bills b
JOIN patients p ON b.patient_id = p.patient_id
WHERE b.payment_status = 'unpaid';

-- 3.3 Medicines at or below their minimum stock threshold
CREATE OR REPLACE VIEW view_low_stock AS
SELECT
    medicine_id,
    medicine_name,
    category,
    stock_quantity,
    min_stock,
    unit_price
FROM medicines
WHERE stock_quantity <= min_stock AND is_active = TRUE;

-- 3.4 Monthly workload per doctor: appointments, records, prescriptions
CREATE OR REPLACE VIEW view_doctor_workload AS
SELECT
    dm.doctor_id,
    d.doctor_name,
    dep.dept_name,
    dm.ym AS work_month,
    COALESCE(ac.appt_count, 0)  AS appointment_count,
    COALESCE(rc.record_count, 0) AS record_count,
    COALESCE(pc.prescription_count, 0) AS prescription_count
FROM (
    SELECT doctor_id, DATE_FORMAT(appointment_date, '%Y-%m') AS ym FROM appointments
    UNION
    SELECT doctor_id, DATE_FORMAT(visit_date, '%Y-%m') AS ym FROM medical_records
    UNION
    SELECT doctor_id, DATE_FORMAT(prescription_date, '%Y-%m') AS ym FROM prescriptions
) dm
JOIN doctors d       ON d.doctor_id = dm.doctor_id
JOIN departments dep ON dep.dept_id = d.dept_id
LEFT JOIN (
    SELECT doctor_id, DATE_FORMAT(appointment_date, '%Y-%m') AS ym, COUNT(*) AS appt_count
    FROM appointments GROUP BY doctor_id, ym
) ac ON ac.doctor_id = dm.doctor_id AND ac.ym = dm.ym
LEFT JOIN (
    SELECT doctor_id, DATE_FORMAT(visit_date, '%Y-%m') AS ym, COUNT(*) AS record_count
    FROM medical_records GROUP BY doctor_id, ym
) rc ON rc.doctor_id = dm.doctor_id AND rc.ym = dm.ym
LEFT JOIN (
    SELECT doctor_id, DATE_FORMAT(prescription_date, '%Y-%m') AS ym, COUNT(*) AS prescription_count
    FROM prescriptions GROUP BY doctor_id, ym
) pc ON pc.doctor_id = dm.doctor_id AND pc.ym = dm.ym
ORDER BY dm.ym DESC, appointment_count DESC;

-- ----------------------------------------------------------------------------
-- 4. STORED PROCEDURES
-- ----------------------------------------------------------------------------

DELIMITER $$

-- 4.1 Generate a bill from a prescription (consultation fee + medicine total)
CREATE PROCEDURE sp_generate_bill(IN p_prescription_id INT, IN p_created_by INT)
BEGIN
    DECLARE v_patient_id INT;
    DECLARE v_doctor_id INT;
    DECLARE v_consultation_fee DECIMAL(10,2);
    DECLARE v_medicine_fee DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_existing_bill INT;

    SELECT patient_id, doctor_id, total_amount
      INTO v_patient_id, v_doctor_id, v_medicine_fee
      FROM prescriptions
      WHERE prescription_id = p_prescription_id;

    IF v_patient_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription not found';
    END IF;

    SELECT COUNT(*) INTO v_existing_bill FROM bills WHERE prescription_id = p_prescription_id;
    IF v_existing_bill > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A bill already exists for this prescription';
    END IF;

    SELECT fee INTO v_consultation_fee FROM doctors WHERE doctor_id = v_doctor_id;

    SET v_total = v_consultation_fee + v_medicine_fee;

    INSERT INTO bills (patient_id, prescription_id, consultation_fee, medicine_fee, other_fee,
                        total_amount, discount, final_amount, payment_status)
    VALUES (v_patient_id, p_prescription_id, v_consultation_fee, v_medicine_fee, 0.00,
            v_total, 0.00, v_total, 'unpaid');

    SELECT LAST_INSERT_ID() AS new_bill_id;
END$$

-- 4.2 Process payment for a bill
CREATE PROCEDURE sp_process_payment(IN p_bill_id INT, IN p_payment_method VARCHAR(20))
BEGIN
    UPDATE bills
    SET payment_status = 'paid',
        payment_method = p_payment_method,
        paid_at = NOW()
    WHERE bill_id = p_bill_id AND payment_status = 'unpaid';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bill not found or already paid';
    END IF;
END$$

-- 4.3 Check whether a medicine has enough stock for a required quantity
CREATE PROCEDURE sp_check_stock(IN p_medicine_id INT, IN p_required_qty INT)
BEGIN
    DECLARE v_stock INT DEFAULT 0;

    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = p_medicine_id;

    SELECT (v_stock >= p_required_qty) AS is_available, v_stock AS current_stock;
END$$

-- 4.4 Dispense a prescription: deduct stock for each line, mark prescription dispensed
CREATE PROCEDURE sp_dispense_prescription(IN p_prescription_id INT)
BEGIN
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_medicine_id INT;
    DECLARE v_quantity INT;
    DECLARE v_stock INT;
    DECLARE v_status VARCHAR(20);

    DECLARE cur CURSOR FOR
        SELECT medicine_id, quantity FROM prescription_details WHERE prescription_id = p_prescription_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT status INTO v_status FROM prescriptions WHERE prescription_id = p_prescription_id;
    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription not found';
    ELSEIF v_status <> 'pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending prescriptions can be dispensed';
    END IF;

    START TRANSACTION;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_medicine_id, v_quantity;
        IF v_done THEN
            LEAVE read_loop;
        END IF;

        SELECT stock_quantity INTO v_stock
          FROM medicines WHERE medicine_id = v_medicine_id FOR UPDATE;

        IF v_stock < v_quantity THEN
            CLOSE cur;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for a medicine in this prescription';
        END IF;

        UPDATE medicines SET stock_quantity = stock_quantity - v_quantity
          WHERE medicine_id = v_medicine_id;
    END LOOP;
    CLOSE cur;

    UPDATE prescriptions SET status = 'dispensed' WHERE prescription_id = p_prescription_id;

    COMMIT;
END$$

-- 4.5 Full medical history for a patient
CREATE PROCEDURE sp_patient_history(IN p_patient_id INT)
BEGIN
    SELECT
        mr.record_id,
        mr.visit_date,
        mr.chief_complaint,
        mr.diagnosis,
        mr.treatment_plan,
        mr.notes,
        d.doctor_name,
        dep.dept_name
    FROM medical_records mr
    JOIN doctors d       ON mr.doctor_id = d.doctor_id
    JOIN departments dep ON d.dept_id = dep.dept_id
    WHERE mr.patient_id = p_patient_id
    ORDER BY mr.visit_date DESC;
END$$

-- 4.6 Daily revenue report: totals + breakdown by payment method
CREATE PROCEDURE sp_daily_revenue(IN p_report_date DATE)
BEGIN
    SELECT
        COUNT(*) AS total_bills,
        COALESCE(SUM(final_amount), 0) AS total_revenue
    FROM bills
    WHERE payment_status = 'paid' AND DATE(paid_at) = p_report_date;

    SELECT
        payment_method,
        COUNT(*) AS bill_count,
        COALESCE(SUM(final_amount), 0) AS revenue
    FROM bills
    WHERE payment_status = 'paid' AND DATE(paid_at) = p_report_date
    GROUP BY payment_method;
END$$

-- 4.7 Cancel an appointment (validated)
CREATE PROCEDURE sp_cancel_appointment(IN p_appointment_id INT)
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT status INTO v_status FROM appointments WHERE appointment_id = p_appointment_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found';
    ELSEIF v_status <> 'scheduled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only scheduled appointments can be cancelled';
    ELSE
        UPDATE appointments SET status = 'cancelled' WHERE appointment_id = p_appointment_id;
    END IF;
END$$

-- 4.8 Search doctors in a department, on a date, with fewer than 20 bookings
CREATE PROCEDURE sp_search_available_doctors(IN p_dept_id INT, IN p_date DATE)
BEGIN
    SELECT
        d.doctor_id,
        d.doctor_name,
        d.title,
        d.fee,
        dep.dept_name,
        COUNT(a.appointment_id) AS booked_count
    FROM doctors d
    JOIN departments dep ON d.dept_id = dep.dept_id
    LEFT JOIN appointments a
        ON a.doctor_id = d.doctor_id
       AND a.appointment_date = p_date
       AND a.status = 'scheduled'
    WHERE d.dept_id = p_dept_id AND d.is_active = TRUE
    GROUP BY d.doctor_id, d.doctor_name, d.title, d.fee, dep.dept_name
    HAVING booked_count < 20
    ORDER BY booked_count ASC;
END$$

DELIMITER ;

-- ----------------------------------------------------------------------------
-- 5. TRIGGERS
-- ----------------------------------------------------------------------------

DELIMITER $$

-- 5.1 Recalculate prescription total after a detail line is inserted
CREATE TRIGGER trg_update_prescription_total
AFTER INSERT ON prescription_details
FOR EACH ROW
BEGIN
    UPDATE prescriptions
    SET total_amount = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM prescription_details
        WHERE prescription_id = NEW.prescription_id
    )
    WHERE prescription_id = NEW.prescription_id;
END$$

-- 5.2 Recalculate prescription total after a detail line is updated
CREATE TRIGGER trg_update_prescription_total_update
AFTER UPDATE ON prescription_details
FOR EACH ROW
BEGIN
    UPDATE prescriptions
    SET total_amount = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM prescription_details
        WHERE prescription_id = NEW.prescription_id
    )
    WHERE prescription_id = NEW.prescription_id;
END$$

-- 5.3 Prevent duplicate scheduled appointments for the same patient/doctor/date/slot
CREATE TRIGGER trg_check_duplicate_appointment
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    DECLARE v_count INT;

    SELECT COUNT(*) INTO v_count
    FROM appointments
    WHERE patient_id = NEW.patient_id
      AND doctor_id = NEW.doctor_id
      AND appointment_date = NEW.appointment_date
      AND time_slot = NEW.time_slot
      AND status = 'scheduled';

    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Duplicate appointment: this patient already has a scheduled appointment with this doctor at this date/time slot';
    END IF;
END$$

DELIMITER ;
