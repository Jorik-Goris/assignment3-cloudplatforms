#!/bin/sh

flask db init
flask db migrate -m "entries table"
flask db upgrade
exec gunicorn --bind 0.0.0.0:5000 crudapp:app