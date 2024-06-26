-- License: MIT
-- Author: Hans Schou <hans@schou.dk> © 2024
-- Example of use:
--   psql --tuples-only --no-align --command="SELECT pg_get_tabledef('foo')"

CREATE OR REPLACE FUNCTION pg_get_tabledef(TEXT)
RETURNS TABLE(R TEXT)
LANGUAGE plpgsql
AS $_$
-- pg_get_tabledef ( text ) → text
-- Reconstructs the underlying CREATE command for a table and objects related to a table.
-- Parameter: Table name
-- (This is a decompiled reconstruction, not the original text of the command.)
DECLARE
	rec record;
	tmp_text text;
	count_columns integer := 0; -- Number of columns in the table
	count_constraint integer := 0;
	v_oid oid; -- Table object id
	v_schema text; -- Schema
	v_table text; -- Table name
	rxrelname text :=  '^(' || $1 || ')$';
BEGIN
	-- Get oid and schema
	SELECT
		c.oid, n.nspname, c.relname
	INTO
		v_oid, v_schema, v_table
	FROM pg_catalog.pg_class c
	LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE c.relname OPERATOR(pg_catalog.~) rxrelname COLLATE pg_catalog.default
		AND pg_catalog.pg_table_is_visible(c.oid);
	-- If table not found exit
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Did not find any relation named "%".', $1;
		RETURN;
	END IF;
	R := 'CREATE TABLE ' || v_schema || '.';
	IF v_table ~ '[A-Z]' THEN -- check camelCase
		R := R ||'"' || v_table || '"';
	ELSE
		R := R || v_table;
	END IF;
	R := R || ' (';
	RETURN NEXT;
	-- Get columns
	SELECT COUNT(a.attnum) INTO count_columns FROM pg_catalog.pg_attribute a WHERE a.attrelid = v_oid AND a.attnum > 0 AND NOT a.attisdropped;
	SELECT COUNT(r.conname) INTO count_constraint FROM pg_catalog.pg_constraint r WHERE r.conrelid = v_oid AND r.contype = 'c';
	FOR rec IN
		SELECT
			a.attname,
			pg_catalog.format_type(a.atttypid, a.atttypmod) AS format_type,
			(SELECT pg_catalog.pg_get_expr(d.adbin, d.adrelid, true)
			 FROM pg_catalog.pg_attrdef d
			 WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef),
			a.attnotnull,
			(SELECT c.collname FROM pg_catalog.pg_collation c, pg_catalog.pg_type t
			 WHERE c.oid = a.attcollation AND t.oid = a.atttypid AND a.attcollation <> t.typcollation) AS attcollation,
			a.attidentity,
			a.attgenerated,
			a.attnum
		FROM pg_catalog.pg_attribute a
		WHERE a.attrelid = v_oid AND a.attnum > 0 AND NOT a.attisdropped
		ORDER BY a.attnum
	LOOP
		R := E'\t';
		IF rec.attname ~ '[A-Z]' THEN
			R := R || '"' || rec.attname || '" ';
		ELSE
			R := R || rec.attname || ' ';
		END IF;
		R := R || rec.format_type;
		IF rec.attnotnull THEN
			R := R || ' NOT NULL';
		END IF;
		IF LENGTH(rec.pg_get_expr) > 0 THEN
			R := R || ' DEFAULT ' || rec.pg_get_expr;
		END IF;
		IF rec.attnum < count_columns OR count_constraint > 0 THEN
			R := R || ','; -- no comma after last column definition or constraints
		END IF;
		RETURN NEXT;
	END LOOP; -- Columns
	-- Constraints
	IF count_constraint > 0 THEN
		FOR rec IN
			SELECT r.conname, pg_catalog.pg_get_constraintdef(r.oid, true)
			FROM pg_catalog.pg_constraint r
			WHERE r.conrelid = v_oid AND r.contype = 'c'
			ORDER BY 1
		LOOP
			-- RAISE NOTICE 'CONSTRAINT % %', rec.conname, rec.pg_get_constraintdef;
			R := E'\t' || 'CONSTRAINT ' || rec.conname || ' ' || rec.pg_get_constraintdef;
			RETURN NEXT;
		END LOOP;
	END IF; -- Constraints
	-- Finalize table
	R := ');';
	RETURN NEXT;
	-- ALTER TABLE public.t1 OWNER TO hasch;
	-- Add COMMENTs
	SELECT obj_description(v_oid) INTO tmp_text;
	IF LENGTH(tmp_text) > 0 THEN
		R := 'COMMENT ON TABLE ' || v_schema || '.';
		IF v_table ~ '[A-Z]' THEN
			R := R || '"' || v_table || '"';
		ELSE
			R := R || v_table;
		END IF;
		R := R || ' IS ''' || tmp_text || ''';';
		RETURN NEXT;
	END IF;
	FOR rec IN
		SELECT
			a.attnum,
			a.attname
		FROM pg_catalog.pg_attribute a
		WHERE a.attrelid = v_oid AND a.attnum > 0 AND NOT a.attisdropped
		ORDER BY a.attnum
	LOOP
		SELECT col_description( v_oid, rec.attnum) INTO tmp_text;
		IF LENGTH(tmp_text) > 0 THEN
			R := 'COMMENT ON COLUMN ' || v_schema || '.';
			IF v_table ~ '[A-Z]' THEN
				R := R || '"' || v_table || '"';
			ELSE
				R := R || v_table;
			END IF;
			R := R || '.';
			IF rec.attname ~ '[A-Z]' THEN
				R := R || '"' || rec.attname || '"';
			ELSE
				R := R || rec.attname;
			END IF;
			R := R || ' IS ''' || tmp_text || ''';';
			RETURN NEXT;
		END IF;
	END LOOP; -- Comments
	-- Sequence
	FOR rec IN
		SELECT
			a.attname,
			pg_catalog.format_type(a.atttypid, a.atttypmod) AS format_type,
			(SELECT pg_catalog.pg_get_expr(d.adbin, d.adrelid, true)
			 FROM pg_catalog.pg_attrdef d
			 WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef),
			a.attnotnull,
			(SELECT c.collname FROM pg_catalog.pg_collation c, pg_catalog.pg_type t
			 WHERE c.oid = a.attcollation AND t.oid = a.atttypid AND a.attcollation <> t.typcollation) AS attcollation,
			a.attidentity,
			a.attgenerated,
			a.attnum
		FROM pg_catalog.pg_attribute a
		WHERE a.attrelid = v_oid AND a.attnum > 0 AND NOT a.attisdropped
		ORDER BY a.attnum
	LOOP
		tmp_text :=  pg_get_serial_sequence(v_table, rec.attname);
		IF LENGTH(tmp_text) > 0 THEN
			R := 'CREATE SEQUENCE ' || tmp_text;
			RETURN NEXT;
			R := E'\t' || 'AS ' || rec.format_type; 
			RETURN NEXT;
			R := E'\t' || 'CACHE 1;';
			RETURN NEXT;
		END IF;
	END LOOP; -- Sequence
	-- Index
	FOR rec IN 
		SELECT
			pg_catalog.pg_get_indexdef(i.indexrelid, 0, true) AS indexdef
		FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
		LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
		WHERE c.oid = v_oid AND c.oid = i.indrelid AND i.indexrelid = c2.oid
		ORDER BY i.indisprimary DESC, c2.relname
	LOOP
		R := rec.indexdef || ';';
		RETURN NEXT;
	END LOOP; -- Index
END; $_$;

-- vim: tabstop=4 noexpandtab :
