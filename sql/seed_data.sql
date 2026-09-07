-- ============================================================================
-- Hospital Outpatient Management System — Seed / Demo Data
-- Run AFTER sql/schema.sql has created the schema.
--
-- Usage:
--   mysql -u root -p hospital_outpatient_db < sql/seed_data.sql
--   (or)  SOURCE sql/seed_data.sql;   -- from inside the mysql client, db selected
--
-- Note: appointment dates use CURDATE() / DATE_SUB(...) so the "today" and
-- "past" appointments always stay correct relative to whenever this file
-- is executed.
-- ============================================================================

USE hospital_outpatient_db;

-- ----------------------------------------------------------------------------
-- 1. Departments (8)
-- ----------------------------------------------------------------------------
INSERT INTO departments (dept_name, dept_location, phone, description) VALUES
('Internal Medicine', 'Building A, 2nd Floor', '021-55510001', 'Diagnoses and treats general adult illnesses, chronic disease management.'),
('Surgery',            'Building A, 3rd Floor', '021-55510002', 'General and minor surgical procedures, wound care, pre/post-op consultation.'),
('Pediatrics',         'Building B, 1st Floor', '021-55510003', 'Outpatient care for infants, children, and adolescents.'),
('Cardiology',         'Building A, 4th Floor', '021-55510004', 'Diagnosis and management of heart and vascular conditions.'),
('Dermatology',        'Building B, 2nd Floor', '021-55510005', 'Skin, hair, and nail conditions, allergy and rash treatment.'),
('Orthopedics',        'Building A, 5th Floor', '021-55510006', 'Bone, joint, and muscle injuries and disorders.'),
('Ophthalmology',      'Building B, 3rd Floor', '021-55510007', 'Eye examinations and treatment of vision-related conditions.'),
('ENT',                'Building B, 4th Floor', '021-55510008', 'Ear, nose, and throat diagnosis and treatment.');

-- ----------------------------------------------------------------------------
-- 2. Doctors (10)
-- ----------------------------------------------------------------------------
INSERT INTO doctors (doctor_name, gender, title, dept_id, phone, email, specialty, fee, is_active) VALUES
('Wang Jianguo', 'M', 'Chief Physician',            1, '13911110001', 'wang.jianguo@hospital.com',   'Chronic disease management, diabetes', 50.00, TRUE),
('Li Xiulan',    'F', 'Attending Physician',        1, '13911110002', 'li.xiulan@hospital.com',      'General internal medicine',            30.00, TRUE),
('Zhang Wei',    'M', 'Chief Physician',            2, '13911110003', 'zhang.wei@hospital.com',      'General and minor surgery',            60.00, TRUE),
('Zhao Min',     'F', 'Attending Physician',        3, '13911110004', 'zhao.min@hospital.com',       'Pediatric respiratory conditions',     35.00, TRUE),
('Liu Yang',     'M', 'Chief Physician',            4, '13911110005', 'liu.yang@hospital.com',       'Interventional cardiology',            70.00, TRUE),
('Chen Jing',    'F', 'Associate Chief Physician',  4, '13911110006', 'chen.jing@hospital.com',      'Arrhythmia, hypertension',             55.00, TRUE),
('Yang Fan',     'M', 'Attending Physician',        5, '13911110007', 'yang.fan@hospital.com',       'Dermatitis, eczema, acne',              40.00, TRUE),
('Huang Lei',    'M', 'Chief Physician',            6, '13911110008', 'huang.lei@hospital.com',      'Sports injuries, spine disorders',     65.00, TRUE),
('Zhou Ting',    'F', 'Attending Physician',        7, '13911110009', 'zhou.ting@hospital.com',      'Cataract, conjunctivitis',              38.00, TRUE),
('Wu Qiang',     'M', 'Associate Chief Physician',  8, '13911110010', 'wu.qiang@hospital.com',       'Sinusitis, hearing disorders',          45.00, TRUE);

