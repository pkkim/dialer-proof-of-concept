DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

CREATE TABLE IF NOT EXISTS phone_bank (
	id SERIAL PRIMARY KEY,
	name VARCHAR
);

-- A single number within a phone bank.
CREATE TABLE IF NOT EXISTS phone_bank_number (
	id SERIAL PRIMARY KEY,
	phone_bank_id INTEGER REFERENCES phone_bank(id),
	phone_number VARCHAR(12),
	status VARCHAR(1) NOT NULL,
	assigned_until TIMESTAMPTZ,
	assigned_to VARCHAR,
	result VARCHAR(1),
	CHECK (NOT(status = 'C') OR result IS NOT NULL),
    CHECK (NOT(status = 'A') OR assigned_until IS NOT NULL),
    CHECK (NOT(status = 'A') OR assigned_to IS NOT NULL)
);
CREATE UNIQUE INDEX phone_bank_number_phone_bank_id_phone_number
    ON phone_bank_number (phone_bank_id, phone_number);


-- statuses:
-- - P[ending]: not assigned, not called
-- - A[ssigned]: assigned until X time
-- - C[alled]: already called (should have a result)

-- results: for now, just 'G' and 'B'.