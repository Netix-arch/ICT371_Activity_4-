# Mulungushi University - ICT371 PostgreSQL Scenario Assignment

## Overview
This repository contains solutions for four PostgreSQL (PL/pgSQL) scenarios as part of the ICT371 assignment requirements. Each script is self-contained and implements relational database design, conditional branching, loops, stored procedures, exception handling, and explicit cursors.

---

## Scenarios Implemented

1. **Scenario 1: University Library Book Loans** (`scenario_1_202400975.sql`)
   * Tracks books and available copies.
   * Manages student book loans and returns with validation and idempotency checks.

2. **Scenario 2: Computer Laboratory Reservations** (`scenario_2_202400975.sql`)
   * Manages laboratory practical sessions and workstation capacities.
   * Handles reservations, cancellations, and capacity constraints.

3. **Scenario 3: Student Hostel Room Allocation** (`scenario_3_202400975.sql`)
   * Tracks hostel rooms and bed space availability.
   * Handles student room allocations, check-outs, and input validations.

4. **Scenario 4: Campus Clinic Medicine Dispensing** (`scenario_4_202400975.sql`)
   * Tracks clinic medicine stock quantities.
   * Handles medication dispensing, error reversals, and threshold warnings.

---

## File Naming Convention
All files follow the required assignment format:
`scenario_number_student_number.sql` *(e.g., `scenario_1_202400975.sql`)*

---

## How to Run the Scripts
1. Open **pgAdmin** and connect to your PostgreSQL server.
2. Open the **Query Tool** on your target database.
3. Open one of the `.sql` files, paste the script into the Query Tool, and click **Execute (F5)**.
4. Review the **Messages / Notice** output tab to see procedural notices, loops, cursor logs, and exception handling messages.
2. Open the **Query Tool** on your target database.
3. Open one of the `.sql` files, paste the script into the Query Tool, and click **Execute (F5)**.
4. Review the **Messages / Notice** output tab to see procedural notices, loops, cursor logs, and exception handling messages.
