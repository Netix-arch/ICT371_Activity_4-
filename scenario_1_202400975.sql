-- Scenario 1: University Library Book Loans
-- File naming format: scenario_1_student_number.sql

-- Clean up existing tables and procedures if re-running
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP PROCEDURE IF EXISTS borrow_book(INT, VARCHAR, INT);
DROP PROCEDURE IF EXISTS return_book(INT);

-- 1. Create books and book_loans tables and add at least three books
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES books(book_id),
    student_number VARCHAR(50) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    loan_status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO books (title, available_copies) VALUES
('Database System Concepts', 5),
('Introduction to Algorithms', 2),
('PostgreSQL Up and Running', 0);

-- 2. Use IF ELSIF ELSE to display book stock status
DO $$
DECLARE
    v_copies INT;
BEGIN
    SELECT available_copies INTO v_copies FROM books WHERE book_id = 1;
    
    IF v_copies = 0 THEN
        RAISE NOTICE 'Book 1 is unavailable.';
    ELSIF v_copies < 3 THEN
        RAISE NOTICE 'Book 1 is low on copies (Only % left).', v_copies;
    ELSE
        RAISE NOTICE 'Book 1 is sufficiently stocked (% copies available).', v_copies;
    END IF;
END $$;

-- 3. Use WHILE for overdue reminders and numeric FOR for shelf numbers
DO $$
DECLARE
    v_counter INT := 1;
    v_shelf INT;
BEGIN
    RAISE NOTICE '--- Overdue Reminders (WHILE Loop) ---';
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Overdue Reminder Notice #%', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    RAISE NOTICE '--- Library Shelves (FOR Loop) ---';
    FOR v_shelf IN 1..3 LOOP
        RAISE NOTICE 'Checking Library Shelf Number: SHLF-00%', v_shelf;
    END LOOP;
END $$;

-- 4. Create borrow_book procedure
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: % copies. Quantity must be greater than zero.', p_quantity;
    END IF;

    SELECT available_copies INTO v_available
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book with ID % does not exist.', p_book_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE EXCEPTION 'Request exceeds available copies. Available: %, Requested: %', v_available, p_quantity;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans (book_id, student_number, quantity, loan_status)
    VALUES (p_book_id, p_student_number, p_quantity, 'ACTIVE');

    RAISE NOTICE 'Successfully borrowed % copy(ies) of book ID % for student %.', p_quantity, p_book_id, p_student_number;
END;
$$;

-- 5. Call borrow_book for two valid loans and one exceeding available copies
CALL borrow_book(1, 'STU1001', 2);
CALL borrow_book(2, 'STU1002', 1);

DO $$
BEGIN
    CALL borrow_book(3, 'STU1003', 1);
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Caught expected error for exceeding stock: %', SQLERRM;
END $$;

SELECT * FROM books;
SELECT * FROM book_loans;

-- 6. Create return_book procedure (idempotent: second call does not restore copies again)
CREATE OR REPLACE PROCEDURE return_book(
    p_loan_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INT;
    v_quantity INT;
    v_status VARCHAR;
BEGIN
    SELECT book_id, quantity, loan_status
    INTO v_book_id, v_quantity, v_status
    FROM book_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan ID % not found.', p_loan_id;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan ID % has already been returned. No changes made.', p_loan_id;
        RETURN;
    END IF;

    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    UPDATE books
    SET available_copies = available_copies + v_quantity
    WHERE book_id = v_book_id;

    RAISE NOTICE 'Loan ID % successfully returned. % copies restored to book ID %.', p_loan_id, v_quantity, v_book_id;
END;
$$;

CALL return_book(1);
CALL return_book(1); -- Second call test for idempotency

-- 7. Use an explicit cursor to display books with few copies remaining (< 3)
DO $$
DECLARE
    cur_low_stock CURSOR FOR 
        SELECT book_id, title, available_copies 
        FROM books 
        WHERE available_copies < 3;
    r_book RECORD;
BEGIN
    RAISE NOTICE '--- Books with Few Copies Remaining (Explicit Cursor) ---';
    OPEN cur_low_stock;
    LOOP
        FETCH cur_low_stock INTO r_book;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Book ID: %, Title: %, Available Copies: %', r_book.book_id, r_book.title, r_book.available_copies;
    END LOOP;
    CLOSE cur_low_stock;
END $$;

-- 8. Try to borrow zero copies and handle invalid quantity with an EXCEPTION block
DO $$
BEGIN
    RAISE NOTICE 'Attempting to borrow 0 copies...';
    CALL borrow_book(1, 'STU9999', 0);
EXCEPTION WHEN others THEN
    RAISE NOTICE 'SUCCESSFUL EXCEPTION HANDLING: Caught invalid quantity error -> %', SQLERRM;
END $$;

-- 9. Query both tables to show final quantities and loan statuses
SELECT 'Final Books Status' AS description, * FROM books;
SELECT 'Final Book Loans Status' AS description, * FROM book_loans;