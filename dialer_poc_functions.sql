START TRANSACTION ;

-- Begin a phone bank.
CREATE OR REPLACE FUNCTION phone_bank_init(__name VARCHAR, __phone_numbers VARCHAR[]) RETURNS void
LANGUAGE plpgsql AS
$_$
DECLARE
    __phone_bank_id INTEGER;
BEGIN
    INSERT INTO phone_bank (name) VALUES (__name) RETURNING id INTO __phone_bank_id;
    INSERT INTO phone_bank_number (phone_bank_id, phone_number, status, result)
        SELECT __phone_bank_id, pn, 'P', NULL
        FROM UNNEST(__phone_numbers) AS pn;
END;
$_$ SECURITY DEFINER;

-- Assign a phone bank number to __assigned_to, returning the number assigned.
CREATE OR REPLACE FUNCTION phone_number_assign(
    __phone_bank_id INTEGER,
    __assigned_to VARCHAR,
    __assigned_until TIMESTAMPTZ,
    OUT __phone_number VARCHAR
)
LANGUAGE plpgsql AS
$_$
BEGIN
    UPDATE phone_bank_number
        SET assigned_until = __assigned_until,
            assigned_to = __assigned_to,
            status = 'A'
    WHERE id = (
        SELECT id FROM phone_bank_number
        WHERE
        phone_bank_id = __phone_bank_id AND
        (
            (status = 'P') OR
            (status = 'A' AND NOW() > assigned_until)
        )
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    )
    RETURNING phone_number INTO __phone_number;
END;
$_$ SECURITY DEFINER;

-- Mark a phone number as having been called and no longer assigned.
CREATE OR REPLACE FUNCTION phone_number_complete(
    __phone_bank_id INTEGER,
    __phone_number VARCHAR,
    __result VARCHAR,
    OUT __success BOOL
)
LANGUAGE plpgsql AS
$_$
BEGIN
    UPDATE phone_bank_number
        SET assigned_until = NULL,
            assigned_to = NULL,
            status = 'C',
            result = __result
    WHERE
    phone_bank_id = __phone_bank_id AND
    phone_number = __phone_number
    RETURNING id IS NOT NULL INTO __success;
END;
$_$ SECURITY DEFINER;

-- Mark a number within a phone bank as not called and no longer assigned.
CREATE OR REPLACE FUNCTION phone_number_abandon(
    __phone_bank_id INTEGER,
    __phone_number VARCHAR,
    OUT __success BOOL
)
LANGUAGE plpgsql AS
$_$
DECLARE
    __current_status BOOLEAN;
BEGIN
    -- status should be A for assigned
    SELECT status INTO __current_status FROM phone_bank_number
        WHERE phone_bank_id = __phone_bank_id
        AND phone_number = __phone_number;
    IF __current_status <> 'A' THEN
        __success := false;
        RETURN;
    END IF;

    UPDATE phone_bank_number
        SET assigned_to = NULL,
            assigned_until = NULL,
            status = 'P'
        WHERE phone_bank_id = __phone_bank_id
            AND phone_number = __phone_number;
END;
$_$ SECURITY DEFINER;

COMMIT;