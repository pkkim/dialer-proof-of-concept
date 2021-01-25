import datetime
import os

from flask import Flask, request
import psycopg2
app = Flask(__name__)


_db_conn = None


def get_db():
    global _db_conn
    if _db_conn is None:
        _db_conn = psycopg2.connect(
            user=os.environ.get('DB_USER', 'pkim'),
            password=os.environ.get('DB_PASSWORD', ''),
            host='127.0.0.1',
            port='5432',
            database='dialer_poc',
        )
    return _db_conn


@app.route('/')
def get_phonebanks():
    cursor = get_db().cursor()
    cursor.execute("SELECT id, name FROM phone_bank")
    records = cursor.fetchall()

    result = "List of currently ongoing phonebanks:<br />"

    for _id, name in records:
        result += f"{name} (ID {_id})<br />"

    return result


# curl -XPOST -H "content-type: application/json" --data '{"name": "abc", "phone_numbers": ["914-620-5001", "914-512-1500"]}' 127.0.0.1:5000/create
@app.route('/create', methods=['POST'])
def create():
    payload = request.json
    name = payload['name']
    phone_numbers = payload['phone_numbers']
    cursor = get_db().cursor()
    cursor.execute('SELECT phone_bank_init(%s, %s)', (name, phone_numbers))
    result = cursor.fetchone()
    get_db().commit()
    return f"Your new phone bank ID is {result[0]}."


# curl -XPOST -H "content-type: application/json" --data '{"assigned_to": "paul"}' 127.0.0.1:5000/create
@app.route('/request-number/<phonebank_id>', methods=['POST'])
def request_number(phonebank_id):
    print(phonebank_id)
    assigned_to = request.args.get('assigned_to', None) or 'me'
    assigned_until = (datetime.datetime.utcnow() + datetime.timedelta(minutes=10)).isoformat()
    cursor = get_db().cursor()
    cursor.execute(
        'SELECT phone_number_assign(%s, %s, %s)',
        (phonebank_id, assigned_to, assigned_until),
    )
    result = cursor.fetchone()[0]
    get_db().commit()
    if result:
        return f"You have been assigned number {result[0]} until {assigned_until}. " \
               f"After {assigned_until}, someone else may be assigned this number."
    else:
        return "The system was unable to assign you a number to call."


# curl -XPOST -H "content-type: application/json" --data '{"result": "C"}' 127.0.0.1:5000/complete-number/8/914-620-5001
@app.route('/complete-number/<phonebank_id>/<phone_number>', methods=['POST'])
def complete_number(phonebank_id, phone_number):
    cursor = get_db().cursor()
    cursor.execute(
        'SELECT phone_number_complete(%s, %s, %s)',
        (phonebank_id, phone_number, request.json['result']),
    )
    result = cursor.fetchone()
    success = result[0]
    if success:
        get_db().commit()
        return f"Completed number with result {success}, now no one else will be " \
               f"assigned this number."
    else:
        return "Error"


# curl -XPOST 127.0.0.1:5000/abandon-number/8/914-620-5001
@app.route('/abandon-number/<phonebank_id>/<phone_number>', methods=['POST'])
def abandon_number(phonebank_id, phone_number):
    cursor = get_db().cursor()
    cursor.execute(
        'SELECT phone_number_abandon(%s, %s, %s)',
        (phonebank_id, phone_number),
    )
    result = cursor.fetchone()
    success = result[0]
    if success:
        get_db().commit()
        return f"Abandoned number, now someone else may be assigned this number."
    else:
        return "Error"