-- ----------------------------------------------------------------------------
-- 3. Patients (12)
-- ----------------------------------------------------------------------------
INSERT INTO patients (patient_name, gender, birth_date, id_card, phone, address, blood_type, allergy_history) VALUES
('Sun Li',        'F', '1985-03-12', '110105198503120021', '13800000001', 'No. 12, Wangjing West Road, Chaoyang District, Beijing',        'A+',  'Penicillin allergy'),
('Ma Chao',        'M', '1990-07-22', '110105199007220032', '13800000002', 'No. 45, Jianguo Road, Chaoyang District, Beijing',               'O+',  NULL),
('Zhu Dan',         'F', '1978-11-05', '110105197811050043', '13800000003', 'No. 8, Fuxing Street, Haidian District, Beijing',                 'B+',  'Seafood allergy'),
('Hu Jun',           'M', '1965-01-30', '110105196501300054', '13800000004', 'No. 101, Zhongguancun Avenue, Haidian District, Beijing',        'AB+', NULL),
('Guo Jingyi',        'F', '2001-09-14', '110105200109140065', '13800000005', 'No. 22, Chaowai Street, Chaoyang District, Beijing',             'O-',  'None known'),
('He Weidong',         'M', '1995-05-08', '110105199505080076', '13800000006', 'No. 6, Xisanqi Road, Haidian District, Beijing',                  'A-',  NULL),
('Gao Feng',            'M', '1972-12-25', '110105197212250087', '13800000007', 'No. 30, Dongzhimen Street, Dongcheng District, Beijing',          'B-',  'Dust and pollen allergy'),
('Lin Xiaowen',          'F', '1988-04-18', '110105198804180098', '13800000008', 'No. 17, Xidan North Street, Xicheng District, Beijing',            'AB-', NULL),
('Zheng Tianyu',          'M', '1999-06-30', '110105199906300109', '13800000009', 'No. 88, Guangqumen Street, Chongwen District, Beijing',            'O+',  NULL),
('Xie Yuxin',              'F', '1993-02-17', '110105199302170110', '13800000010', 'No. 5, Andingmen Street, Dongcheng District, Beijing',              'A+',  'Allergic to sulfa drugs'),
('Luo Jianjun',             'M', '1960-08-09', '110105196008090121', '13800000011', 'No. 60, Yonghegong Street, Dongcheng District, Beijing',           'B+',  NULL),
('Han Meimei',               'F', '1982-10-21', '110105198210210132', '13800000012', 'No. 3, Xinjiekou Street, Xicheng District, Beijing',                'O+',  NULL);

-- ----------------------------------------------------------------------------
-- 4. Users — system login accounts (7)
--    Passwords below are for the demo accounts described in README.md.
--    Hashes were generated with werkzeug.security.generate_password_hash
--    using method="pbkdf2:sha256" (see requirements.txt for the pinned version).
-- ----------------------------------------------------------------------------
INSERT INTO users (username, password_hash, role, real_name, phone, is_active) VALUES
('admin',       'pbkdf2:sha256:1000000$OJcvaqmxI60DsL07$978181f2b9799d69d30606d989500a3ec7933741f8398d84a48b821f2911f300', 'admin',        'System Administrator', '13900000001', TRUE),
('reception1',  'pbkdf2:sha256:1000000$1eBKxkWwWQBiS4C1$95db403338b7da8b28287c2a55fa7ac1b3386f914c9b0a6b88a8ee8f7f3216d6', 'receptionist', 'Qian Fei',              '13900000002', TRUE),
('reception2',  'pbkdf2:sha256:1000000$PKyTxBKKR8AkV4iC$e1c75af2dfcbf0a038511b600022794f9253622ebafa3cb1edbce218cb763e0f', 'receptionist', 'Sun Ya',                '13900000003', TRUE),
('doctor1',     'pbkdf2:sha256:1000000$J2Phgug4tVw7iKG2$a54b09a042d8e73083178f0f77a4271487034c165000da8f014971388df177a2', 'doctor',       'Wang Jianguo',          '13911110001', TRUE),
('doctor2',     'pbkdf2:sha256:1000000$u2DnRREbnld9WwjR$0cf604117b9554f8a1dd651bf6009bf65015ec523492dae9770fe1ad8c30ebac', 'doctor',       'Liu Yang',              '13911110005', TRUE),
('pharmacist1', 'pbkdf2:sha256:1000000$F5g9h24qLHKyzM3u$81b5735f3eece4f04817bc5ff58c1c86a88713761f713a3a44cee86d2c233970', 'pharmacist',   'Feng Li',               '13900000004', TRUE),
('cashier1',    'pbkdf2:sha256:1000000$qKEutpVPomVOCK2o$983322ca0e694f422c0d001a74a1c0f5b0c785284846ffaaa2ceb12309afea25', 'cashier',      'Zhao Qian',             '13900000005', TRUE);

