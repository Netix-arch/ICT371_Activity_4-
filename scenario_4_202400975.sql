-- Scenario 4: Campus Clinic Medicine Dispensing
-- File naming format: scenario_4_student_number.sql

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;
DROP PROCEDURE IF EXISTS dispense_medicine(INT, VARCHAR, INT);
DROP PROCEDURE IF EXISTS reverse_dispensing(INT);

-- 1. Create tables and add at least three medicines
CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id),
    student_number VARCHAR(50) NOT NULL,
    quantity_dispensed INT NOT NULL CHECK (quantity_dispensed > 0),
    status VARCHAR(50) NOT NULL DEFAULT 'DISPENSED'
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol 500mg', 100),
('Ibuprofen 400mg', 8),
('Amoxicillin 250mg', 0);

-- 2. Use IF ELSIF ELSE to report medicine stock status
DO $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = 3;
    
    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine 3 is out of stock.';
    ELSIF v_stock < 20 THEN
        RAISE NOTICE 'Medicine 3 is low on stock (% units left).', v_stock;
    ELSE
        RAISE NOTICE 'Medicine 3 is sufficiently stocked (% units).', v_stock;
    END IF;
END $$;

-- 3. Use WHILE for stock review days and numeric FOR for shelf inspections
DO $$
DECLARE
    v_day INT := 1;
    v_shelf INT;
BEGIN
    RAISE NOTICE '--- Stock Review Days (WHILE Loop) ---';
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Clinic Medicine Inventory Review Day % of 3.', v_day;
        v_day := v_day + 1;
    END LOOP;

    RAISE NOTICE '--- Shelf Inspections (FOR Loop) ---';
    FOR v_shelf IN 1..3 LOOP
        RAISE NOTICE 'Inspecting Clinic Pharmacy Shelf #%', v_shelf;
    END LOOP;
END $$;

-- 4. Create dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. Quantity must be greater than zero.', p_quantity;
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine ID % does not exist.', p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Requested quantity exceeds available stock. Stock: %, Requested: %', v_stock, p_quantity;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records (medicine_id, student_number, quantity_dispensed, status)
    VALUES (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

    RAISE NOTICE 'Successfully dispensed % unit(s) of medicine ID % to student %.', p_quantity, p_medicine_id, p_student_number;
END;
$$;

-- 5. Call for two valid quantities and one exceeding stock
CALL dispense_medicine(1, 'STU501', 5);
CALL dispense_medicine(2, 'STU502', 3);

DO $$
BEGIN
    CALL dispense_medicine(3, 'STU503', 2);
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Caught expected error for exceeding stock: %', SQLERRM;
END $$;

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. Create reverse_dispensing procedure (idempotent)
CREATE OR REPLACE PROCEDURE reverse_dispensing(
    p_record_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INT;
    v_quantity INT;
    v_status VARCHAR;
BEGIN
    SELECT medicine_id, quantity_dispensed, status
    INTO v_medicine_id, v_quantity, v_status
    FROM dispensing_records
    WHERE record_id = p_record_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record ID % not found.', p_record_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Dispensing record ID % is already reversed. Stock not restored again.', p_record_id;
        RETURN;
    END IF;

    UPDATE dispensing_records
    SET status = 'REVERSED'
    WHERE record_id = p_record_id;

    UPDATE medicines
    SET stock_quantity = stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;

    RAISE NOTICE 'Dispensing record ID % reversed. % units restored to medicine ID %.', p_record_id, v_quantity, v_medicine_id;
END;
$$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1); -- Second call test for idempotency

-- 7. Use an explicit cursor to display medicines below a low-stock threshold (< 20)
DO $$
DECLARE
    cur_meds CURSOR FOR 
        SELECT medicine_id, medicine_name, stock_quantity 
        FROM medicines 
        WHERE stock_quantity < 20;
    r_med RECORD;
BEGIN
    RAISE NOTICE '--- Medicines Below Low-Stock Threshold (Explicit Cursor) ---';
    OPEN cur_meds;
    LOOP
        FETCH cur_meds INTO r_med;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Medicine ID: %, Name: %, Stock Quantity: %', r_med.medicine_id, r_med.medicine_name, r_med.stock_quantity;
    END LOOP;
    CLOSE cur_meds;
END $$;

-- 8. Request a negative dispensing quantity and handle with EXCEPTION block
DO $$
BEGIN
    RAISE NOTICE 'Attempting to dispense negative quantity...';
    CALL dispense_medicine(1, 'STU999', -5);
EXCEPTION WHEN others THEN
    RAISE NOTICE 'SUCCESSFUL EXCEPTION HANDLING: Caught invalid negative quantity -> %', SQLERRM;
END $$;

-- 9. Query both tables
SELECT 'Final Medicines Stock' AS description, * FROM medicines;
SELECT 'Final Dispensing Records' AS description, * FROM dispensing_records;