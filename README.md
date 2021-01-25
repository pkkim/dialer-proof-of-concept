## What this is

This is a short demonstration of how to use PostgreSQL's locking mechanisms, specifically FOR UPDATE SKIP LOCKED, to
create a autodialing phone bank app. When a client requests a phone number from the server, the server will assign a
phone number to that client in a way that ensures no phone numbers are skipped or doubly assigned.

The bulk of the logic is implemented using PostgreSQL functions in `dialer_poc_functions.sql`, but it could be
implemented in any language.

## Set up database:

Prerequisites: PostgreSQL >= 9.5
```
export DIALER_POC_DB=dialer_poc
createdb $DIALER_POC_DB
# may need to add more connection parameters to the next two commands:
psql -d $DIALER_POC_DB  < dialer_poc.sql
psql -d $DIALER_POC_DB  < dialer_poc_functions.sql
```

## Run Flask app:

```
python3 -m venv venv
. venv/bin/activate
pip install -r app_server/requirements.txt

export DB_USER=...  # by default, same as your username
export DB_PASSWORD=...  # by default, ""
export FLASK_APP=app_server/app.py
flask run
```

`curl` command examples are given in `app_server/app.py`.