-- ----------------------------------------------------------------------------
-- 5. Medicines (15) across all required categories
-- ----------------------------------------------------------------------------
INSERT INTO medicines (medicine_name, generic_name, category, specification, manufacturer, unit_price, stock_quantity, min_stock, expiry_date, is_active) VALUES
('Amoxicillin Capsules',            'Amoxicillin',        'Antibiotics',       '0.25g x 24 capsules', 'Huarui Pharma',    15.50, 200, 30, '2027-06-30', TRUE),
('Paracetamol Tablets',              'Paracetamol',         'Antipyretics',      '0.5g x 20 tablets',   'Kanglin Pharma',   8.00, 300, 50, '2027-08-31', TRUE),
('Ibuprofen Suspension',              'Ibuprofen',            'Analgesics',        '100ml/bottle',        'Renhe Pharma',    12.50, 120, 30, '2026-12-31', TRUE),
('Diclofenac Sodium Tablets',          'Diclofenac',            'Analgesics',        '25mg x 20 tablets',   'Kanglin Pharma',   9.90,   8, 20, '2027-03-31', TRUE),
('Omeprazole Capsules',                 'Omeprazole',             'Gastrointestinal',  '20mg x 14 capsules',  'Huarui Pharma',   18.00,  90, 20, '2027-05-31', TRUE),
('Domperidone Tablets',                  'Domperidone',             'Gastrointestinal',  '10mg x 30 tablets',   'Renhe Pharma',    14.00,  60, 15, '2027-01-31', TRUE),
('Metformin Tablets',                     'Metformin',                'Antidiabetic',      '0.5g x 30 tablets',   'Kanglin Pharma',  16.80, 100, 25, '2027-09-30', TRUE),
('Amlodipine Tablets',                     'Amlodipine',                'Antihypertensive',  '5mg x 14 tablets',    'Huarui Pharma',   20.00,  75, 20, '2027-04-30', TRUE),
('Losartan Potassium Tablets',               'Losartan',                   'Antihypertensive',  '50mg x 14 tablets',   'Renhe Pharma',    25.00,   5, 15, '2027-02-28', TRUE),
('Loratadine Tablets',                        'Loratadine',                  'Antihistamines',    '10mg x 12 tablets',   'Kanglin Pharma',  11.00, 150, 30, '2027-07-31', TRUE),
('Vitamin C Tablets',                          'Ascorbic Acid',                'Vitamins',          '0.1g x 100 tablets',  'Huarui Pharma',    6.50, 500, 100, '2028-01-31', TRUE),
('Sodium Chloride Injection',                    'Sodium Chloride',              'Infusion',          '0.9% 250ml/bag',      'Renhe Pharma',     4.00, 400, 100, '2027-10-31', TRUE),
('Compound Ketoconazole Cream',                    'Ketoconazole',                  'Dermatological',    '15g/tube',            'Kanglin Pharma',  13.50,  40, 10, '2027-06-30', TRUE),
('Compound Liquorice Tablets',                      'Liquorice Extract',              'Cough Medicine',    '0.3g x 100 tablets',  'Huarui Pharma',    7.20,  12, 20, '2027-03-31', TRUE),
('Calcium Carbonate D3 Tablets',                      'Calcium Carbonate/Vit D3',       'Supplements',       '0.6g x 60 tablets',   'Renhe Pharma',    18.00, 180, 40, '2028-02-28', TRUE);

