---
name: sqlite
description: Query, inspect, and modify SQLite databases using the sqlite3 CLI.
---

## Inspection

- `sqlite3 db.sqlite '.tables'` — list all tables
- `sqlite3 db.sqlite '.schema users'` — show CREATE statement for a table
- `sqlite3 db.sqlite '.indexes'` — list all indexes
- `sqlite3 db.sqlite 'PRAGMA table_info(users);'` — column names and types

## Querying

- `sqlite3 -column -header db.sqlite 'SELECT * FROM users LIMIT 10;'`
- `sqlite3 db.sqlite 'SELECT COUNT(*) FROM orders WHERE status="open";'`

## Exporting

- `sqlite3 -csv -header db.sqlite 'SELECT * FROM users;' > users.csv`
- `sqlite3 db.sqlite '.dump' > backup.sql`

## Modifying

- `sqlite3 db.sqlite 'UPDATE users SET active=1 WHERE id=42;'`
- `sqlite3 db.sqlite < migration.sql`

## Tips

- Use `.mode column` + `.headers on` for readable output in scripts
- `PRAGMA foreign_keys = ON;` must be set per-connection — it is off by default
