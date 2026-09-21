import sqlite3
import os

db_path = r'e:\Project\photo_post\lumira-server\packages\backend\data\lumira.db'
print(f"DB exists: {os.path.exists(db_path)}")
print(f"DB size: {os.path.getsize(db_path)} bytes")

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# List all tables
cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
tables = cur.fetchall()
print(f"\nTables: {[t[0] for t in tables]}")

# Check template_categories
if ('template_categories',) in tables:
    cur.execute("SELECT COUNT(*) FROM template_categories")
    print(f"\ntemplate_categories count: {cur.fetchone()[0]}")

    cur.execute("SELECT key, name, parent_key, level, sort_order FROM template_categories ORDER BY level, sort_order LIMIT 30")
    rows = cur.fetchall()
    print("\nCategories (key, name, parent_key, level, sort_order):")
    for r in rows:
        print(f"  {r}")
else:
    print("\ntemplate_categories table does NOT exist")

conn.close()
