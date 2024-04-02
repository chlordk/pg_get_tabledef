-- psql -c 'DROP DATABASE tabledef' ; psql --file=create-tabledef.sql ; pg_dump -d tabledef > db-tabledef.sql
-- egrep -v '^-|^$' db-tabledef.sql
CREATE DATABASE tabledef;
COMMENT ON DATABASE tabledef IS 'TableDef comment';
\c tabledef
DROP TABLE IF EXISTS t1;
CREATE TABLE t1 (i int PRIMARY KEY);
DROP TABLE IF EXISTS t2;
CREATE TABLE t2 (i2 serial, c1 TEXT);
CREATE UNIQUE INDEX t2_i2_c1 ON t2 (i2,c1);
CREATE TABLE "tC" ("iC" bigserial, "cC" TEXT);
CREATE UNIQUE INDEX "tC_cC" ON "tC" ("cC");
CREATE UNIQUE INDEX "tC_iC_cC" ON "tC" ("iC","cC");
COMMENT ON TABLE t1 IS 'T1 comment';
COMMENT ON COLUMN t1.i IS 'T1.i comment';
COMMENT ON TABLE t2 IS 'T2 comment';
COMMENT ON COLUMN t2.i2 IS 'T2.i2 comment';
COMMENT ON COLUMN t2.c1 IS 'T2.c1 comment';
COMMENT ON TABLE "tC" IS 'Table Camel Case comment';
COMMENT ON COLUMN "tC"."iC" IS 'tC.iC comment';
COMMENT ON COLUMN "tC"."cC" IS 'tC.cC comment';
INSERT INTO t1 VALUES(7);
INSERT INTO t2 VALUES(1,'one');
INSERT INTO t2 VALUES(7,'seven');
