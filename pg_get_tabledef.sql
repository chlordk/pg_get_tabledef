-- License: MIT
-- Author: Hans Schou <hans@schou.dk> © 2024
-- psql --tuples-only --no-align --command="SELECT pg_get_tabledef('foo')"

CREATE OR REPLACE FUNCTION pg_get_tabledef(TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $_$
-- pg_get_tabledef ( text ) → text
-- Reconstructs the underlying CREATE command for a table and objects related to a table.
-- Parameter: Table name
-- (This is a decompiled reconstruction, not the original text of the command.)
DECLARE
	R TEXT := ''; -- Return result
	R_c TEXT := ''; -- Comments result, show after table definition
	rec RECORD;
	tmp_text TEXT;
	v_oid OID; -- Table object id
	v_schema TEXT; -- Schema
	v_table TEXT; -- Table name
	rxrelname TEXT :=  '^(' || $1 || ')$';
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
		-- RAISE EXCEPTION 'Table % not found', $1;
		RETURN '-- Table not found: ''' || $1 || '''';
	END IF;
	-- Table comment first, columns comment second, init variable R_c, 
	SELECT obj_description(v_oid) INTO tmp_text;
	IF LENGTH(tmp_text) > 0 THEN
		R_c := 'COMMENT ON TABLE ' || v_schema || '."' || v_table || '" IS ''' || tmp_text || ''';' || E'\n';
	END IF;
	R := 'CREATE TABLE ' || v_schema || '."' || v_table || '" (';
	-- Get columns
	FOR rec IN
		SELECT
			a.attname,
			pg_catalog.format_type(a.atttypid, a.atttypmod),
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
		--RAISE NOTICE '% % %', rec.attnum, rec.attname, rec.format_type;
		IF rec.attnum > 1 THEN
			R := R || ','; -- no comma after last column definition
		END IF;
		R := R || E'\n' || '	"' || rec.attname || '" ' || rec.format_type;
		IF rec.attnotnull THEN
			R := R || ' NOT NULL';
		END IF;
		-- Comment on column
		SELECT col_description( v_oid, rec.attnum) INTO tmp_text;
		IF LENGTH(tmp_text) > 0 THEN
			R_c := R_c || 'COMMENT ON COLUMN ' || v_schema || '."' || v_table || '"."' || rec.attname || '" IS ''' || tmp_text || ''';' || E'\n';
		END IF;
	END LOOP; -- Columns
	-- Finalize table
	R := R || E'\n' || ');' || E'\n';
	-- Add COMMENTs
	IF LENGTH(R_c) > 0 THEN
		R := R || R_c;
	END IF;
	-- Index
	FOR rec IN 
		SELECT
			pg_catalog.pg_get_indexdef(i.indexrelid, 0, true) AS indexdef
		FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
		LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
		WHERE c.oid = v_oid AND c.oid = i.indrelid AND i.indexrelid = c2.oid
		ORDER BY i.indisprimary DESC, c2.relname
	LOOP
		R := R || rec.indexdef || ';' || E'\n';
	END LOOP; -- Index
	RETURN R;
END;
$_$;

-- vim: tabstop=4 noexpandtab :
