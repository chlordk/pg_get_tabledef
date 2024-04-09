# pg_get_tabledef

PostgreSQL function for reconstructing the underlying CREATE command for a table
and related objects.

Version: beta

Sample run & output:

    $ psql --tuples-only --no-align --command="SELECT pg_get_tabledef('t2')"

    CREATE TABLE public.t2 (
        i2 integer NOT NULL DEFAULT nextval('t2_i2_seq'::regclass),
        c1 text NOT NULL,
        CONSTRAINT t2_c1_check CHECK (c1 ~* '[a-m]+'::text)
    );
    COMMENT ON TABLE public.t2 IS 'T2 comment';
    COMMENT ON COLUMN public.t2.i2 IS 'T2.i2 comment';
    COMMENT ON COLUMN public.t2.c1 IS 'T2.c1 comment';
    CREATE SEQUENCE public.t2_i2_seq
        AS integer
        CACHE 1;
    CREATE UNIQUE INDEX t2_i2_c1 ON t2 USING btree (i2, c1);

## Installation & test

Install the function `pg_get_tabledef`:

    psql -d tabledef -f pg_get_tabledef.sql

Install test data in database `tabledef` as PostgreSQL superuser:

    psql -f create-test-tabledef.sql

Dump sample table with indexes and comments:

    psql -tA -d tabledef -c "SELECT pg_get_tabledef('tC')"

## Implementation

Status of implementation:

- CREATE TABLE
  - NOT NULL
  - DEFAULT
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

## Bug report

If the table output of `pg_dump` is different from `pg_get_tabledef` it is probably 
considered a bug. Run the following command and send the output together with the
output from `pg_get_tabledef`.

    pg_dump --schema-only -d <db> -t <table> | egrep -v '^-|^$|^SET |^SELECT'