-- ----------------------------------------------------------------------------
-- 6. Appointments (15): first 5 are past & completed, next 10 are today & scheduled
--    (insertion order fixes appointment_id 1-5 = completed, 6-15 = today)
-- ----------------------------------------------------------------------------
INSERT INTO appointments (patient_id, doctor_id, appointment_date, time_slot, status, symptoms, created_by) VALUES
(1,  1, DATE_SUB(CURDATE(), INTERVAL 10 DAY), '09:00-09:30', 'completed', 'Fever, cough, and sore throat for 3 days', 2),
(2,  5, DATE_SUB(CURDATE(), INTERVAL 7  DAY), '10:00-10:30', 'completed', 'Chest tightness and palpitations for 1 week', 2),
(3,  7, DATE_SUB(CURDATE(), INTERVAL 5  DAY), '11:00-11:30', 'completed', 'Itchy rash on both forearms for 4 days', 3),
(4,  8, DATE_SUB(CURDATE(), INTERVAL 3  DAY), '14:00-14:30', 'completed', 'Lower back pain radiating to left leg after lifting', 3),
(5,  9, DATE_SUB(CURDATE(), INTERVAL 1  DAY), '15:30-16:00', 'completed', 'Blurred vision and redness in right eye for 2 days', 2),
(6,  2, CURDATE(), '08:00-08:30', 'scheduled', 'Routine follow-up for hypertension', 2),
(7,  3, CURDATE(), '08:30-09:00', 'scheduled', 'Child with mild fever and runny nose', 3),
(8,  6, CURDATE(), '09:00-09:30', 'scheduled', 'Irregular heartbeat sensation', 2),
(9, 10, CURDATE(), '09:30-10:00', 'scheduled', 'Ear pain and reduced hearing', 3),
(10, 1, CURDATE(), '10:00-10:30', 'scheduled', 'Follow-up for diabetes management', 2),
(11, 5, CURDATE(), '10:30-11:00', 'scheduled', 'Shortness of breath on exertion', 3),
(12, 7, CURDATE(), '11:00-11:30', 'scheduled', 'New skin lesion on left arm', 2),
(1,  8, CURDATE(), '14:00-14:30', 'scheduled', 'Knee pain after exercise', 2),
(2,  9, CURDATE(), '14:30-15:00', 'scheduled', 'Annual eye check-up', 3),
(3, 10, CURDATE(), '15:00-15:30', 'scheduled', 'Persistent sinus congestion', 2);

-- ----------------------------------------------------------------------------
-- 7. Medical records (5), linked to the 5 completed appointments above
-- ----------------------------------------------------------------------------
INSERT INTO medical_records (patient_id, doctor_id, appointment_id, visit_date, chief_complaint, diagnosis, treatment_plan, notes) VALUES
(1, 1, 1, DATE_SUB(NOW(), INTERVAL 10 DAY), 'Fever, cough, sore throat for 3 days',
    'Acute upper respiratory tract infection',
    'Rest, hydration, oral antibiotics and antipyretics as prescribed',
    'Follow up in 5 days if symptoms persist'),
(2, 5, 2, DATE_SUB(NOW(), INTERVAL 7 DAY), 'Chest tightness and palpitations for 1 week',
    'Sinus tachycardia, rule out mild arrhythmia',
    'ECG monitoring, reduce caffeine intake, prescribed antihypertensive',
    'Refer to cardiology follow-up in 2 weeks'),
(3, 7, 3, DATE_SUB(NOW(), INTERVAL 5 DAY), 'Itchy rash on both forearms for 4 days',
    'Contact dermatitis',
    'Topical corticosteroid cream, avoid known irritants',
    'None'),
(4, 8, 4, DATE_SUB(NOW(), INTERVAL 3 DAY), 'Lower back pain radiating to left leg after lifting heavy object',
    'Lumbar muscle strain',
    'NSAIDs, physical therapy, rest for 1 week',
    'X-ray shows no fracture'),
(5, 9, 5, DATE_SUB(NOW(), INTERVAL 1 DAY), 'Blurred vision and redness in right eye for 2 days',
    'Acute conjunctivitis',
    'Antibiotic eye drops substitute (oral), avoid touching/rubbing eyes',
    'Return if no improvement in 3 days');

