# pg_get_tabledef

PostgreSQL function for reconstructing the underlying CREATE command for a table
and related objects.

Version: beta

Sample run & output:

    $ psql --tuples-only --no-align --command="SELECT pg_get_tabledef('tC')"

    CREATE TABLE public."tC" (
        "iC" integer NOT NULL,
        "cC" text
    );
    COMMENT ON TABLE public."tC" IS 'Table Camel Case comment';
    COMMENT ON COLUMN public."tC.iC" IS 'tC.iC comment';
    COMMENT ON COLUMN public."tC.cC" IS 'tC.cC comment';
    CREATE UNIQUE INDEX "tC_cC" ON "tC" USING btree ("cC");
    CREATE UNIQUE INDEX "tC_iC_cC" ON "tC" USING btree ("iC", "cC");

## Installation & test

Install the function `pg_get_tabledef`:

    psql -d tabledef -f pg_get_tabledef.sql

Install test data in database `tabledef` as PostgreSQL superuser:

    psql -f create-tabledef.sql

Dump sample table with indexes and comments:

    psql -tA -d tabledef -c "SELECT pg_get_tabledef('tC')"

## Implementation

Status of implementation:

- CREATE TABLE
  - NOT NULL
- CREATE INDEX
- COMMENT ON
  - TABLE
  - COLUMN

## TODO

The goal is to re-create all objects which will be deleted on a `DROP TABLE` command.
Sample output is created by creating a table with all possible objects and
then run `pg_dump` before and after `DROP TABLE` and then reconstruct the difference.

## Hint

To get a hint on how to get the SQL statements needed use the `psql` option `-E`
or `--echo-hidden` which will display queries that internal commands generate.

Example:

    psql -E -c "CREATE TABLE foo(i int)"
    psql -E -c "COMMENT ON TABLE foo IS 'A comment'"
    psql -E -c "DROP TABLE foo"
