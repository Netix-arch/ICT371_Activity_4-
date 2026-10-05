-- Scenario 3: Student Hostel Room Allocation
-- File naming format: scenario_3_student_number.sql

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;
DROP PROCEDURE IF EXISTS allocate_room(INT, VARCHAR);
DROP PROCEDURE IF EXISTS check_out(INT);

-- 1. Create tables and add at least three rooms
CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL,
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INT REFERENCES hostel_rooms(room_id),
    student_number VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ALLOCATED'
);

INSERT INTO hostel_rooms (room_number, available_spaces) VALUES
('Block A-101', 3),
('Block B-202', 1),
('Block C-303', 0);

-- 2. Use IF ELSIF ELSE to report room space status
DO $$
DECLARE
    v_spaces INT;
BEGIN
    SELECT available_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = 1;
    
    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room 1 is full.';
    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room 1 has one space left.';
    ELSE
        RAISE NOTICE 'Room 1 has several spaces (% spaces available).', v_spaces;
    END IF;
END $$;

-- 3. Use WHILE for inspection days and numeric FOR for room checks
DO $$
DECLARE
    v_day INT := 1;
    v_room_chk INT;
BEGIN
    RAISE NOTICE '--- Hostel Inspection Days (WHILE Loop) ---';
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Hostel Hygiene Inspection Day % of 3 scheduled.', v_day;
        v_day := v_day + 1;
    END LOOP;

    RAISE NOTICE '--- Room Checks (FOR Loop) ---';
    FOR v_room_chk IN 1..3 LOOP
        RAISE NOTICE 'Inspecting room structural integrity and lighting - Check #%', v_room_chk;
    END LOOP;
END $$;

-- 4. Create allocate_room procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_room_id INT,
    p_student_number VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student_number IS NULL OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Invalid student number: Student number cannot be blank or null.';
    END IF;

    SELECT available_spaces INTO v_spaces
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room ID % does not exist.', p_room_id;
    END IF;

    IF v_spaces <= 0 THEN
        RAISE EXCEPTION 'Room ID % is full. No available bed spaces.', p_room_id;
    END IF;

    UPDATE hostel_rooms
    SET available_spaces = available_spaces - 1
    WHERE room_id = p_room_id;

    INSERT INTO allocations (room_id, student_number, status)
    VALUES (p_room_id, p_student_number, 'ALLOCATED');

    RAISE NOTICE 'Successfully allocated bed space in room ID % to student %.', p_room_id, p_student_number;
END;
$$;

-- 5. Call for two valid allocations and one allocation to a full room
CALL allocate_room(1, 'MU/2026/001');
CALL allocate_room(2, 'MU/2026/002');

DO $$
BEGIN
    CALL allocate_room(3, 'MU/2026/003');
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Caught expected error for full room: %', SQLERRM;
END $$;

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. Create check_out procedure (idempotent)
CREATE OR REPLACE PROCEDURE check_out(
    p_allocation_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INT;
    v_status VARCHAR;
BEGIN
    SELECT room_id, status
    INTO v_room_id, v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Allocation ID % not found.', p_allocation_id;
    END IF;

    IF v_status = 'COMPLETED' THEN
        RAISE NOTICE 'Allocation ID % is already checked out. No space freed again.', p_allocation_id;
        RETURN;
    END IF;

    UPDATE allocations
    SET status = 'COMPLETED'
    WHERE allocation_id = p_allocation_id;

    UPDATE hostel_rooms
    SET available_spaces = available_spaces + 1
    WHERE room_id = v_room_id;

    RAISE NOTICE 'Allocation ID % checked out. Bed space freed in room ID %.', p_allocation_id, v_room_id;
END;
$$;

CALL check_out(1);
CALL check_out(1); -- Second call test for idempotency

-- 7. Use an explicit cursor to display full or nearly full rooms (available_spaces <= 1)
DO $$
DECLARE
    cur_rooms CURSOR FOR 
        SELECT room_id, room_number, available_spaces 
        FROM hostel_rooms 
        WHERE available_spaces <= 1;
    r_room RECORD;
BEGIN
    RAISE NOTICE '--- Full or Nearly Full Rooms (Explicit Cursor) ---';
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO r_room;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Room ID: %, Room Number: %, Available Spaces: %', r_room.room_id, r_room.room_number, r_room.available_spaces;
    END LOOP;
    CLOSE cur_rooms;
END $$;

-- 8. Attempt allocation using blank student number and handle with EXCEPTION block
DO $$
BEGIN
    RAISE NOTICE 'Attempting allocation with blank student number...';
    CALL allocate_room(1, '   ');
EXCEPTION WHEN others THEN
    RAISE NOTICE 'SUCCESSFUL EXCEPTION HANDLING: Caught invalid input -> %', SQLERRM;
END $$;

-- 9. Query both tables
SELECT 'Final Hostel Rooms' AS description, * FROM hostel_rooms;
SELECT 'Final Allocations' AS description, * FROM allocations;