-- ----------------------------------------------------------------------------
-- 8. Prescriptions (5), linked to the 5 medical records above
--    total_amount starts at 0.00; trg_update_prescription_total recalculates
--    it automatically as prescription_details rows are inserted below.
-- ----------------------------------------------------------------------------
INSERT INTO prescriptions (record_id, patient_id, doctor_id, prescription_date, status, total_amount) VALUES
(1, 1, 1, DATE_SUB(NOW(), INTERVAL 10 DAY), 'dispensed', 0.00),
(2, 2, 5, DATE_SUB(NOW(), INTERVAL 7 DAY),  'dispensed', 0.00),
(3, 3, 7, DATE_SUB(NOW(), INTERVAL 5 DAY),  'dispensed', 0.00),
(4, 4, 8, DATE_SUB(NOW(), INTERVAL 3 DAY),  'dispensed', 0.00),
(5, 5, 9, DATE_SUB(NOW(), INTERVAL 1 DAY),  'dispensed', 0.00);

-- ----------------------------------------------------------------------------
-- 9. Prescription details (12 rows, multiple medicines per prescription)
--    Each insert fires trg_update_prescription_total to keep totals in sync.
-- ----------------------------------------------------------------------------
INSERT INTO prescription_details (prescription_id, medicine_id, quantity, dosage, unit_price, subtotal) VALUES
-- prescription 1 (Sun Li — respiratory infection) -> total 39.00
(1, 1, 2, '1 capsule 3 times daily after meals for 7 days', 15.50, 31.00),
(1, 2, 1, '1 tablet as needed for fever, max 4 times daily', 8.00, 8.00),
-- prescription 2 (Ma Chao — cardiology) -> total 26.50
(2, 8, 1, '1 tablet once daily in the morning', 20.00, 20.00),
(2, 11, 1, '1 tablet once daily', 6.50, 6.50),
-- prescription 3 (Zhu Dan — dermatitis) -> total 24.50
(3, 13, 1, 'Apply a thin layer to affected area twice daily', 13.50, 13.50),
(3, 10, 1, '1 tablet once daily for itching', 11.00, 11.00),
-- prescription 4 (Hu Jun — lumbar strain) -> total 59.90
(4, 4, 1, '1 tablet twice daily after meals', 9.90, 9.90),
(4, 15, 2, '1 tablet daily with food', 18.00, 36.00),
(4, 6, 1, '1 tablet before meals to protect the stomach', 14.00, 14.00),
-- prescription 5 (Guo Jingyi — conjunctivitis) -> total 33.00
(5, 1, 1, '1 capsule 3 times daily for 5 days', 15.50, 15.50),
(5, 11, 1, '1 tablet once daily', 6.50, 6.50),
(5, 10, 1, '1 tablet at night if itching occurs', 11.00, 11.00);

-- ----------------------------------------------------------------------------
-- 10. Bills (5), linked to the 5 prescriptions above, all paid
-- ----------------------------------------------------------------------------
INSERT INTO bills (patient_id, prescription_id, bill_date, consultation_fee, medicine_fee, other_fee, total_amount, discount, final_amount, payment_status, payment_method, paid_at) VALUES
(1, 1, DATE_SUB(NOW(), INTERVAL 10 DAY), 50.00, 39.00, 0.00, 89.00,  0.00, 89.00,  'paid', 'cash',       DATE_SUB(NOW(), INTERVAL 10 DAY)),
(2, 2, DATE_SUB(NOW(), INTERVAL 7 DAY),  70.00, 26.50, 0.00, 96.50,  0.00, 96.50,  'paid', 'card',       DATE_SUB(NOW(), INTERVAL 7 DAY)),
(3, 3, DATE_SUB(NOW(), INTERVAL 5 DAY),  40.00, 24.50, 0.00, 64.50,  5.00, 59.50,  'paid', 'mobile_pay', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(4, 4, DATE_SUB(NOW(), INTERVAL 3 DAY),  65.00, 59.90, 0.00, 124.90, 0.00, 124.90, 'paid', 'insurance',  DATE_SUB(NOW(), INTERVAL 3 DAY)),
(5, 5, DATE_SUB(NOW(), INTERVAL 1 DAY),  38.00, 33.00, 0.00, 71.00,  1.00, 70.00,  'paid', 'cash',       DATE_SUB(NOW(), INTERVAL 1 DAY));
