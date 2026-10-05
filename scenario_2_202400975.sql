-- Scenario 2: Computer Laboratory Reservations
-- File naming format: scenario_2_student_number.sql

DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;
DROP PROCEDURE IF EXISTS reserve_workstations(INT, VARCHAR, INT);
DROP PROCEDURE IF EXISTS cancel_reservation(INT);

-- 1. Create tables and add at least three sessions
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100) NOT NULL,
    workstations_reserved INT NOT NULL CHECK (workstations_reserved > 0),
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('Database Lab A', 30),
('Networking Lab B', 5),
('AI Lab C', 0);

-- 2. Use IF ELSIF ELSE to report workstation status
DO $$
DECLARE
    v_stations INT;
BEGIN
    SELECT available_workstations INTO v_stations FROM lab_sessions WHERE session_id = 1;
    
    IF v_stations = 0 THEN
        RAISE NOTICE 'Lab Session 1 is full (0 workstations).';
    ELSIF v_stations < 10 THEN
        RAISE NOTICE 'Lab Session 1 is nearly full (% workstations left).', v_stations;
    ELSE
        RAISE NOTICE 'Lab Session 1 has enough workstations (% available).', v_stations;
    END IF;
END $$;

-- 3. Use WHILE for reminders and numeric FOR for workstation checks
DO $$
DECLARE
    v_i INT := 1;
    v_check INT;
BEGIN
    RAISE NOTICE '--- Session Preparation Reminders (WHILE Loop) ---';
    WHILE v_i <= 3 LOOP
        RAISE NOTICE 'Reminder #: Check lab software installation - Day %', v_i;
        v_i := v_i + 1;
    END LOOP;

    RAISE NOTICE '--- Workstation Checks (FOR Loop) ---';
    FOR v_check IN 1..3 LOOP
        RAISE NOTICE 'Performing diagnostic check on Workstation WKS-00%', v_check;
    END LOOP;
END $$;

-- 4. Create reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_workstations INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid number of workstations requested: %. Must be greater than zero.', p_workstations;
    END IF;

    SELECT available_workstations INTO v_available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lab session ID % does not exist.', p_session_id;
    END IF;

    IF v_available < p_workstations THEN
        RAISE EXCEPTION 'Request exceeds capacity. Available: %, Requested: %', v_available, p_workstations;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations (session_id, lecturer_name, workstations_reserved, status)
    VALUES (p_session_id, p_lecturer, p_workstations, 'ACTIVE');

    RAISE NOTICE 'Successfully reserved % workstations for session % by lecturer %.', p_workstations, p_session_id, p_lecturer;
END;
$$;

-- 5. Call for two valid reservations and one exceeding capacity
CALL reserve_workstations(1, 'Dr. Smith', 10);
CALL reserve_workstations(2, 'Dr. Banda', 3);

DO $$
BEGIN
    CALL reserve_workstations(3, 'Prof. Phiri', 5);
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Caught expected error for exceeding capacity: %', SQLERRM;
END $$;

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. Create cancel_reservation procedure (idempotent)
CREATE OR REPLACE PROCEDURE cancel_reservation(
    p_reservation_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INT;
    v_workstations INT;
    v_status VARCHAR;
BEGIN
    SELECT session_id, workstations_reserved, status
    INTO v_session_id, v_workstations, v_status
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation ID % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation ID % is already cancelled. No workstations released again.', p_reservation_id;
        RETURN;
    END IF;

    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;

    UPDATE lab_sessions
    SET available_workstations = available_workstations + v_workstations
    WHERE session_id = v_session_id;

    RAISE NOTICE 'Reservation ID % cancelled. % workstations released for session ID %.', p_reservation_id, v_workstations, v_session_id;
END;
$$;

CALL cancel_reservation(1);
CALL cancel_reservation(1); -- Second call test for idempotency

-- 7. Use an explicit cursor to display sessions with few workstations remaining (< 10)
DO $$
DECLARE
    cur_sessions CURSOR FOR 
        SELECT session_id, session_name, available_workstations 
        FROM lab_sessions 
        WHERE available_workstations < 10;
    r_sess RECORD;
BEGIN
    RAISE NOTICE '--- Sessions with Few Workstations Remaining (Explicit Cursor) ---';
    OPEN cur_sessions;
    LOOP
        FETCH cur_sessions INTO r_sess;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Session ID: %, Name: %, Available Workstations: %', r_sess.session_id, r_sess.session_name, r_sess.available_workstations;
    END LOOP;
    CLOSE cur_sessions;
END $$;

-- 8. Request zero workstations and handle invalid quantity with EXCEPTION block
DO $$
BEGIN
    RAISE NOTICE 'Attempting to reserve 0 workstations...';
    CALL reserve_workstations(1, 'Dr. Mwansa', 0);
EXCEPTION WHEN others THEN
    RAISE NOTICE 'SUCCESSFUL EXCEPTION HANDLING: Caught invalid quantity -> %', SQLERRM;
END $$;

-- 9. Query both tables
SELECT 'Final Lab Sessions' AS description, * FROM lab_sessions;
SELECT 'Final Reservations' AS description, * FROM reservations;