CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;

CREATE ROLE quesnelia_mod_inventory_storage PASSWORD 'quesnelia' NOSUPERUSER NOCREATEDB INHERIT LOGIN;
ALTER ROLE quesnelia_mod_inventory_storage SET search_path TO 'quesnelia_mod_inventory_storage';

-- for populateHoldingsSourceId.sql we need quesnelia_mod_source_record_storage.records_lb
CREATE SCHEMA quesnelia_mod_source_record_storage;
CREATE TABLE quesnelia_mod_source_record_storage.records_lb (external_id UUID);
CREATE INDEX idx_records_external_id ON quesnelia_mod_source_record_storage.records_lb USING btree (external_id);
INSERT INTO quesnelia_mod_source_record_storage.records_lb VALUES
  ('0c45bb50-7c9b-48b0-86eb-178a494e25fe'),
  ('e6d7e91a-4dbc-4a70-9b38-e000d2fbdc79'),
  ('e9285a1c-1dfc-4380-868c-e74073003f43');

SET search_path TO quesnelia_mod_inventory_storage;

-- the following has been dumped using
-- PGPASSWORD="$DB_PASSWORD" pg_dump -U "$DB_USERNAME" -h "$DB_HOST" -p "$DB_PORT" -n quesnelia_mod_inventory_storage > dump.sql


--
-- PostgreSQL database dump
--

-- Dumped from database version 16.8
-- Dumped by pg_dump version 16.8 (Ubuntu 16.8-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: quesnelia_mod_inventory_storage; Type: SCHEMA; Schema: -; Owner: quesnelia_mod_inventory_storage
--

CREATE SCHEMA quesnelia_mod_inventory_storage;


ALTER SCHEMA quesnelia_mod_inventory_storage OWNER TO quesnelia_mod_inventory_storage;

--
-- Name: alternative_title_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.alternative_title_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.alternative_title_type_set_md() OWNER TO postgres;

--
-- Name: audit_holdings_record_changes(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.audit_holdings_record_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    jsonb JSONB;
    uuidtext TEXT;
    uuid UUID;
  BEGIN
    jsonb = CASE WHEN TG_OP = 'DELETE' THEN OLD.jsonb ELSE NEW.jsonb END;

    -- create uuid based on the jsonb value so that concurrent updates of different records are possible.
    uuidtext = md5(jsonb::text);
    -- UUID version byte
    uuidtext = overlay(uuidtext placing '4' from 13);
    -- UUID variant byte
    uuidtext = overlay(uuidtext placing '8' from 17);
    uuid = uuidtext::uuid;
    -- If uuid is already in use increment until an unused is found. This can only happen if the jsonb content
    -- is exactly the same. This should be very rare when it includes a timestamp.
    WHILE EXISTS (SELECT 1 FROM quesnelia_mod_inventory_storage.audit_holdings_record WHERE id = uuid) LOOP
      uuid = quesnelia_mod_inventory_storage.next_uuid(uuid);
    END LOOP;

    jsonb = jsonb_build_object(
      'id', to_jsonb(uuid::text),
      'record', jsonb,
      'operation', to_jsonb(left(TG_OP, 1)),
      'createdDate', to_jsonb(current_timestamp::text));
    IF (TG_OP = 'DELETE') THEN
    ELSIF (TG_OP = 'UPDATE') THEN
    ELSIF (TG_OP = 'INSERT') THEN
    END IF;
    INSERT INTO quesnelia_mod_inventory_storage.audit_holdings_record VALUES (uuid, jsonb);
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.audit_holdings_record_changes() OWNER TO postgres;

--
-- Name: audit_instance_changes(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.audit_instance_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    jsonb JSONB;
    uuidtext TEXT;
    uuid UUID;
  BEGIN
    jsonb = CASE WHEN TG_OP = 'DELETE' THEN OLD.jsonb ELSE NEW.jsonb END;

    -- create uuid based on the jsonb value so that concurrent updates of different records are possible.
    uuidtext = md5(jsonb::text);
    -- UUID version byte
    uuidtext = overlay(uuidtext placing '4' from 13);
    -- UUID variant byte
    uuidtext = overlay(uuidtext placing '8' from 17);
    uuid = uuidtext::uuid;
    -- If uuid is already in use increment until an unused is found. This can only happen if the jsonb content
    -- is exactly the same. This should be very rare when it includes a timestamp.
    WHILE EXISTS (SELECT 1 FROM quesnelia_mod_inventory_storage.audit_instance WHERE id = uuid) LOOP
      uuid = quesnelia_mod_inventory_storage.next_uuid(uuid);
    END LOOP;

    jsonb = jsonb_build_object(
      'id', to_jsonb(uuid::text),
      'record', jsonb,
      'operation', to_jsonb(left(TG_OP, 1)),
      'createdDate', to_jsonb(current_timestamp::text));
    IF (TG_OP = 'DELETE') THEN
    ELSIF (TG_OP = 'UPDATE') THEN
    ELSIF (TG_OP = 'INSERT') THEN
    END IF;
    INSERT INTO quesnelia_mod_inventory_storage.audit_instance VALUES (uuid, jsonb);
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.audit_instance_changes() OWNER TO postgres;

--
-- Name: audit_item_changes(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.audit_item_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    jsonb JSONB;
    uuidtext TEXT;
    uuid UUID;
  BEGIN
    jsonb = CASE WHEN TG_OP = 'DELETE' THEN OLD.jsonb ELSE NEW.jsonb END;

    -- create uuid based on the jsonb value so that concurrent updates of different records are possible.
    uuidtext = md5(jsonb::text);
    -- UUID version byte
    uuidtext = overlay(uuidtext placing '4' from 13);
    -- UUID variant byte
    uuidtext = overlay(uuidtext placing '8' from 17);
    uuid = uuidtext::uuid;
    -- If uuid is already in use increment until an unused is found. This can only happen if the jsonb content
    -- is exactly the same. This should be very rare when it includes a timestamp.
    WHILE EXISTS (SELECT 1 FROM quesnelia_mod_inventory_storage.audit_item WHERE id = uuid) LOOP
      uuid = quesnelia_mod_inventory_storage.next_uuid(uuid);
    END LOOP;

    jsonb = jsonb_build_object(
      'id', to_jsonb(uuid::text),
      'record', jsonb,
      'operation', to_jsonb(left(TG_OP, 1)),
      'createdDate', to_jsonb(current_timestamp::text));
    IF (TG_OP = 'DELETE') THEN
    ELSIF (TG_OP = 'UPDATE') THEN
    ELSIF (TG_OP = 'INSERT') THEN
    END IF;
    INSERT INTO quesnelia_mod_inventory_storage.audit_item VALUES (uuid, jsonb);
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.audit_item_changes() OWNER TO postgres;

--
-- Name: bound_with_part_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.bound_with_part_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.bound_with_part_set_md() OWNER TO postgres;

--
-- Name: call_number_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.call_number_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.call_number_type_set_md() OWNER TO postgres;

--
-- Name: check_statistical_code_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.check_statistical_code_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  invalid text;
BEGIN
  SELECT ref
    INTO invalid
    FROM jsonb_array_elements_text(NEW.jsonb->'statisticalCodeIds') ref
    LEFT JOIN statistical_code ON id=ref::uuid
    WHERE id IS NULL
    LIMIT 1;
  IF FOUND THEN
    RAISE foreign_key_violation USING
      MESSAGE='statistical code doesn''t exist: ' || invalid,
      DETAIL='foreign key violation in statisticalCodeIds array of ' || TG_TABLE_NAME || ' with id=' || NEW.id,
      SCHEMA=TG_TABLE_SCHEMA,
      TABLE=TG_TABLE_NAME;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.check_statistical_code_references() OWNER TO postgres;

--
-- Name: classification_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.classification_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.classification_type_set_md() OWNER TO postgres;

--
-- Name: completeupdateddate_for_holdings_delete(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_holdings_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
      UPDATE quesnelia_mod_inventory_storage.instance inst SET complete_updated_date = NOW()
      WHERE inst.id = OLD.instanceid;
   RETURN OLD;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_holdings_delete() OWNER TO postgres;

--
-- Name: completeupdateddate_for_holdings_insert_update(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_holdings_insert_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
      UPDATE quesnelia_mod_inventory_storage.instance inst SET complete_updated_date = NOW()
      WHERE inst.id = NEW.instanceid;
   RETURN NEW;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_holdings_insert_update() OWNER TO postgres;

--
-- Name: completeupdateddate_for_instance(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_instance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
     NEW.complete_updated_date = NOW();
  RETURN NEW;
 END;
 $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_instance() OWNER TO postgres;

--
-- Name: completeupdateddate_for_item_delete(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_item_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
     UPDATE quesnelia_mod_inventory_storage.instance inst SET complete_updated_date = NOW()
     WHERE inst.id IN (
          SELECT instanceid
          FROM quesnelia_mod_inventory_storage.holdings_record hold_rec
          WHERE hold_rec.id = OLD.holdingsrecordid);
  RETURN OLD;
 END;
 $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_item_delete() OWNER TO postgres;

--
-- Name: completeupdateddate_for_item_insert_update(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_item_insert_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
     UPDATE quesnelia_mod_inventory_storage.instance inst SET complete_updated_date = NOW()
     WHERE inst.id IN (
         SELECT instanceid
         FROM quesnelia_mod_inventory_storage.holdings_record hold_rec
         WHERE hold_rec.id = NEW.holdingsrecordid);

     UPDATE quesnelia_mod_inventory_storage.instance inst SET complete_updated_date = NOW()
     WHERE inst.id IN (
         SELECT instanceid
         FROM quesnelia_mod_inventory_storage.holdings_record hold_rec
         WHERE hold_rec.id IN (
             SELECT holdingsrecordid
             FROM quesnelia_mod_inventory_storage.bound_with_part bwp
             WHERE bwp.itemid = NEW.id));
     RETURN NEW;
 END;
 $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_item_insert_update() OWNER TO postgres;

--
-- Name: concat_array_object(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.concat_array_object(jsonb_array jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT string_agg(value::text, ' ') FROM jsonb_array_elements_text($1);
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.concat_array_object(jsonb_array jsonb) OWNER TO postgres;

--
-- Name: concat_array_object_values(jsonb, text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.concat_array_object_values(jsonb_array jsonb, field text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT string_agg(value->>$2, ' ') FROM jsonb_array_elements($1);
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.concat_array_object_values(jsonb_array jsonb, field text) OWNER TO postgres;

--
-- Name: concat_array_object_values(jsonb, text, text, text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.concat_array_object_values(jsonb_array jsonb, field text, filterkey text, filtervalue text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
SELECT string_agg(value->>$2, ' ') FROM jsonb_array_elements($1) WHERE value->>$3 = $4;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.concat_array_object_values(jsonb_array jsonb, field text, filterkey text, filtervalue text) OWNER TO postgres;

--
-- Name: concat_space_sql(text[]); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.concat_space_sql(VARIADIC text[]) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$ select concat_ws(' ', VARIADIC $1);
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.concat_space_sql(VARIADIC text[]) OWNER TO postgres;

--
-- Name: contributor_name_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.contributor_name_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.contributor_name_type_set_md() OWNER TO postgres;

--
-- Name: count_estimate(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.count_estimate(query text) RETURNS bigint
    LANGUAGE plpgsql STABLE STRICT
    AS $$
DECLARE
  count bigint;
  est_count bigint;
  q text;
BEGIN
  est_count = quesnelia_mod_inventory_storage.count_estimate_smart2(1000, 1000, query);
  IF est_count > 4*1000 THEN
    RETURN est_count;
  END IF;
  q = 'SELECT COUNT(*) FROM (' || query || ' LIMIT 1000) x';
  EXECUTE q INTO count;
  IF count < 1000 THEN
    RETURN count;
  END IF;
  IF est_count < 1000 THEN
    RETURN 1000;
  END IF;
  RETURN est_count;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.count_estimate(query text) OWNER TO postgres;

--
-- Name: count_estimate_default(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.count_estimate_default(query text) RETURNS bigint
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
  rows bigint;
  q text;
BEGIN
  q = 'SELECT COUNT(*) FROM (' || query || ' LIMIT 1000) x';
  EXECUTE q INTO rows;
  IF rows < 1000 THEN
    return rows;
  END IF;
  rows = quesnelia_mod_inventory_storage.count_estimate_smart2(1000, 1000, query);
  IF rows < 1000 THEN
    return 1000;
  END IF;
  RETURN rows;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.count_estimate_default(query text) OWNER TO postgres;

--
-- Name: count_estimate_smart2(bigint, bigint, text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.count_estimate_smart2(rows bigint, lim bigint, query text) RETURNS bigint
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
  rec   record;
  cnt bigint;
BEGIN
  IF rows = lim THEN
      FOR rec IN EXECUTE 'EXPLAIN ' || query LOOP
        cnt := substring(rec."QUERY PLAN" FROM ' rows=([[:digit:]]+)');
        EXIT WHEN cnt IS NOT NULL;
      END LOOP;
      RETURN cnt;
  END IF;
  RETURN rows;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.count_estimate_smart2(rows bigint, lim bigint, query text) OWNER TO postgres;

--
-- Name: dateormax(timestamp with time zone); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.dateormax(timestamp with time zone) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT COALESCE($1, timestamptz '2050-01-01')
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.dateormax(timestamp with time zone) OWNER TO postgres;

--
-- Name: dateormin(timestamp with time zone); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.dateormin(timestamp with time zone) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT COALESCE($1, timestamptz '1970-01-01')
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.dateormin(timestamp with time zone) OWNER TO postgres;

--
-- Name: electronic_access_relationship_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.electronic_access_relationship_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.electronic_access_relationship_set_md() OWNER TO postgres;

--
-- Name: f_unaccent(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.f_unaccent(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
        SELECT public.unaccent('public.unaccent', $1)  -- schema-qualify function and dictionary
      $_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.f_unaccent(text) OWNER TO postgres;

--
-- Name: first_array_object_value(jsonb, text, text, text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.first_array_object_value(jsonb_array jsonb, field text, filterkey text, filtervalue text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
SELECT value->>$2 FROM jsonb_array_elements($1) WHERE value->>$3 = $4 LIMIT 1;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.first_array_object_value(jsonb_array jsonb, field text, filterkey text, filtervalue text) OWNER TO postgres;

--
-- Name: get_items_and_holdings_view(uuid[], boolean); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.get_items_and_holdings_view(instanceids uuid[], skipsuppressedfromdiscoveryrecords boolean DEFAULT true) RETURNS TABLE("instanceId" uuid, source character varying, "modeOfIssuance" character varying, "natureOfContent" jsonb, holdings jsonb, items jsonb)
    LANGUAGE sql
    AS $_$
WITH
    -- Locations
    viewLocations(locId, locJsonb, locCampJsonb, locLibJsonb, locInstJsonb) AS (
        SELECT loc.id AS locId,
               loc.jsonb AS locJsonb,
               locCamp.jsonb AS locCampJsonb,
               locLib.jsonb AS locLibJsonb,
               locInst.jsonb AS locInstJsonb
        FROM location loc
                 LEFT JOIN locinstitution locInst
                           ON (loc.jsonb ->> 'institutionId')::uuid = locInst.id
                 LEFT JOIN loccampus locCamp
                           ON (loc.jsonb ->> 'campusId')::uuid = locCamp.id
                 LEFT JOIN loclibrary locLib
                           ON (loc.jsonb ->> 'libraryId')::uuid = locLib.id
        WHERE (loc.jsonb ->> 'isActive')::bool = true
    ),
    -- Passed instances ids
    viewInstances(instId, source, modeOfIssuance, natureOfContent) AS (
        SELECT DISTINCT
            instId AS "instanceId",
            i.jsonb ->> 'source' AS source,
            moi.jsonb ->> 'name' AS modeOfIssuance,
            COALESCE(getNatureOfContentName(COALESCE(i.jsonb #> '{natureOfContentTermIds}', '[]'::jsonb)), '[]'::jsonb) AS natureOfContent
        FROM UNNEST( $1 ) instId
                 JOIN instance i
                      ON i.id = instId
                 LEFT JOIN mode_of_issuance moi
                           ON moi.id = nullif(i.jsonb ->> 'modeOfIssuanceId','')::uuid
    ),
    -- Prepared items and holdings
    viewItemsAndHoldings(instId, records) AS (
        SELECT itemAndHoldingsAttrs.instanceId, jsonb_strip_nulls(itemAndHoldingsAttrs.itemsAndHoldings)
        FROM (SELECT
                  i.id AS instanceId,
                  jsonb_build_object('holdings',
                                     COALESCE(jsonb_agg(DISTINCT
                                              jsonb_build_object('id', hr.id,
                                                                 'hrId', hr.jsonb ->> 'hrId',
                                                                 'suppressFromDiscovery',
                                                                 CASE WHEN hr.id IS NOT NULL THEN
                                                                              COALESCE((i.jsonb ->> 'discoverySuppress')::bool, false) OR
                                                                              COALESCE((hr.jsonb ->> 'discoverySuppress')::bool, false)
                                                                      ELSE NULL END::bool,
                                                                 'holdingsType', ht.jsonb ->> 'name',
                                                                 'formerIds', hr.jsonb -> 'formerIds',
                                                                 'location',
                                                                 CASE WHEN hr.id IS NOT NULL THEN
                                                                          json_build_object('permanentLocation',
                                                                                            jsonb_build_object('name', COALESCE(holdPermLoc.locJsonb ->> 'discoveryDisplayName', holdPermLoc.locJsonb ->> 'name'),
                                                                                                               'code', holdPermLoc.locJsonb ->> 'code',
                                                                                                               'id', holdPermLoc.locJsonb ->> 'id',
                                                                                                               'campusName', holdPermLoc.locCampJsonb ->> 'name',
                                                                                                               'libraryName', holdPermLoc.locLibJsonb ->> 'name',
                                                                                                               'libraryCode', holdPermLoc.locLibJsonb ->> 'code',
                                                                                                               'institutionName', holdPermLoc.locInstJsonb ->> 'name'),
                                                                                            'temporaryLocation',
                                                                                            jsonb_build_object('name', COALESCE(holdTempLoc.locJsonb ->> 'discoveryDisplayName', holdTempLoc.locJsonb ->> 'name'),
                                                                                                               'code', holdTempLoc.locJsonb ->> 'code',
                                                                                                               'id', holdTempLoc.locJsonb ->> 'id',
                                                                                                               'campusName', holdTempLoc.locCampJsonb ->> 'name',
                                                                                                               'libraryName', holdTempLoc.locLibJsonb ->> 'name',
                                                                                                               'libraryCode', holdTempLoc.locLibJsonb ->> 'code',
                                                                                                               'institutionName', holdTempLoc.locInstJsonb ->> 'name'),
                                                                                            'effectiveLocation',
                                                                                            jsonb_build_object('name', COALESCE(holdEffLoc.locJsonb ->> 'discoveryDisplayName', holdEffLoc.locJsonb ->> 'name'),
                                                                                                               'code', holdEffLoc.locJsonb ->> 'code',
                                                                                                               'id', holdEffLoc.locJsonb ->> 'id',
                                                                                                               'campusName', holdEffLoc.locCampJsonb ->> 'name',
                                                                                                               'libraryName', holdEffLoc.locLibJsonb ->> 'name',
                                                                                                               'libraryCode', holdEffLoc.locLibJsonb ->> 'code',
                                                                                                               'institutionName', holdEffLoc.locInstJsonb ->> 'name'))
                                                                      ELSE NULL END::jsonb,
                                                                 'callNumber', json_build_object('prefix', hr.jsonb ->> 'callNumberPrefix',
                                                                                                 'suffix', hr.jsonb ->> 'callNumberSuffix',
                                                                                                 'typeId', hr.jsonb ->> 'callNumberTypeId',
                                                                                                 'typeName', hrcnt.jsonb ->> 'name',
                                                                                                 'callNumber', hr.jsonb ->> 'callNumber'),
                                                                 'shelvingTitle', hr.jsonb ->> 'shelvingTitle',
                                                                 'acquisitionFormat', hr.jsonb ->> 'acquisitionFormat',
                                                                 'acquisitionMethod', hr.jsonb ->> 'acquisitionMethod',
                                                                 'receiptStatus', hr.jsonb ->> 'receiptStatus',
                                                                 'electronicAccess',
                                                                 CASE WHEN hr.id IS NOT NULL THEN
                                                                          COALESCE(getElectronicAccessName(COALESCE(hr.jsonb #> '{electronicAccess}', '[]'::jsonb)), '[]'::jsonb)
                                                                      ELSE NULL::jsonb END,
                                                                 'notes',
                                                                 CASE WHEN hr.id IS NOT NULL THEN
                                                                          COALESCE(getHoldingNoteTypeName(hr.jsonb -> 'notes'), '[]'::jsonb)
                                                                      ELSE NULL END::jsonb,
                                                                 'illPolicy', ilp.jsonb ->> 'name',
                                                                 'retentionPolicy', hr.jsonb ->> 'retentionPolicy',
                                                                 'digitizationPolicy', hr.jsonb ->> 'digitizationPolicy',
                                                                 'holdingsStatements', hr.jsonb -> 'holdingsStatements',
                                                                 'holdingsStatementsForIndexes', hr.jsonb -> 'holdingsStatementsForIndexes',
                                                                 'holdingsStatementsForSupplements', hr.jsonb -> 'holdingsStatementsForSupplements',
                                                                 'copyNumber', hr.jsonb ->> 'copyNumber',
                                                                 'numberOfItems', hr.jsonb ->> 'numberOfItems',
                                                                 'receivingHistory', hr.jsonb -> 'receivingHistory',
                                                                 'tags', hr.jsonb -> 'tags',
                                                                 'statisticalCodes',
                                                                 CASE WHEN hr.id IS NOT NULL THEN
                                                                          COALESCE(getStatisticalCodes(hr.jsonb -> 'statisticalCodeIds'), '[]'::jsonb)
                                                                      ELSE NULL END ::jsonb))
                                              FILTER (WHERE hr.id IS NOT NULL), '[]'::jsonb),
                                     'items',
                                     COALESCE(jsonb_agg(DISTINCT
                                              jsonb_build_object('id', item.id,
                                                                 'hrId', item.jsonb ->> 'hrId',
                                                                 'holdingsRecordId', (item.jsonb ->> 'holdingsRecordId')::UUID,
                                                                 'suppressFromDiscovery',
                                                                 CASE WHEN item.id IS NOT NULL THEN
                                                                              COALESCE((i.jsonb ->> 'discoverySuppress')::bool, false) OR
                                                                              COALESCE((hr.jsonb ->> 'discoverySuppress')::bool, false) OR
                                                                              COALESCE((item.jsonb ->> 'discoverySuppress')::bool, false)
                                                                      ELSE NULL END::bool,
                                                                 'status', item.jsonb #>> '{status, name}',
                                                                 'formerIds', item.jsonb -> 'formerIds',
                                                                 'location',
                                                                 CASE WHEN item.id IS NOT NULL THEN
                                                                          json_build_object('location',
                                                                                            jsonb_build_object('name', COALESCE(itemEffLoc.locJsonb ->> 'discoveryDisplayName', itemEffLoc.locJsonb ->> 'name'),
                                                                                                               'code', itemEffLoc.locJsonb ->> 'code',
                                                                                                               'id', itemEffLoc.locJsonb ->> 'id',
                                                                                                               'campusName', itemEffLoc.locCampJsonb ->> 'name',
                                                                                                               'libraryName', itemEffLoc.locLibJsonb ->> 'name',
                                                                                                               'libraryCode', itemEffLoc.locLibJsonb ->> 'code',
                                                                                                               'institutionName', itemEffLoc.locInstJsonb ->> 'name'),
                                                                                            'permanentLocation',
                                                                                            jsonb_build_object('name', COALESCE(itemPermLoc.locJsonb ->> 'discoveryDisplayName', itemPermLoc.locJsonb ->> 'name'),
                                                                                                               'code', itemPermLoc.locJsonb ->> 'code',
                                                                                                               'id', itemPermLoc.locJsonb ->> 'id',
                                                                                                               'campusName', itemPermLoc.locCampJsonb ->> 'name',
                                                                                                               'libraryName', itemPermLoc.locLibJsonb ->> 'name',
                                                                                                               'libraryCode', itemPermLoc.locLibJsonb ->> 'code',
                                                                                                               'institutionName', itemPermLoc.locInstJsonb ->> 'name'),
                                                                                            'temporaryLocation',
                                                                                            jsonb_build_object('name', COALESCE(itemTempLoc.locJsonb ->> 'discoveryDisplayName', itemTempLoc.locJsonb ->> 'name'),
                                                                                                               'code', itemTempLoc.locJsonb ->> 'code',
                                                                                                               'id', itemTempLoc.locJsonb ->> 'id',
                                                                                                               'campusName', itemTempLoc.locCampJsonb ->> 'name',
                                                                                                               'libraryName', itemTempLoc.locLibJsonb ->> 'name',
                                                                                                               'libraryCode', itemTempLoc.locLibJsonb ->> 'code',
                                                                                                               'institutionName', itemTempLoc.locInstJsonb ->> 'name'))
                                                                      ELSE NULL END::jsonb,
                                                                 'callNumber', item.jsonb -> 'effectiveCallNumberComponents' ||
                                                                               jsonb_build_object('typeName', cnt.jsonb ->> 'name'),
                                                                 'accessionNumber', item.jsonb ->> 'accessionNumber',
                                                                 'barcode', item.jsonb ->> 'barcode',
                                                                 'copyNumber', item.jsonb ->> 'copyNumber',
                                                                 'volume', item.jsonb ->> 'volume',
                                                                 'enumeration', item.jsonb ->> 'enumeration',
                                                                 'chronology', item.jsonb ->>'chronology',
                                                                 'displaySummary', item.jsonb ->>'displaySummary',
                                                                 'yearCaption', item.jsonb -> 'yearCaption',
                                                                 'itemIdentifier', item.jsonb ->> 'itemIdentifier',
                                                                 'numberOfPieces', item.jsonb ->> 'numberOfPieces',
                                                                 'descriptionOfPieces', item.jsonb ->> 'descriptionOfPieces',
                                                                 'numberOfMissingPieces', item.jsonb ->> 'numberOfMissingPieces',
                                                                 'missingPieces', item.jsonb ->> 'missingPieces',
                                                                 'missingPiecesDate', item.jsonb ->> 'missingPiecesDate',
                                                                 'itemDamagedStatus', itemDmgStat.jsonb ->> 'name',
                                                                 'itemDamagedStatusDate', item.jsonb ->> 'itemDamagedStatusDate',
                                                                 'materialType', mt.jsonb ->> 'name',
                                                                 'materialTypeId', mt.jsonb ->> 'id',
                                                                 'permanentLoanType', plt.jsonb ->> 'name',
                                                                 'temporaryLoanType', tlt.jsonb ->> 'name',
                                                                 'electronicAccess',
                                                                 CASE WHEN item.id IS NOT NULL THEN
                                                                          COALESCE(getElectronicAccessName(COALESCE(item.jsonb #> '{electronicAccess}', '[]'::jsonb)), '[]'::jsonb)
                                                                      ELSE NULL::jsonb END,
                                                                 'notes',
                                                                 CASE WHEN item.id IS NOT NULL THEN
                                                                          COALESCE(getItemNoteTypeName(item.jsonb -> 'notes'), '[]'::jsonb)
                                                                      ELSE NULL END::jsonb,
                                                                 'tags', item.jsonb -> 'tags',
                                                                 'statisticalCodes',
                                                                 CASE WHEN item.id IS NOT NULL THEN
                                                                          COALESCE(getStatisticalCodes(item.jsonb -> 'statisticalCodeIds'), '[]'::jsonb)
                                                                      ELSE NULL END ::jsonb))
                                              FILTER (WHERE item.id IS NOT NULL AND NOT ($2 AND COALESCE((item.jsonb ->> 'discoverySuppress')::bool, false))), '[]'::jsonb)
                      ) itemsAndHoldings

              FROM quesnelia_mod_inventory_storage.holdings_record hr
                       JOIN quesnelia_mod_inventory_storage.instance i
                            ON i.id = hr.instanceid
                       JOIN viewInstances vi
                            ON vi.instId = i.id
                       LEFT JOIN quesnelia_mod_inventory_storage.bound_with_part bwp on bwp.holdingsrecordid = hr.id
                       LEFT JOIN quesnelia_mod_inventory_storage.item item
                                 ON item.holdingsrecordid = hr.id OR item.id = bwp.itemid
                  -- Item's Effective location relation
                       LEFT JOIN viewLocations itemEffLoc
                                 ON (item.jsonb ->> 'effectiveLocationId')::uuid = itemEffLoc.locId
                  -- Item's Permanent location relation
                       LEFT JOIN viewLocations itemPermLoc
                                 ON (item.jsonb ->> 'permanentLocationId')::uuid = itemPermLoc.locId
                  -- Item's Temporary location relation
                       LEFT JOIN viewLocations itemTempLoc
                                 ON (item.jsonb ->> 'temporaryLocationId')::uuid = itemTempLoc.locId
                  -- Item's Material type relation
                       LEFT JOIN quesnelia_mod_inventory_storage.material_type mt
                                 ON item.materialtypeid = mt.id
                  -- Item's Call number type relation
                       LEFT JOIN quesnelia_mod_inventory_storage.call_number_type cnt
                                 ON (item.jsonb #>> '{effectiveCallNumberComponents, typeId}')::uuid = cnt.id
                  -- Item's Damaged status relation
                       LEFT JOIN quesnelia_mod_inventory_storage.item_damaged_status itemDmgStat
                                 ON (item.jsonb ->> 'itemDamagedStatusId')::uuid = itemDmgStat.id
                  -- Item's Permanent loan type relation
                       LEFT JOIN quesnelia_mod_inventory_storage.loan_type plt
                                 ON (item.jsonb ->> 'permanentLoanTypeId')::uuid = plt.id
                  -- Item's Temporary loan type relation
                       LEFT JOIN quesnelia_mod_inventory_storage.loan_type tlt
                                 ON (item.jsonb ->> 'temporaryLoanTypeId')::uuid = tlt.id
                  -- Holdings type relation
                       LEFT JOIN quesnelia_mod_inventory_storage.holdings_type ht
                                 ON ht.id = hr.holdingstypeid
                  -- Holdings Permanent location relation
                       LEFT JOIN viewLocations holdPermLoc
                                 ON (hr.jsonb ->> 'permanentLocationId')::uuid = holdPermLoc.locId
                  -- Holdings Temporary location relation
                       LEFT JOIN viewLocations holdTempLoc
                                 ON (hr.jsonb ->> 'temporaryLocationId')::uuid = holdTempLoc.locId
                  -- Holdings Effective location relation
                       LEFT JOIN viewLocations holdEffLoc
                                 ON (hr.jsonb ->> 'effectiveLocationId')::uuid = holdEffLoc.locId
                  -- Holdings Call number type relation
                       LEFT JOIN quesnelia_mod_inventory_storage.call_number_type hrcnt
                                 ON (hr.jsonb ->> 'callNumberTypeId')::uuid = hrcnt.id
                  -- Holdings Ill policy relation
                       LEFT JOIN quesnelia_mod_inventory_storage.ill_policy ilp
                                 ON hr.illpolicyid = ilp.id
              WHERE true
                AND NOT ($2 AND COALESCE((hr.jsonb ->> 'discoverySuppress')::bool, false))
              GROUP BY 1
             ) itemAndHoldingsAttrs
    )
-- Instances with items and holding records
SELECT
    vi.instId AS "instanceId",
    vi.source AS "source",
    vi.modeOfIssuance AS "modeOfIssuance",
    vi.natureOfContent AS "natureOfContent",
    COALESCE(viah.records -> 'holdings', '[]'::jsonb) AS "holdings",
    COALESCE(viah.records -> 'items', '[]'::jsonb) AS "items"
FROM viewInstances vi
         LEFT JOIN viewItemsAndHoldings viah
                   ON viah.instId = vi.instId

$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.get_items_and_holdings_view(instanceids uuid[], skipsuppressedfromdiscoveryrecords boolean) OWNER TO postgres;

--
-- Name: get_tsvector(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.get_tsvector(text) RETURNS tsvector
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT to_tsvector('simple', translate($1, '&', ','));
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.get_tsvector(text) OWNER TO postgres;

--
-- Name: get_updated_instance_ids_view(timestamp with time zone, timestamp with time zone, boolean, boolean, boolean, character varying); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.get_updated_instance_ids_view(startdate timestamp with time zone, enddate timestamp with time zone, deletedrecordsupport boolean DEFAULT true, skipsuppressedfromdiscoveryrecords boolean DEFAULT true, onlyinstanceupdatedate boolean DEFAULT true, source character varying DEFAULT NULL::character varying) RETURNS TABLE("instanceId" uuid, source character varying, "updatedDate" timestamp with time zone, "suppressFromDiscovery" boolean, deleted boolean)
    LANGUAGE sql
    AS $_$
WITH instanceIdsInRange AS ( SELECT inst.id AS instanceId,
                                    (strToTimestamp(inst.jsonb -> 'metadata' ->> 'updatedDate')) AS maxDate
                             FROM quesnelia_mod_inventory_storage.instance inst
                             WHERE ($6 IS NULL OR inst.jsonb ->> 'source' = $6)
                             AND (strToTimestamp(inst.jsonb -> 'metadata' ->> 'updatedDate')) BETWEEN dateOrMin($1) AND dateOrMax($2)

                             UNION ALL
                             SELECT instanceid, MAX(maxdate) as maxdate
                               FROM (
                                     SELECT instanceid,(strToTimestamp(hr.jsonb -> 'metadata' ->> 'updatedDate')) as maxdate
                                       FROM quesnelia_mod_inventory_storage.holdings_record hr
                                      WHERE ((strToTimestamp(hr.jsonb -> 'metadata' ->> 'updatedDate')) BETWEEN dateOrMin($1) AND dateOrMax($2)
                                        AND NOT EXISTS (SELECT NULL WHERE $5))
                                     UNION
                                     SELECT instanceid, (strToTimestamp(item.jsonb -> 'metadata' ->> 'updatedDate')) AS maxDate
                                       FROM quesnelia_mod_inventory_storage.holdings_record hr
                                              INNER JOIN quesnelia_mod_inventory_storage.item item ON item.holdingsrecordid = hr.id
                                      WHERE (strToTimestamp(item.jsonb -> 'metadata' ->> 'updatedDate')) BETWEEN dateOrMin($1) AND dateOrMax($2)
                                        AND NOT EXISTS (SELECT NULL WHERE $5)
                                    ) AS related_hr_items
                                    GROUP BY instanceid
                             UNION ALL
                             SELECT (audit_holdings_record.jsonb #>> '{record,instanceId}')::uuid,
                                    greatest((strToTimestamp(audit_item.jsonb ->> 'createdDate')),
                                             (strToTimestamp(audit_holdings_record.jsonb ->> 'createdDate'))) AS maxDate
                             FROM quesnelia_mod_inventory_storage.audit_holdings_record audit_holdings_record
                                      JOIN quesnelia_mod_inventory_storage.audit_item audit_item
                                           ON (audit_item.jsonb ->> '{record,holdingsRecordId}')::uuid =
                                              (audit_holdings_record.jsonb ->> '{record,id}')::uuid
                             WHERE ((strToTimestamp(audit_holdings_record.jsonb ->> 'createdDate')) BETWEEN dateOrMin($1) AND dateOrMax($2) OR
                                    (strToTimestamp(audit_item.jsonb ->> 'createdDate')) BETWEEN dateOrMin($1) AND dateOrMax($2))
                                    AND NOT EXISTS (SELECT NULL WHERE $5)
                             UNION ALL -- case when only item was deleted
            						     SELECT hold_rec.instanceId,
                                    greatest((strToTimestamp(audit_item.jsonb ->> 'createdDate')),
                                             (strToTimestamp(hold_rec.jsonb -> 'metadata' ->> 'updatedDate'))) AS maxDate
                             FROM quesnelia_mod_inventory_storage.holdings_record hold_rec
                                      JOIN quesnelia_mod_inventory_storage.audit_item audit_item
                                          ON (audit_item.jsonb -> 'record' ->> 'holdingsRecordId')::uuid = hold_rec.id
                             WHERE ((strToTimestamp(hold_rec.jsonb -> 'metadata' ->> 'updatedDate')) BETWEEN dateOrMin($1) AND dateOrMax($2) OR
                                    (strToTimestamp(audit_item.jsonb ->> 'createdDate')) BETWEEN dateOrMin($1) AND dateOrMax($2))
                                    AND NOT EXISTS (SELECT NULL WHERE $5)
            						     UNION ALL -- case when only holding was deleted
            						     SELECT (audit_holdings_record.jsonb #>> '{record,instanceId}')::uuid,
                                     strToTimestamp(audit_holdings_record.jsonb ->> 'createdDate') AS maxDate
                             FROM quesnelia_mod_inventory_storage.audit_holdings_record audit_holdings_record
                             WHERE ((strToTimestamp(audit_holdings_record.jsonb ->> 'createdDate')) BETWEEN dateOrMin($1) AND dateOrMax($2))
                                     AND NOT EXISTS (SELECT NULL WHERE $5) )
SELECT instanceId,
       instance.jsonb ->> 'source' AS source,
       MAX(instanceIdsInRange.maxDate) AS maxDate,
       (instance.jsonb ->> 'discoverySuppress')::bool AS suppressFromDiscovery,
       false AS deleted
FROM instanceIdsInRange,
    quesnelia_mod_inventory_storage.instance
WHERE instanceIdsInRange.maxDate BETWEEN dateOrMin($1) AND dateOrMax($2)
      AND instance.id = instanceIdsInRange.instanceId
      AND NOT ($4 AND COALESCE((instance.jsonb ->> 'discoverySuppress')::bool, false))
      AND ($6 IS NULL OR instance.jsonb ->> 'source' = $6)
GROUP BY 1, 2, 4

UNION ALL
SELECT (jsonb #>> '{record,id}')::uuid              AS instanceId,
        jsonb #>> '{record,source}'                 AS source,
        strToTimestamp(jsonb ->> 'createdDate')     AS maxDate,
        false                                       AS suppressFromDiscovery,
        true                                        AS deleted
FROM quesnelia_mod_inventory_storage.audit_instance
WHERE $3
      AND strToTimestamp(jsonb ->> 'createdDate') BETWEEN dateOrMin($1) AND dateOrMax($2)
      AND ($6 IS NULL OR jsonb #>> '{record,source}' = $6)

$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.get_updated_instance_ids_view(startdate timestamp with time zone, enddate timestamp with time zone, deletedrecordsupport boolean, skipsuppressedfromdiscoveryrecords boolean, onlyinstanceupdatedate boolean, source character varying) OWNER TO postgres;

--
-- Name: getelectronicaccessname(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.getelectronicaccessname(val jsonb) RETURNS jsonb
    LANGUAGE sql STRICT
    AS $_$
SELECT jsonb_agg(DISTINCT e)
FROM ( SELECT e || jsonb_build_object('name', ( SELECT jsonb ->> 'name'
                                                FROM quesnelia_mod_inventory_storage.electronic_access_relationship
                                                WHERE id = nullif(e ->> 'relationshipId','')::uuid )) e
       FROM jsonb_array_elements($1) AS e ) e1
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.getelectronicaccessname(val jsonb) OWNER TO postgres;

--
-- Name: getholdingnotetypename(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.getholdingnotetypename(val jsonb) RETURNS jsonb
    LANGUAGE sql STRICT
    AS $_$
SELECT jsonb_agg(DISTINCT e)
FROM ( SELECT e - 'holdingsNoteTypeId' - 'staffOnly' ||
              jsonb_build_object('holdingsNoteTypeName', ( SELECT jsonb ->> 'name'
                                   FROM holdings_note_type
                                   WHERE id = nullif(e ->> 'holdingsNoteTypeId','')::uuid )) e
       FROM jsonb_array_elements( $1 ) AS e
	   WHERE NOT (e ->> 'staffOnly')::bool ) e1
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.getholdingnotetypename(val jsonb) OWNER TO postgres;

--
-- Name: getitemnotetypename(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.getitemnotetypename(val jsonb) RETURNS jsonb
    LANGUAGE sql STRICT
    AS $_$
SELECT jsonb_agg(DISTINCT e)
FROM ( SELECT e - 'itemNoteTypeId' - 'staffOnly' ||
              jsonb_build_object('itemNoteTypeName', ( SELECT jsonb ->> 'name'
                                 FROM item_note_type
                                 WHERE id = nullif(e ->> 'itemNoteTypeId','')::uuid )) e
       FROM jsonb_array_elements( $1 ) AS e
	   WHERE NOT (e ->> 'staffOnly')::bool ) e1
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.getitemnotetypename(val jsonb) OWNER TO postgres;

--
-- Name: getnatureofcontentname(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.getnatureofcontentname(val jsonb) RETURNS jsonb
    LANGUAGE sql STRICT
    AS $_$
SELECT jsonb_agg(DISTINCT e.name)
FROM (
	SELECT (jsonb ->> 'name') AS "name"
	FROM quesnelia_mod_inventory_storage.nature_of_content_term
		JOIN jsonb_array_elements($1) as insNoctIds
			ON id = nullif(insNoctIds ->> 0,'')::uuid) e
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.getnatureofcontentname(val jsonb) OWNER TO postgres;

--
-- Name: getstatisticalcodes(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.getstatisticalcodes(val jsonb) RETURNS jsonb
    LANGUAGE sql STRICT
    AS $_$
WITH stat_codes(statCodeId, statCodeJsonb, statCodeTypeJsonb) AS (
SELECT sc.id, sc.jsonb, sct.jsonb
FROM statistical_code sc
JOIN statistical_code_type sct ON sct.id = sc.statisticalcodetypeid
)
SELECT jsonb_agg(DISTINCT jsonb_build_object('id', sc.statCodeJsonb ->> 'id') ||
							  jsonb_build_object('code', sc.statCodeJsonb ->> 'code') ||
							  jsonb_build_object('name', sc.statCodeJsonb ->> 'name') ||
							  jsonb_build_object('statisticalCodeType', sc.statCodeTypeJsonb ->> 'name') ||
							  jsonb_build_object('source', sc.statCodeTypeJsonb ->> 'source'))
FROM jsonb_array_elements( $1 ) AS e,
     stat_codes sc
WHERE sc.statCodeId::text = (e ->> 0)::text
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.getstatisticalcodes(val jsonb) OWNER TO postgres;

--
-- Name: holdings_note_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.holdings_note_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.holdings_note_type_set_md() OWNER TO postgres;

--
-- Name: holdings_record_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.holdings_record_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.holdings_record_set_md() OWNER TO postgres;

--
-- Name: holdings_record_set_ol_version(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.holdings_record_set_ol_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    CASE TG_OP
      WHEN 'INSERT' THEN
          NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}', to_jsonb(1));
      WHEN 'UPDATE' THEN
        IF NEW.jsonb->'_version' = '-1' THEN
          IF OLD.jsonb->'_version' IS NULL THEN
            NEW.jsonb = NEW.jsonb - '_version';
          ELSE
            NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}', OLD.jsonb->'_version');
          END IF;
        END IF;
        IF NEW.jsonb->'_version' IS DISTINCT FROM OLD.jsonb->'_version' THEN
            RAISE 'Cannot update record % because it has been changed (optimistic locking): '
                'Stored _version is %, _version of request is %',
                OLD.id, OLD.jsonb->'_version', NEW.jsonb->'_version' 
                USING ERRCODE = '23F09', TABLE = 'holdings_record', SCHEMA = 'quesnelia_mod_inventory_storage';
        END IF;
        NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}',
            to_jsonb(COALESCE(((OLD.jsonb->>'_version')::numeric + 1) % 2147483648, 1)));
    END CASE;
    RETURN NEW;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.holdings_record_set_ol_version() OWNER TO postgres;

--
-- Name: holdings_records_source_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.holdings_records_source_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.holdings_records_source_set_md() OWNER TO postgres;

--
-- Name: holdings_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.holdings_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.holdings_type_set_md() OWNER TO postgres;

--
-- Name: hrid_settings_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.hrid_settings_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.hrid_settings_set_md() OWNER TO postgres;

--
-- Name: identifier_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.identifier_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.identifier_type_set_md() OWNER TO postgres;

--
-- Name: ill_policy_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.ill_policy_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.ill_policy_set_md() OWNER TO postgres;

--
-- Name: instance_note_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.instance_note_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.instance_note_type_set_md() OWNER TO postgres;

--
-- Name: instance_relationship_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.instance_relationship_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.instance_relationship_set_md() OWNER TO postgres;

--
-- Name: instance_relationship_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.instance_relationship_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.instance_relationship_type_set_md() OWNER TO postgres;

--
-- Name: instance_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.instance_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.instance_set_md() OWNER TO postgres;

--
-- Name: instance_set_ol_version(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.instance_set_ol_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    CASE TG_OP
      WHEN 'INSERT' THEN
          NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}', to_jsonb(1));
      WHEN 'UPDATE' THEN
        IF NEW.jsonb->'_version' = '-1' THEN
          IF OLD.jsonb->'_version' IS NULL THEN
            NEW.jsonb = NEW.jsonb - '_version';
          ELSE
            NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}', OLD.jsonb->'_version');
          END IF;
        END IF;
        IF NEW.jsonb->'_version' IS DISTINCT FROM OLD.jsonb->'_version' THEN
            RAISE 'Cannot update record % because it has been changed (optimistic locking): '
                'Stored _version is %, _version of request is %',
                OLD.id, OLD.jsonb->'_version', NEW.jsonb->'_version' 
                USING ERRCODE = '23F09', TABLE = 'instance', SCHEMA = 'quesnelia_mod_inventory_storage';
        END IF;
        NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}',
            to_jsonb(COALESCE(((OLD.jsonb->>'_version')::numeric + 1) % 2147483648, 1)));
    END CASE;
    RETURN NEW;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.instance_set_ol_version() OWNER TO postgres;

--
-- Name: instance_source_marc_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.instance_source_marc_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.instance_source_marc_set_md() OWNER TO postgres;

--
-- Name: instance_status_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.instance_status_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.instance_status_set_md() OWNER TO postgres;

--
-- Name: item_damaged_status_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.item_damaged_status_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.item_damaged_status_set_md() OWNER TO postgres;

--
-- Name: item_note_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.item_note_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.item_note_type_set_md() OWNER TO postgres;

--
-- Name: item_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.item_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.item_set_md() OWNER TO postgres;

--
-- Name: item_set_ol_version(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.item_set_ol_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    CASE TG_OP
      WHEN 'INSERT' THEN
          NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}', to_jsonb(1));
      WHEN 'UPDATE' THEN
        IF NEW.jsonb->'_version' = '-1' THEN
          IF OLD.jsonb->'_version' IS NULL THEN
            NEW.jsonb = NEW.jsonb - '_version';
          ELSE
            NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}', OLD.jsonb->'_version');
          END IF;
        END IF;
        IF NEW.jsonb->'_version' IS DISTINCT FROM OLD.jsonb->'_version' THEN
            RAISE 'Cannot update record % because it has been changed (optimistic locking): '
                'Stored _version is %, _version of request is %',
                OLD.id, OLD.jsonb->'_version', NEW.jsonb->'_version' 
                USING ERRCODE = '23F09', TABLE = 'item', SCHEMA = 'quesnelia_mod_inventory_storage';
        END IF;
        NEW.jsonb = jsonb_set(NEW.jsonb, '{_version}',
            to_jsonb(COALESCE(((OLD.jsonb->>'_version')::numeric + 1) % 2147483648, 1)));
    END CASE;
    RETURN NEW;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.item_set_ol_version() OWNER TO postgres;

--
-- Name: loan_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.loan_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.loan_type_set_md() OWNER TO postgres;

--
-- Name: location_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.location_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.location_set_md() OWNER TO postgres;

--
-- Name: loccampus_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.loccampus_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.loccampus_set_md() OWNER TO postgres;

--
-- Name: locinstitution_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.locinstitution_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.locinstitution_set_md() OWNER TO postgres;

--
-- Name: loclibrary_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.loclibrary_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.loclibrary_set_md() OWNER TO postgres;

--
-- Name: material_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.material_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.material_type_set_md() OWNER TO postgres;

--
-- Name: migrate_series_and_subjects(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.migrate_series_and_subjects(jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
DECLARE
  instance jsonb := $1;
BEGIN
  IF jsonb_typeof(instance->'series'->0) = 'string' THEN
    instance = jsonb_set(instance, '{series}',
      (SELECT COALESCE(jsonb_agg(v), '[]')
              FROM (SELECT jsonb_build_object('value', jsonb_array_elements_text(instance->'series')) AS v) x));
  END IF;
  IF jsonb_typeof(instance->'subjects'->0) = 'string' THEN
    instance = jsonb_set(instance, '{subjects}',
      (SELECT COALESCE(jsonb_agg(v), '[]')
              FROM (SELECT jsonb_build_object('value', jsonb_array_elements_text(instance->'subjects')) AS v) x));
  END IF;
  RETURN instance;
END;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.migrate_series_and_subjects(jsonb) OWNER TO postgres;

--
-- Name: mode_of_issuance_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.mode_of_issuance_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.mode_of_issuance_set_md() OWNER TO postgres;

--
-- Name: nature_of_content_term_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.nature_of_content_term_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.nature_of_content_term_set_md() OWNER TO postgres;

--
-- Name: next_uuid(uuid); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.next_uuid(uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $_$
DECLARE
  uuid text;
  digit text;
BEGIN
  uuid = $1;
  FOR i IN REVERSE 36..1 LOOP
    digit := substring(uuid from i for 1);
    -- skip minus, version byte M and variant byte N
    CONTINUE WHEN digit = '-' OR i = 15 OR i = 20;
    CASE digit
      WHEN '0' THEN digit := '1';
      WHEN '1' THEN digit := '2';
      WHEN '2' THEN digit := '3';
      WHEN '3' THEN digit := '4';
      WHEN '4' THEN digit := '5';
      WHEN '5' THEN digit := '6';
      WHEN '6' THEN digit := '7';
      WHEN '7' THEN digit := '8';
      WHEN '8' THEN digit := '9';
      WHEN '9' THEN digit := 'a';
      WHEN 'a' THEN digit := 'b';
      WHEN 'b' THEN digit := 'c';
      WHEN 'c' THEN digit := 'd';
      WHEN 'd' THEN digit := 'e';
      WHEN 'e' THEN digit := 'f';
      WHEN 'f' THEN digit := '0';
      ELSE NULL;
    END CASE;
    uuid = overlay(uuid placing digit from i);
    EXIT WHEN digit <> '0';
  END LOOP;
  RETURN uuid;
END;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.next_uuid(uuid) OWNER TO postgres;

--
-- Name: normalize_digits(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.normalize_digits(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT    translate((regexp_match($1, '^([0-9 \t-]*(?:\*[ \t]*)?)(.*)'))[1], E' \t-', '')
         || CASE WHEN (regexp_match($1, '^([0-9 \t-]*(?:\*[ \t]*)?)(.*)'))[1] = '' THEN ''
                 WHEN (regexp_match($1, '^([0-9 \t-]*(?:\*[ \t]*)?)(.*)'))[2] = '' THEN ''
                 ELSE ' '
            END
         || (regexp_match($1, '^([0-9 \t-]*(?:\*[ \t]*)?)(.*)'))[2];
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.normalize_digits(text) OWNER TO postgres;

--
-- Name: normalize_invalid_isbns(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.normalize_invalid_isbns(jsonb_array jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT string_agg(quesnelia_mod_inventory_storage.normalize_digits(identifier->>'value'), ' ')
  FROM jsonb_array_elements($1) as identifier
  WHERE identifier->>'identifierTypeId' = 'fcca2643-406a-482a-b760-7a7f8aec640e';
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.normalize_invalid_isbns(jsonb_array jsonb) OWNER TO postgres;

--
-- Name: normalize_isbns(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.normalize_isbns(jsonb_array jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT string_agg(quesnelia_mod_inventory_storage.normalize_digits(identifier->>'value'), ' ')
  FROM jsonb_array_elements($1) as identifier
  WHERE identifier->>'identifierTypeId' = '8261054f-be78-422d-bd51-4ed9f33c3422';
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.normalize_isbns(jsonb_array jsonb) OWNER TO postgres;

--
-- Name: parse_end_year(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.parse_end_year(jsonb) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT COALESCE(
    (regexp_match($1->'publication'->-1->>'dateOfPublication', '(?:-\s?|and\s|,\s?)\w{0,2}(\d{4})'))[1],
    (regexp_match($1->'publication'->-1->>'dateOfPublication', '\d{4}'))[1],
    (regexp_match($1->'publication'-> 0->>'dateOfPublication', '(?:-\s?|and\s|,\s?)\w{0,2}(\d{4})'))[1],
    (regexp_match($1->'publication'-> 0->>'dateOfPublication', '\d{4}'))[1]
  )::int;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.parse_end_year(jsonb) OWNER TO postgres;

--
-- Name: parse_publication_period(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.parse_publication_period(jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT CASE
    WHEN $1->'publication' IS NULL THEN NULL
    WHEN jsonb_array_length($1->'publication') = 0 THEN NULL
    WHEN parse_start_year($1) IS NULL AND parse_end_year($1) IS NULL THEN NULL
    WHEN parse_start_year($1) IS NULL THEN jsonb_build_object('end', parse_end_year($1))
    WHEN parse_end_year($1) IS NULL OR parse_start_year($1) >= parse_end_year($1)
        THEN jsonb_build_object('start', parse_start_year($1))
    ELSE jsonb_build_object('start', parse_start_year($1), 'end', parse_end_year($1))
  END;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.parse_publication_period(jsonb) OWNER TO postgres;

--
-- Name: parse_start_year(jsonb); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.parse_start_year(jsonb) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT COALESCE(
    (regexp_match($1->'publication'->0->>'dateOfPublication', '(\d{4})\w{0,2}(?:\s?-|\sand|\s?,)'))[1],
    (regexp_match($1->'publication'->0->>'dateOfPublication', '\d{4}'))[1]
  )::int;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.parse_start_year(jsonb) OWNER TO postgres;

--
-- Name: pmh_get_updated_instances_ids(timestamp with time zone, timestamp with time zone, boolean, boolean); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.pmh_get_updated_instances_ids(startdate timestamp with time zone, enddate timestamp with time zone, deletedrecordsupport boolean DEFAULT true, skipsuppressedfromdiscoveryrecords boolean DEFAULT true) RETURNS TABLE(instanceid uuid, updateddate timestamp with time zone, suppressfromdiscovery boolean, deleted boolean)
    LANGUAGE sql
    AS $_$
with instanceIdsInRange as ( select inst.id                                                       as instanceId,
                                    (strToTimestamp(inst.jsonb -> 'metadata' ->> 'updatedDate')) as maxDate
                             from quesnelia_mod_inventory_storage.instance inst
                             where (strToTimestamp(inst.jsonb -> 'metadata' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2)

                             union all
                             select instanceid,
                                    greatest((strToTimestamp(item.jsonb -> 'metadata' ->> 'updatedDate')),
                                             (strToTimestamp(hr.jsonb -> 'metadata' ->> 'updatedDate'))) as maxDate
                             from holdings_record hr
                                      join quesnelia_mod_inventory_storage.item item on item.holdingsrecordid = hr.id
                             where ((strToTimestamp(hr.jsonb -> 'metadata' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2) or
                                    (strToTimestamp(item.jsonb -> 'metadata' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2))

                             union all
                             select (audit_holdings_record.jsonb #>> '{record,instanceId}')::uuid,
                                    greatest((strtotimestamp(audit_item.jsonb -> 'record' ->> 'updatedDate')),
                                             (strtotimestamp(audit_holdings_record.jsonb -> 'record' ->> 'updatedDate'))) as maxDate
                             from audit_holdings_record audit_holdings_record
                                      join audit_item audit_item
                                           on (audit_item.jsonb ->> '{record,holdingsRecordId}')::uuid =
                                              audit_holdings_record.id
                             where ((strToTimestamp(audit_holdings_record.jsonb -> 'record' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2) or
                                    (strToTimestamp(audit_item.jsonb #>> '{record,updatedDate}')) between dateOrMin($1) and dateOrMax($2)) )

select instanceId,
                    max(instanceIdsInRange.maxDate)    as maxDate,
        (instance.jsonb ->> 'discoverySuppress')::bool as suppressFromDiscovery,
                                                 false as deleted
                                     from instanceIdsInRange,
                                          instance
                                     where instanceIdsInRange.maxDate between dateOrMin($1) and dateOrMax($2)
                                       and instance.id = instanceIdsInRange.instanceId
                                       and not ($4 and coalesce((instance.jsonb ->> 'discoverySuppress')::bool, false))
                                     group by 1, 3
union all
select (audit_instance.jsonb #>> '{record,id}')::uuid as instanceId,
       strToTimestamp(jsonb ->> 'createdDate')        as maxDate,
       false                                          as suppressFromDiscovery,
       true                                           as deleted
from quesnelia_mod_inventory_storage.audit_instance
where $3
  and strToTimestamp(jsonb ->> 'createdDate') between dateOrMin($1) and dateOrMax($2)

$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.pmh_get_updated_instances_ids(startdate timestamp with time zone, enddate timestamp with time zone, deletedrecordsupport boolean, skipsuppressedfromdiscoveryrecords boolean) OWNER TO postgres;

--
-- Name: pmh_instance_view_function(uuid[], boolean); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.pmh_instance_view_function(instanceids uuid[], skipsuppressedfromdiscoveryrecords boolean DEFAULT true) RETURNS TABLE(instanceid uuid, itemsandholdingsfields jsonb)
    LANGUAGE sql
    AS $_$
select instId,
(select to_jsonb(itemAndHoldingsAttrs) as itemsAndHoldingsFields
         from ( select hr.instanceid,
                       jsonb_agg(jsonb_build_object('id', item.id, 'callNumber',
                                                    item.jsonb -> 'effectiveCallNumberComponents'
                                                        || jsonb_build_object('typeName',cnt.jsonb ->> 'name'),
                                                    'location',
                                                    json_build_object('location', jsonb_build_object('institutionId',
                                                                                                     itemLocInst.id,
                                                                                                     'institutionName',
                                                                                                     itemLocInst.jsonb ->> 'name',
                                                                                                     'campusId',
                                                                                                     itemLocCamp.id,
                                                                                                     'campusName',
                                                                                                     itemLocCamp.jsonb ->> 'name',
                                                                                                     'libraryId',
                                                                                                     itemLocLib.id,
                                                                                                     'libraryName',
                                                                                                     itemLocLib.jsonb ->> 'name'),
                                                                                                      'name',
                                                                                                      coalesce(loc.jsonb ->> 'discoveryDisplayName', loc.jsonb ->> 'name')),
                                                    'volume',
                                                    item.jsonb -> 'volume',
                                                    'enumeration',
                                                    item.jsonb -> 'enumeration',
                                                    'materialType',
                                                    mt.jsonb -> 'name',
                                                    'electronicAccess',
                                                    getElectronicAccessName(
                                                                coalesce(item.jsonb #> '{electronicAccess}', '[]'::jsonb) ||
                                                                coalesce(hr.jsonb #> '{electronicAccess}', '[]'::jsonb)),
                                                    'suppressFromDiscovery',
                                                                coalesce((hr.jsonb ->> 'discoverySuppress')::bool, false) or
                                                                coalesce((item.jsonb ->> 'discoverySuppress')::bool, false),
                                                    'notes',
                                                    getItemNoteTypeName(item.jsonb-> 'notes'),
                                                    'barcode',
                                                    item.jsonb->>'barcode',
                                                    'chronology',
                                                    item.jsonb->>'chronology',
                                                    'copyNumber',
                                                    item.jsonb->>'copyNumber',
                                                    'holdingsRecordId',
                                                    hr.id
                           )) items
                from holdings_record hr
                         join quesnelia_mod_inventory_storage.item item on item.holdingsrecordid = hr.id
                         join quesnelia_mod_inventory_storage.location loc
                              on (item.jsonb ->> 'effectiveLocationId')::uuid = loc.id and
                                 (loc.jsonb ->> 'isActive')::bool = true
                         join quesnelia_mod_inventory_storage.locinstitution itemLocInst
                              on (loc.jsonb ->> 'institutionId')::uuid = itemLocInst.id
                         join quesnelia_mod_inventory_storage.loccampus itemLocCamp
                              on (loc.jsonb ->> 'campusId')::uuid = itemLocCamp.id
                         join quesnelia_mod_inventory_storage.loclibrary itemLocLib
                              on (loc.jsonb ->> 'libraryId')::uuid = itemLocLib.id
                         left join quesnelia_mod_inventory_storage.material_type mt on item.materialtypeid = mt.id
                         left join quesnelia_mod_inventory_storage.call_number_type cnt on nullif(item.jsonb #>> '{effectiveCallNumberComponents, typeId}','')::uuid = cnt.id
                where instanceId = instId
                  and not ($2 and coalesce((hr.jsonb ->> 'discoverySuppress')::bool, false))
                  and not ($2 and coalesce((item.jsonb ->> 'discoverySuppress')::bool, false))
                group by 1) itemAndHoldingsAttrs)
FROM unnest( $1 ) AS instId;

$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.pmh_instance_view_function(instanceids uuid[], skipsuppressedfromdiscoveryrecords boolean) OWNER TO postgres;

--
-- Name: pmh_view_function(timestamp with time zone, timestamp with time zone, boolean, boolean); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.pmh_view_function(startdate timestamp with time zone, enddate timestamp with time zone, deletedrecordsupport boolean DEFAULT true, skipsuppressedfromdiscoveryrecords boolean DEFAULT true) RETURNS TABLE(instanceid uuid, updateddate timestamp with time zone, deleted boolean, itemsandholdingsfields jsonb)
    LANGUAGE sql
    AS $_$
with instanceIdsInRange as ( select inst.id                                                      as instanceId,
                                    (strToTimestamp(inst.jsonb -> 'metadata' ->> 'updatedDate')) as maxDate
                             from quesnelia_mod_inventory_storage.instance inst
                             where (strToTimestamp(inst.jsonb -> 'metadata' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2)

                             union all
                             select instanceid,
                                    greatest((strToTimestamp(item.jsonb -> 'metadata' ->> 'updatedDate')),
                                             (strToTimestamp(hr.jsonb -> 'metadata' ->> 'updatedDate'))) as maxDate
                             from holdings_record hr
                                      join quesnelia_mod_inventory_storage.item item on item.holdingsrecordid = hr.id
                             where ((strToTimestamp(hr.jsonb -> 'metadata' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2) or
                                    (strToTimestamp(item.jsonb -> 'metadata' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2))

                             union all
                             select (audit_holdings_record.jsonb #>> '{record,instanceId}')::uuid,
                                    greatest((strtotimestamp(audit_item.jsonb -> 'record' ->> 'updatedDate')),
                                             (strtotimestamp(audit_holdings_record.jsonb -> 'record' ->> 'updatedDate'))) as maxDate
                             from audit_holdings_record audit_holdings_record
                                      join audit_item audit_item
                                           on (audit_item.jsonb ->> '{record,holdingsRecordId}')::uuid =
                                              audit_holdings_record.id
                             where ((strToTimestamp(audit_holdings_record.jsonb -> 'record' ->> 'updatedDate')) between dateOrMin($1) and dateOrMax($2) or
                                    (strToTimestamp(audit_item.jsonb #>> '{record,updatedDate}')) between dateOrMin($1) and dateOrMax($2)) ),
     instanceIdsAndDatesInRange as ( select instanceId, max(instanceIdsInRange.maxDate) as maxDate,
                                            (instance.jsonb ->> 'discoverySuppress')::bool as suppressFromDiscovery
                                     from instanceIdsInRange,
                                          instance
                                     where instanceIdsInRange.maxDate between dateOrMin($1) and dateOrMax($2)
                                       and instance.id = instanceIdsInRange.instanceId
                                       and not ($4 and coalesce((instance.jsonb ->> 'discoverySuppress')::bool, false))
                                     group by 1, 3)

select instanceIdsAndDatesInRange.instanceId,
       instanceIdsAndDatesInRange.maxDate,
       false as deleted,
       ( select to_jsonb(itemAndHoldingsAttrs) as instanceFields
         from ( select hr.instanceid,
                       instanceIdsAndDatesInRange.suppressFromDiscovery as suppressFromDiscovery,
                       jsonb_agg(jsonb_build_object('id', item.id, 'callNumber',
                                                    item.jsonb -> 'effectiveCallNumberComponents'
                                                        || jsonb_build_object('typeName',cnt.jsonb ->> 'name'),
                                                    'location',
                                                    json_build_object('location', jsonb_build_object('institutionId',
                                                                                                     itemLocInst.id,
                                                                                                     'institutionName',
                                                                                                     itemLocInst.jsonb ->> 'name',
                                                                                                     'campusId',
                                                                                                     itemLocCamp.id,
                                                                                                     'campusName',
                                                                                                     itemLocCamp.jsonb ->> 'name',
                                                                                                     'libraryId',
                                                                                                     itemLocLib.id,
                                                                                                     'libraryName',
                                                                                                     itemLocLib.jsonb ->> 'name'),
                                                                                                      'name',
                                                                                                      coalesce(loc.jsonb ->> 'discoveryDisplayName', loc.jsonb ->> 'name')),
                                                    'volume',
                                                    item.jsonb -> 'volume',
                                                    'enumeration',
                                                    item.jsonb -> 'enumeration',
                                                    'materialType',
                                                    mt.jsonb -> 'name',
                                                    'electronicAccess',
                                                    getElectronicAccessName(
                                                                coalesce(item.jsonb #> '{electronicAccess}', '[]'::jsonb) ||
                                                                coalesce(hr.jsonb #> '{electronicAccess}', '[]'::jsonb)),
                                                    'suppressFromDiscovery',
                                                    case
                                                        when instanceIdsAndDatesInRange.suppressFromDiscovery
                                                            then true
                                                        else
                                                                coalesce((hr.jsonb ->> 'discoverySuppress')::bool, false) or
                                                                coalesce((item.jsonb ->> 'discoverySuppress')::bool, false)
                                                        end,
                                                    'notes',
                                                    getItemNoteTypeName(item.jsonb-> 'notes'),
                                                    'barcode',
                                                    item.jsonb->>'barcode',
                                                    'chronology',
                                                    item.jsonb->>'chronology',
                                                    'copyNumber',
                                                    item.jsonb->>'copyNumber',
                                                    'holdingsRecordId',
                                                    hr.id
                           )) items
                from holdings_record hr
                         join quesnelia_mod_inventory_storage.item item on item.holdingsrecordid = hr.id
                         join quesnelia_mod_inventory_storage.location loc
                              on (item.jsonb ->> 'effectiveLocationId')::uuid = loc.id and
                                 (loc.jsonb ->> 'isActive')::bool = true
                         join quesnelia_mod_inventory_storage.locinstitution itemLocInst
                              on (loc.jsonb ->> 'institutionId')::uuid = itemLocInst.id
                         join quesnelia_mod_inventory_storage.loccampus itemLocCamp
                              on (loc.jsonb ->> 'campusId')::uuid = itemLocCamp.id
                         join quesnelia_mod_inventory_storage.loclibrary itemLocLib
                              on (loc.jsonb ->> 'libraryId')::uuid = itemLocLib.id
                         left join quesnelia_mod_inventory_storage.material_type mt on item.materialtypeid = mt.id
                         left join quesnelia_mod_inventory_storage.call_number_type cnt on nullif(item.jsonb #>> '{effectiveCallNumberComponents, typeId}','')::uuid = cnt.id
                where instanceId = instanceIdsAndDatesInRange.instanceId
                  and not ($4 and coalesce((hr.jsonb ->> 'discoverySuppress')::bool, false))
                  and not ($4 and coalesce((item.jsonb ->> 'discoverySuppress')::bool, false))
                group by 1) itemAndHoldingsAttrs )
from instanceIdsAndDatesInRange
union all
select (audit_instance.jsonb #>> '{record,id}')::uuid as instanceId,
       strToTimestamp(jsonb ->> 'createdDate')         as maxDate,
       true                                           as deleted,
       null                                           as itemFields
from quesnelia_mod_inventory_storage.audit_instance
where $3
  and strToTimestamp(jsonb ->> 'createdDate') between dateOrMin($1) and dateOrMax($2)

$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.pmh_view_function(startdate timestamp with time zone, enddate timestamp with time zone, deletedrecordsupport boolean, skipsuppressedfromdiscoveryrecords boolean) OWNER TO postgres;

--
-- Name: preceding_succeeding_title_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.preceding_succeeding_title_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.preceding_succeeding_title_set_md() OWNER TO postgres;

--
-- Name: process_statistical_code_delete(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.process_statistical_code_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    item_fk_counter integer := 0;
    holding_fk_counter integer := 0;
    instance_fk_counter integer := 0;
  BEGIN
    IF (TG_OP = 'DELETE') THEN
      SELECT COUNT(*) INTO item_fk_counter FROM item WHERE jsonb->'statisticalCodeIds' ? OLD.id::text;
      IF (item_fk_counter > 0) THEN
        RAISE foreign_key_violation USING DETAIL = format('Key (id)=(%s) is still referenced from table "item".', OLD.id::text);
      END IF;

      SELECT COUNT(*) INTO holding_fk_counter FROM holdings_record WHERE jsonb->'statisticalCodeIds' ? OLD.id::text;
      IF (holding_fk_counter > 0) THEN
        RAISE foreign_key_violation USING DETAIL = format('Key (id)=(%s) is still referenced from table "holdings record".', OLD.id::text);
      END IF;

      SELECT COUNT(*) INTO instance_fk_counter FROM instance WHERE jsonb->'statisticalCodeIds' ? OLD.id::text;
      IF (instance_fk_counter > 0) THEN
        RAISE foreign_key_violation USING DETAIL = format('Key (id)=(%s) is still referenced from table "instance".', OLD.id::text);
      END IF;
    END IF;
    RETURN OLD;
  END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.process_statistical_code_delete() OWNER TO postgres;

--
-- Name: rmb_internal_index(text, text, text, text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.rmb_internal_index(atable text, aname text, tops text, newdef text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
  olddef text;
  namep CONSTANT text = concat(aname, '_p');
  prepareddef text;
BEGIN
  IF tops = 'DELETE' THEN
    -- use case insensitive %s, not case sensitive %I
    -- no SQL injection because the names are hard-coded in schema.json
    EXECUTE format('DROP INDEX IF EXISTS %s', aname);
    EXECUTE 'DELETE FROM quesnelia_mod_inventory_storage.rmb_internal_index WHERE name = $1' USING aname;
    RETURN;
  END IF;
  SELECT def INTO olddef      FROM quesnelia_mod_inventory_storage.rmb_internal_index WHERE name = aname;
  SELECT def INTO prepareddef FROM quesnelia_mod_inventory_storage.rmb_internal_index WHERE name = namep;
  prepareddef = replace(prepareddef, concat(' ', namep, ' ON '), concat(' ', aname, ' ON '));
  IF prepareddef = newdef THEN
    EXECUTE format('DROP INDEX IF EXISTS %s', aname);
    EXECUTE format('ALTER INDEX IF EXISTS %s RENAME TO %s', namep, aname);
    EXECUTE 'DELETE FROM rmb_internal_index WHERE name = $1' USING namep;
    EXECUTE 'INSERT INTO rmb_internal_analyze VALUES ($1)' USING atable;
  ELSIF olddef IS DISTINCT FROM newdef THEN
    EXECUTE format('DROP INDEX IF EXISTS %s', aname);
    EXECUTE newdef;
    EXECUTE 'INSERT INTO rmb_internal_analyze VALUES ($1)' USING atable;
  END IF;
  EXECUTE 'INSERT INTO quesnelia_mod_inventory_storage.rmb_internal_index VALUES ($1, $2, FALSE) '
          'ON CONFLICT (name) DO UPDATE SET def = EXCLUDED.def, remove = EXCLUDED.remove' USING aname, newdef;
END
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.rmb_internal_index(atable text, aname text, tops text, newdef text) OWNER TO postgres;

--
-- Name: service_point_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.service_point_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.service_point_set_md() OWNER TO postgres;

--
-- Name: service_point_user_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.service_point_user_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.service_point_user_set_md() OWNER TO postgres;

--
-- Name: set_alternative_title_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_alternative_title_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_alternative_title_type_md_json() OWNER TO postgres;

--
-- Name: set_bound_with_part_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_bound_with_part_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_bound_with_part_md_json() OWNER TO postgres;

--
-- Name: set_call_number_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_call_number_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_call_number_type_md_json() OWNER TO postgres;

--
-- Name: set_classification_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_classification_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_classification_type_md_json() OWNER TO postgres;

--
-- Name: set_contributor_name_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_contributor_name_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_contributor_name_type_md_json() OWNER TO postgres;

--
-- Name: set_electronic_access_relationship_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_electronic_access_relationship_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_electronic_access_relationship_md_json() OWNER TO postgres;

--
-- Name: set_holdings_note_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_holdings_note_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_holdings_note_type_md_json() OWNER TO postgres;

--
-- Name: set_holdings_record_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_holdings_record_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_holdings_record_md_json() OWNER TO postgres;

--
-- Name: set_holdings_records_source_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_holdings_records_source_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_holdings_records_source_md_json() OWNER TO postgres;

--
-- Name: set_holdings_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_holdings_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_holdings_type_md_json() OWNER TO postgres;

--
-- Name: set_hrid_settings_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_hrid_settings_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_hrid_settings_md_json() OWNER TO postgres;

--
-- Name: set_id_in_jsonb(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.jsonb = jsonb_set(NEW.jsonb, '{id}', to_jsonb(NEW.id));
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb() OWNER TO postgres;

--
-- Name: set_identifier_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_identifier_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_identifier_type_md_json() OWNER TO postgres;

--
-- Name: set_ill_policy_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_ill_policy_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_ill_policy_md_json() OWNER TO postgres;

--
-- Name: set_instance_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_md_json() OWNER TO postgres;

--
-- Name: set_instance_note_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_note_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_note_type_md_json() OWNER TO postgres;

--
-- Name: set_instance_relationship_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_relationship_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_relationship_md_json() OWNER TO postgres;

--
-- Name: set_instance_relationship_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_relationship_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_relationship_type_md_json() OWNER TO postgres;

--
-- Name: set_instance_source_marc_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_source_marc_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_source_marc_md_json() OWNER TO postgres;

--
-- Name: set_instance_sourcerecordformat(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_sourcerecordformat() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    CASE TG_OP
    WHEN 'INSERT' THEN
      -- a newly inserted instance cannot have a source record because of foreign key relationship
      NEW.jsonb := NEW.jsonb - 'sourceRecordFormat';
    ELSE
      NEW.jsonb := CASE (SELECT count(*) FROM quesnelia_mod_inventory_storage.instance_source_marc WHERE id=NEW.id)
                   WHEN 0 THEN NEW.jsonb - 'sourceRecordFormat'
                   ELSE jsonb_set(NEW.jsonb, '{sourceRecordFormat}', '"MARC-JSON"')
                   END;
    END CASE;
    RETURN NEW;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_sourcerecordformat() OWNER TO postgres;

--
-- Name: set_instance_status_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_status_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_status_md_json() OWNER TO postgres;

--
-- Name: set_instance_status_updated_date(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_instance_status_updated_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		IF (OLD.jsonb->'statusId' IS DISTINCT FROM NEW.jsonb->'statusId') THEN
			-- Date time in "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" format at UTC (00:00) time zone
			NEW.jsonb = jsonb_set(
		    NEW.jsonb, '{statusUpdatedDate}',
			  to_jsonb(to_char(CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.ms"Z"'))
		  );
		END IF;
		RETURN NEW;
	END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_instance_status_updated_date() OWNER TO postgres;

--
-- Name: set_item_damaged_status_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_item_damaged_status_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_item_damaged_status_md_json() OWNER TO postgres;

--
-- Name: set_item_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_item_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_item_md_json() OWNER TO postgres;

--
-- Name: set_item_note_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_item_note_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_item_note_type_md_json() OWNER TO postgres;

--
-- Name: set_loan_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_loan_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_loan_type_md_json() OWNER TO postgres;

--
-- Name: set_location_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_location_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_location_md_json() OWNER TO postgres;

--
-- Name: set_loccampus_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_loccampus_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_loccampus_md_json() OWNER TO postgres;

--
-- Name: set_locinstitution_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_locinstitution_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_locinstitution_md_json() OWNER TO postgres;

--
-- Name: set_loclibrary_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_loclibrary_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_loclibrary_md_json() OWNER TO postgres;

--
-- Name: set_material_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_material_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_material_type_md_json() OWNER TO postgres;

--
-- Name: set_mode_of_issuance_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_mode_of_issuance_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_mode_of_issuance_md_json() OWNER TO postgres;

--
-- Name: set_nature_of_content_term_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_nature_of_content_term_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_nature_of_content_term_md_json() OWNER TO postgres;

--
-- Name: set_preceding_succeeding_title_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_preceding_succeeding_title_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_preceding_succeeding_title_md_json() OWNER TO postgres;

--
-- Name: set_service_point_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_service_point_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_service_point_md_json() OWNER TO postgres;

--
-- Name: set_service_point_user_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_service_point_user_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_service_point_user_md_json() OWNER TO postgres;

--
-- Name: set_statistical_code_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_statistical_code_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_statistical_code_md_json() OWNER TO postgres;

--
-- Name: set_statistical_code_type_md_json(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.set_statistical_code_type_md_json() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  updatedDate timestamp;
BEGIN
  if NEW.creation_date IS NULL then
    RETURN NEW;
  end if;

  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(NEW.creation_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  if NEW.created_by IS NULL then
    NEW.jsonb = NEW.jsonb #- '{metadata,createdByUserId}';
  else
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdByUserId}', to_jsonb(NEW.created_by));
  end if;

  input = NEW.jsonb->'metadata'->>'updatedDate';
  if input IS NOT NULL then
    -- time stamp without time zone?
    IF (input::timestamp::timestamptz = input::timestamptz) THEN
      -- updatedDate already has no time zone, normalize using ::timestamp
      updatedDate = input::timestamp;
    ELSE
      -- updatedDate has a time zone string
      -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
      updatedDate = input::timestamptz AT TIME ZONE '+00';
    END IF;
    NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(updatedDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  end if;
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.set_statistical_code_type_md_json() OWNER TO postgres;

--
-- Name: statistical_code_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.statistical_code_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.statistical_code_set_md() OWNER TO postgres;

--
-- Name: statistical_code_type_set_md(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.statistical_code_type_set_md() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  input text;
  createdDate timestamp;
BEGIN
  input = NEW.jsonb->'metadata'->>'createdDate';
  IF input IS NULL THEN
    RETURN NEW;
  END IF;
  -- time stamp without time zone?
  IF (input::timestamp::timestamptz = input::timestamptz) THEN
    -- createdDate already has no time zone, normalize using ::timestamp
    createdDate = input::timestamp;
  ELSE
    -- createdDate has a time zone string
    -- normalize using ::timestamptz, convert to '+00' time zone and remove time zone string
    createdDate = input::timestamptz AT TIME ZONE '+00';
  END IF;
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,createdDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.jsonb = jsonb_set(NEW.jsonb, '{metadata,updatedDate}', to_jsonb(to_char(createdDate, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
  NEW.creation_date = createdDate;
  NEW.created_by = NEW.jsonb->'metadata'->>'createdByUserId';
  RETURN NEW;
END;
$$;


ALTER FUNCTION quesnelia_mod_inventory_storage.statistical_code_type_set_md() OWNER TO postgres;

--
-- Name: strtotimestamp(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.strtotimestamp(text) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT $1::timestamptz
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.strtotimestamp(text) OWNER TO postgres;

--
-- Name: tsquery_and(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.tsquery_and(text) RETURNS tsquery
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT to_tsquery('simple', string_agg(CASE WHEN length(v) = 0 OR v = '*' THEN ''
                                              WHEN right(v, 1) = '*' THEN '''' || left(v, -1) || ''':*'
                                              ELSE '''' || v || '''' END,
                                         '&'))
  FROM (SELECT regexp_split_to_table(translate($1, '&''', ',,'), ' +')) AS x(v);
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.tsquery_and(text) OWNER TO postgres;

--
-- Name: tsquery_or(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.tsquery_or(text) RETURNS tsquery
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT replace(quesnelia_mod_inventory_storage.tsquery_and($1)::text, '&', '|')::tsquery;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.tsquery_or(text) OWNER TO postgres;

--
-- Name: tsquery_phrase(text); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.tsquery_phrase(text) RETURNS tsquery
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$
  SELECT replace(quesnelia_mod_inventory_storage.tsquery_and($1)::text, '&', '<->')::tsquery;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.tsquery_phrase(text) OWNER TO postgres;

--
-- Name: update_bound_with_part_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_bound_with_part_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.itemId = (NEW.jsonb->>'itemId');
      NEW.holdingsRecordId = (NEW.jsonb->>'holdingsRecordId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_bound_with_part_references() OWNER TO postgres;

--
-- Name: update_holdings_record_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_holdings_record_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.instanceId = (NEW.jsonb->>'instanceId');
      NEW.permanentLocationId = (NEW.jsonb->>'permanentLocationId');
      NEW.temporaryLocationId = (NEW.jsonb->>'temporaryLocationId');
      NEW.effectiveLocationId = (NEW.jsonb->>'effectiveLocationId');
      NEW.holdingsTypeId = (NEW.jsonb->>'holdingsTypeId');
      NEW.callNumberTypeId = (NEW.jsonb->>'callNumberTypeId');
      NEW.illPolicyId = (NEW.jsonb->>'illPolicyId');
      NEW.sourceId = (NEW.jsonb->>'sourceId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_holdings_record_references() OWNER TO postgres;

--
-- Name: update_instance_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_instance_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.instanceStatusId = (NEW.jsonb->>'instanceStatusId');
      NEW.modeOfIssuanceId = (NEW.jsonb->>'modeOfIssuanceId');
      NEW.instanceTypeId = (NEW.jsonb->>'instanceTypeId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_instance_references() OWNER TO postgres;

--
-- Name: update_instance_relationship_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_instance_relationship_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.superInstanceId = (NEW.jsonb->>'superInstanceId');
      NEW.subInstanceId = (NEW.jsonb->>'subInstanceId');
      NEW.instanceRelationshipTypeId = (NEW.jsonb->>'instanceRelationshipTypeId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_instance_relationship_references() OWNER TO postgres;

--
-- Name: update_instance_source_marc(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_instance_source_marc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    IF (TG_OP = 'DELETE') THEN
      UPDATE quesnelia_mod_inventory_storage.instance
        SET jsonb = jsonb - 'sourceRecordFormat'
        WHERE id = OLD.id;
    ELSE
      UPDATE quesnelia_mod_inventory_storage.instance
        SET jsonb = jsonb_set(jsonb, '{sourceRecordFormat}', '"MARC-JSON"')
        WHERE id = NEW.id;
    END IF;
    RETURN NULL;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_instance_source_marc() OWNER TO postgres;

--
-- Name: update_item_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_item_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.holdingsRecordId = (NEW.jsonb->>'holdingsRecordId');
      NEW.permanentLoanTypeId = (NEW.jsonb->>'permanentLoanTypeId');
      NEW.temporaryLoanTypeId = (NEW.jsonb->>'temporaryLoanTypeId');
      NEW.materialTypeId = (NEW.jsonb->>'materialTypeId');
      NEW.permanentLocationId = (NEW.jsonb->>'permanentLocationId');
      NEW.temporaryLocationId = (NEW.jsonb->>'temporaryLocationId');
      NEW.effectiveLocationId = (NEW.jsonb->>'effectiveLocationId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_item_references() OWNER TO postgres;

--
-- Name: update_item_status_date(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_item_status_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
	  newStatus text;
  BEGIN
  	newStatus = NEW.jsonb->'status'->>'name';
	  IF (newStatus IS DISTINCT FROM OLD.jsonb->'status'->>'name') THEN
	    -- Date time in "YYYY-MM-DD"T"HH24:MI:SS.ms'Z'" format at UTC (00:00) time zone
      NEW.jsonb = jsonb_set(NEW.jsonb, '{status,date}',
       to_jsonb(to_char(CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.ms"Z"')), true);
    ELSIF (OLD.jsonb->'status'->'date' IS NOT NULL) THEN
      NEW.jsonb = jsonb_set(NEW.jsonb, '{status,date}', OLD.jsonb->'status'->'date', true);
    ELSE
      NEW.jsonb = NEW.jsonb #- '{status, date}';
	  END IF;
	  RETURN NEW;
  END;
  $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_item_status_date() OWNER TO postgres;

--
-- Name: update_location_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_location_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.institutionId = (NEW.jsonb->>'institutionId');
      NEW.campusId = (NEW.jsonb->>'campusId');
      NEW.libraryId = (NEW.jsonb->>'libraryId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_location_references() OWNER TO postgres;

--
-- Name: update_loccampus_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_loccampus_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.institutionId = (NEW.jsonb->>'institutionId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_loccampus_references() OWNER TO postgres;

--
-- Name: update_loclibrary_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_loclibrary_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.campusId = (NEW.jsonb->>'campusId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_loclibrary_references() OWNER TO postgres;

--
-- Name: update_preceding_succeeding_title_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_preceding_succeeding_title_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.precedingInstanceId = (NEW.jsonb->>'precedingInstanceId');
      NEW.succeedingInstanceId = (NEW.jsonb->>'succeedingInstanceId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_preceding_succeeding_title_references() OWNER TO postgres;

--
-- Name: update_service_point_user_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_service_point_user_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.defaultServicePointId = (NEW.jsonb->>'defaultServicePointId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_service_point_user_references() OWNER TO postgres;

--
-- Name: update_statistical_code_references(); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.update_statistical_code_references() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.statisticalCodeTypeId = (NEW.jsonb->>'statisticalCodeTypeId');
      RETURN NEW;
    END;
    $$;


ALTER FUNCTION quesnelia_mod_inventory_storage.update_statistical_code_references() OWNER TO postgres;

--
-- Name: upsert(text, uuid, anyelement); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.upsert(text, uuid, anyelement) RETURNS uuid
    LANGUAGE plpgsql
    AS $_$
DECLARE
  ret uuid;
BEGIN
  EXECUTE format('UPDATE quesnelia_mod_inventory_storage.%I SET jsonb=$3 WHERE id=$2 RETURNING id', $1)
          USING $1, $2, $3 INTO ret;
  IF ret IS NOT NULL THEN
    RETURN ret;
  END IF;
  EXECUTE format('INSERT INTO quesnelia_mod_inventory_storage.%I (id, jsonb) VALUES ($2, $3) RETURNING id', $1)
          USING $1, $2, $3 INTO STRICT ret;
  RETURN ret;
END;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.upsert(text, uuid, anyelement) OWNER TO postgres;

--
-- Name: uuid_larger(uuid, uuid); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.uuid_larger(uuid, uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $_$
BEGIN
  IF $1 IS NULL THEN
    RETURN $2;
  END IF;
  IF $2 IS NULL THEN
    RETURN $1;
  END IF;
  IF $1 > $2 THEN
    RETURN $1;
  ELSE
    RETURN $2;
  END IF;
END;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.uuid_larger(uuid, uuid) OWNER TO postgres;

--
-- Name: uuid_smaller(uuid, uuid); Type: FUNCTION; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE FUNCTION quesnelia_mod_inventory_storage.uuid_smaller(uuid, uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $_$
BEGIN
  IF $1 IS NULL THEN
    RETURN $2;
  END IF;
  IF $2 IS NULL THEN
    RETURN $1;
  END IF;
  IF $1 < $2 THEN
    RETURN $1;
  ELSE
    RETURN $2;
  END IF;
END;
$_$;


ALTER FUNCTION quesnelia_mod_inventory_storage.uuid_smaller(uuid, uuid) OWNER TO postgres;

--
-- Name: max(uuid); Type: AGGREGATE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE AGGREGATE quesnelia_mod_inventory_storage.max(uuid) (
    SFUNC = quesnelia_mod_inventory_storage.uuid_larger,
    STYPE = uuid,
    COMBINEFUNC = quesnelia_mod_inventory_storage.uuid_larger,
    SORTOP = OPERATOR(pg_catalog.>),
    PARALLEL = safe
);


ALTER AGGREGATE quesnelia_mod_inventory_storage.max(uuid) OWNER TO postgres;

--
-- Name: min(uuid); Type: AGGREGATE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE AGGREGATE quesnelia_mod_inventory_storage.min(uuid) (
    SFUNC = quesnelia_mod_inventory_storage.uuid_smaller,
    STYPE = uuid,
    COMBINEFUNC = quesnelia_mod_inventory_storage.uuid_smaller,
    SORTOP = OPERATOR(pg_catalog.<),
    PARALLEL = safe
);


ALTER AGGREGATE quesnelia_mod_inventory_storage.min(uuid) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alternative_title_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.alternative_title_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.alternative_title_type OWNER TO postgres;

--
-- Name: async_migration_job; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.async_migration_job (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.async_migration_job OWNER TO postgres;

--
-- Name: audit_holdings_record; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.audit_holdings_record (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.audit_holdings_record OWNER TO postgres;

--
-- Name: audit_instance; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.audit_instance (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.audit_instance OWNER TO postgres;

--
-- Name: audit_item; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.audit_item (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.audit_item OWNER TO postgres;

--
-- Name: bound_with_part; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.bound_with_part (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    itemid uuid,
    holdingsrecordid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.bound_with_part OWNER TO postgres;

--
-- Name: call_number_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.call_number_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.call_number_type OWNER TO postgres;

--
-- Name: classification_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.classification_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.classification_type OWNER TO postgres;

--
-- Name: contributor_name_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.contributor_name_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.contributor_name_type OWNER TO postgres;

--
-- Name: contributor_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.contributor_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.contributor_type OWNER TO postgres;

--
-- Name: electronic_access_relationship; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.electronic_access_relationship (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.electronic_access_relationship OWNER TO postgres;

--
-- Name: holdings_note_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.holdings_note_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.holdings_note_type OWNER TO postgres;

--
-- Name: holdings_record; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.holdings_record (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    instanceid uuid,
    permanentlocationid uuid,
    temporarylocationid uuid,
    effectivelocationid uuid,
    holdingstypeid uuid,
    callnumbertypeid uuid,
    illpolicyid uuid,
    sourceid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.holdings_record OWNER TO postgres;

--
-- Name: holdings_records_source; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.holdings_records_source (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.holdings_records_source OWNER TO postgres;

--
-- Name: holdings_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.holdings_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.holdings_type OWNER TO postgres;

--
-- Name: hrid_settings; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

CREATE TABLE quesnelia_mod_inventory_storage.hrid_settings (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    lock boolean DEFAULT true,
    CONSTRAINT hrid_settings_lock_check CHECK ((lock = true))
);


ALTER TABLE quesnelia_mod_inventory_storage.hrid_settings OWNER TO quesnelia_mod_inventory_storage;

--
-- Name: hrid_holdings_seq; Type: SEQUENCE; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

CREATE SEQUENCE quesnelia_mod_inventory_storage.hrid_holdings_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 99999999999
    CACHE 1;


ALTER SEQUENCE quesnelia_mod_inventory_storage.hrid_holdings_seq OWNER TO quesnelia_mod_inventory_storage;

--
-- Name: hrid_holdings_seq; Type: SEQUENCE OWNED BY; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

ALTER SEQUENCE quesnelia_mod_inventory_storage.hrid_holdings_seq OWNED BY quesnelia_mod_inventory_storage.hrid_settings.jsonb;


--
-- Name: hrid_instances_seq; Type: SEQUENCE; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

CREATE SEQUENCE quesnelia_mod_inventory_storage.hrid_instances_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 99999999999
    CACHE 1;


ALTER SEQUENCE quesnelia_mod_inventory_storage.hrid_instances_seq OWNER TO quesnelia_mod_inventory_storage;

--
-- Name: hrid_instances_seq; Type: SEQUENCE OWNED BY; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

ALTER SEQUENCE quesnelia_mod_inventory_storage.hrid_instances_seq OWNED BY quesnelia_mod_inventory_storage.hrid_settings.jsonb;


--
-- Name: hrid_items_seq; Type: SEQUENCE; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

CREATE SEQUENCE quesnelia_mod_inventory_storage.hrid_items_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 99999999999
    CACHE 1;


ALTER SEQUENCE quesnelia_mod_inventory_storage.hrid_items_seq OWNER TO quesnelia_mod_inventory_storage;

--
-- Name: hrid_items_seq; Type: SEQUENCE OWNED BY; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

ALTER SEQUENCE quesnelia_mod_inventory_storage.hrid_items_seq OWNED BY quesnelia_mod_inventory_storage.hrid_settings.jsonb;


--
-- Name: hrid_settings_view; Type: VIEW; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE VIEW quesnelia_mod_inventory_storage.hrid_settings_view AS
 SELECT jsonb_set(jsonb_set(jsonb_set(hrid_settings.jsonb, '{instances,currentNumber}'::text[], to_jsonb((hrid_instances_seq.last_value -
        CASE
            WHEN hrid_instances_seq.is_called THEN 0
            ELSE 1
        END))), '{holdings,currentNumber}'::text[], to_jsonb((hrid_holdings_seq.last_value -
        CASE
            WHEN hrid_holdings_seq.is_called THEN 0
            ELSE 1
        END))), '{items,currentNumber}'::text[], to_jsonb((hrid_items_seq.last_value -
        CASE
            WHEN hrid_items_seq.is_called THEN 0
            ELSE 1
        END))) AS jsonb
   FROM quesnelia_mod_inventory_storage.hrid_settings,
    quesnelia_mod_inventory_storage.hrid_instances_seq,
    quesnelia_mod_inventory_storage.hrid_holdings_seq,
    quesnelia_mod_inventory_storage.hrid_items_seq;


ALTER VIEW quesnelia_mod_inventory_storage.hrid_settings_view OWNER TO postgres;

--
-- Name: identifier_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.identifier_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.identifier_type OWNER TO postgres;

--
-- Name: ill_policy; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.ill_policy (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.ill_policy OWNER TO postgres;

--
-- Name: instance; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    instancestatusid uuid,
    modeofissuanceid uuid,
    instancetypeid uuid,
    complete_updated_date timestamp with time zone
);


ALTER TABLE quesnelia_mod_inventory_storage.instance OWNER TO postgres;

--
-- Name: instance_format; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance_format (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.instance_format OWNER TO postgres;

--
-- Name: item; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.item (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    holdingsrecordid uuid,
    permanentloantypeid uuid,
    temporaryloantypeid uuid,
    materialtypeid uuid,
    permanentlocationid uuid,
    temporarylocationid uuid,
    effectivelocationid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.item OWNER TO postgres;

--
-- Name: instance_holdings_item_view; Type: VIEW; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE VIEW quesnelia_mod_inventory_storage.instance_holdings_item_view AS
 SELECT id,
    jsonb_build_object('instanceId', id, 'instance', jsonb, 'holdingsRecords', ( SELECT jsonb_agg(holdings_record.jsonb) AS jsonb_agg
           FROM quesnelia_mod_inventory_storage.holdings_record
          WHERE (holdings_record.instanceid = instance.id)), 'items', ( SELECT jsonb_agg(item.jsonb) AS jsonb_agg
           FROM (quesnelia_mod_inventory_storage.holdings_record hr
             JOIN quesnelia_mod_inventory_storage.item ON (((item.holdingsrecordid = hr.id) AND (hr.instanceid = instance.id))))), 'isBoundWith', ( SELECT (EXISTS ( SELECT 1
                   FROM ((quesnelia_mod_inventory_storage.bound_with_part bw
                     JOIN quesnelia_mod_inventory_storage.item it ON ((it.id = bw.itemid)))
                     JOIN quesnelia_mod_inventory_storage.holdings_record hr ON ((hr.id = bw.holdingsrecordid)))
                  WHERE (hr.instanceid = instance.id)
                 LIMIT 1)) AS "exists")) AS jsonb
   FROM quesnelia_mod_inventory_storage.instance;


ALTER VIEW quesnelia_mod_inventory_storage.instance_holdings_item_view OWNER TO postgres;

--
-- Name: instance_note_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance_note_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.instance_note_type OWNER TO postgres;

--
-- Name: instance_relationship; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance_relationship (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    superinstanceid uuid,
    subinstanceid uuid,
    instancerelationshiptypeid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.instance_relationship OWNER TO postgres;

--
-- Name: instance_relationship_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance_relationship_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.instance_relationship_type OWNER TO postgres;

--
-- Name: preceding_succeeding_title; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.preceding_succeeding_title (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    precedinginstanceid uuid,
    succeedinginstanceid uuid,
    CONSTRAINT preceding_or_succeeding_id_is_set CHECK ((((jsonb -> 'precedingInstanceId'::text) IS NOT NULL) OR ((jsonb -> 'succeedingInstanceId'::text) IS NOT NULL)))
);


ALTER TABLE quesnelia_mod_inventory_storage.preceding_succeeding_title OWNER TO postgres;

--
-- Name: instance_set; Type: VIEW; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE VIEW quesnelia_mod_inventory_storage.instance_set AS
 SELECT id,
    ( SELECT COALESCE(jsonb_agg(holdings_record.jsonb), '[]'::jsonb) AS "coalesce"
           FROM quesnelia_mod_inventory_storage.holdings_record
          WHERE (holdings_record.instanceid = instance.id)) AS holdings_records,
    ( SELECT COALESCE(jsonb_agg(item.jsonb), '[]'::jsonb) AS "coalesce"
           FROM (quesnelia_mod_inventory_storage.holdings_record hr
             JOIN quesnelia_mod_inventory_storage.item ON (((item.holdingsrecordid = hr.id) AND (hr.instanceid = instance.id))))) AS items,
    ( SELECT COALESCE(jsonb_agg(preceding_succeeding_title.jsonb), '[]'::jsonb) AS "coalesce"
           FROM quesnelia_mod_inventory_storage.preceding_succeeding_title
          WHERE (preceding_succeeding_title.succeedinginstanceid = instance.id)) AS preceding_titles,
    ( SELECT COALESCE(jsonb_agg(preceding_succeeding_title.jsonb), '[]'::jsonb) AS "coalesce"
           FROM quesnelia_mod_inventory_storage.preceding_succeeding_title
          WHERE (preceding_succeeding_title.precedinginstanceid = instance.id)) AS succeeding_titles,
    ( SELECT COALESCE(jsonb_agg(instance_relationship.jsonb), '[]'::jsonb) AS "coalesce"
           FROM quesnelia_mod_inventory_storage.instance_relationship
          WHERE (instance_relationship.subinstanceid = instance.id)) AS super_instance_relationships,
    ( SELECT COALESCE(jsonb_agg(instance_relationship.jsonb), '[]'::jsonb) AS "coalesce"
           FROM quesnelia_mod_inventory_storage.instance_relationship
          WHERE (instance_relationship.superinstanceid = instance.id)) AS sub_instance_relationships
   FROM quesnelia_mod_inventory_storage.instance;


ALTER VIEW quesnelia_mod_inventory_storage.instance_set OWNER TO postgres;

--
-- Name: instance_source_marc; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance_source_marc (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.instance_source_marc OWNER TO postgres;

--
-- Name: instance_status; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance_status (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.instance_status OWNER TO postgres;

--
-- Name: instance_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.instance_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.instance_type OWNER TO postgres;

--
-- Name: item_damaged_status; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.item_damaged_status (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.item_damaged_status OWNER TO postgres;

--
-- Name: item_note_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.item_note_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.item_note_type OWNER TO postgres;

--
-- Name: iteration_job; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.iteration_job (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.iteration_job OWNER TO postgres;

--
-- Name: loan_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.loan_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.loan_type OWNER TO postgres;

--
-- Name: location; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.location (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    institutionid uuid,
    campusid uuid,
    libraryid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.location OWNER TO postgres;

--
-- Name: loccampus; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.loccampus (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    institutionid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.loccampus OWNER TO postgres;

--
-- Name: locinstitution; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.locinstitution (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.locinstitution OWNER TO postgres;

--
-- Name: loclibrary; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.loclibrary (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    campusid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.loclibrary OWNER TO postgres;

--
-- Name: material_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.material_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.material_type OWNER TO postgres;

--
-- Name: mode_of_issuance; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.mode_of_issuance (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.mode_of_issuance OWNER TO postgres;

--
-- Name: nature_of_content_term; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.nature_of_content_term (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.nature_of_content_term OWNER TO postgres;

--
-- Name: notification_sending_error; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.notification_sending_error (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.notification_sending_error OWNER TO postgres;

--
-- Name: reindex_job; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.reindex_job (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.reindex_job OWNER TO postgres;

--
-- Name: related_instance_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.related_instance_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.related_instance_type OWNER TO postgres;

--
-- Name: rmb_internal; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.rmb_internal (
    id integer NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.rmb_internal OWNER TO postgres;

--
-- Name: rmb_internal_analyze; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.rmb_internal_analyze (
    tablename text
);


ALTER TABLE quesnelia_mod_inventory_storage.rmb_internal_analyze OWNER TO postgres;

--
-- Name: rmb_internal_id_seq; Type: SEQUENCE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE SEQUENCE quesnelia_mod_inventory_storage.rmb_internal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE quesnelia_mod_inventory_storage.rmb_internal_id_seq OWNER TO postgres;

--
-- Name: rmb_internal_id_seq; Type: SEQUENCE OWNED BY; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER SEQUENCE quesnelia_mod_inventory_storage.rmb_internal_id_seq OWNED BY quesnelia_mod_inventory_storage.rmb_internal.id;


--
-- Name: rmb_internal_index; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.rmb_internal_index (
    name text NOT NULL,
    def text NOT NULL,
    remove boolean NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.rmb_internal_index OWNER TO postgres;

--
-- Name: rmb_job; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.rmb_job (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL
);


ALTER TABLE quesnelia_mod_inventory_storage.rmb_job OWNER TO postgres;

--
-- Name: service_point; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.service_point (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.service_point OWNER TO postgres;

--
-- Name: service_point_user; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.service_point_user (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    defaultservicepointid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.service_point_user OWNER TO postgres;

--
-- Name: statistical_code; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.statistical_code (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text,
    statisticalcodetypeid uuid
);


ALTER TABLE quesnelia_mod_inventory_storage.statistical_code OWNER TO postgres;

--
-- Name: statistical_code_type; Type: TABLE; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TABLE quesnelia_mod_inventory_storage.statistical_code_type (
    id uuid NOT NULL,
    jsonb jsonb NOT NULL,
    creation_date timestamp without time zone,
    created_by text
);


ALTER TABLE quesnelia_mod_inventory_storage.statistical_code_type OWNER TO postgres;

--
-- Name: rmb_internal id; Type: DEFAULT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.rmb_internal ALTER COLUMN id SET DEFAULT nextval('quesnelia_mod_inventory_storage.rmb_internal_id_seq'::regclass);


--
-- Data for Name: alternative_title_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.alternative_title_type (id, jsonb, creation_date, created_by) FROM stdin;
0fe58901-183e-4678-a3aa-0b4751174ba8	{"id": "0fe58901-183e-4678-a3aa-0b4751174ba8", "name": "No type specified", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.149Z", "updatedDate": "2025-05-16T18:12:35.149Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.149	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
35bbe7f2-1a49-11ed-861d-0242ac120002	{"id": "35bbe7f2-1a49-11ed-861d-0242ac120002", "name": "Variant title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.151Z", "updatedDate": "2025-05-16T18:12:35.151Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.151	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
a8b45056-2223-43ca-8514-4dd88ece984b	{"id": "a8b45056-2223-43ca-8514-4dd88ece984b", "name": "Portion of title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.164Z", "updatedDate": "2025-05-16T18:12:35.164Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.164	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
30512027-cdc9-4c79-af75-1565b3bd888d	{"id": "30512027-cdc9-4c79-af75-1565b3bd888d", "name": "Uniform title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.163Z", "updatedDate": "2025-05-16T18:12:35.163Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.163	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
4bb300a4-04c9-414b-bfbc-9c032f74b7b2	{"id": "4bb300a4-04c9-414b-bfbc-9c032f74b7b2", "name": "Parallel title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.163Z", "updatedDate": "2025-05-16T18:12:35.163Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.163	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
781c04a4-f41e-4ab0-9118-6836e93de3c8	{"id": "781c04a4-f41e-4ab0-9118-6836e93de3c8", "name": "Distinctive title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.167Z", "updatedDate": "2025-05-16T18:12:35.167Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.167	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2ca8538d-a2fd-4e60-b967-1cb220101e22	{"id": "2ca8538d-a2fd-4e60-b967-1cb220101e22", "name": "Added title page title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.169Z", "updatedDate": "2025-05-16T18:12:35.169Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.169	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
09964ad1-7aed-49b8-8223-a4c105e3ef87	{"id": "09964ad1-7aed-49b8-8223-a4c105e3ef87", "name": "Running title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.174Z", "updatedDate": "2025-05-16T18:12:35.174Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.174	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5c364ce4-c8fd-4891-a28d-bb91c9bcdbfb	{"id": "5c364ce4-c8fd-4891-a28d-bb91c9bcdbfb", "name": "Cover title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.177Z", "updatedDate": "2025-05-16T18:12:35.177Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.177	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
dae08d04-8c4e-4ab2-b6bb-99edbf252231	{"id": "dae08d04-8c4e-4ab2-b6bb-99edbf252231", "name": "Spine title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.177Z", "updatedDate": "2025-05-16T18:12:35.177Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.177	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
ab26d2e4-1a4a-11ed-861d-0242ac120002	{"id": "ab26d2e4-1a4a-11ed-861d-0242ac120002", "name": "Former title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.180Z", "updatedDate": "2025-05-16T18:12:35.180Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.18	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2584943f-36ad-4037-a7fa-3bdebb09f452	{"id": "2584943f-36ad-4037-a7fa-3bdebb09f452", "name": "Other title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.182Z", "updatedDate": "2025-05-16T18:12:35.182Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.182	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
432ca81a-fe4d-4249-bfd3-53388725647d	{"id": "432ca81a-fe4d-4249-bfd3-53388725647d", "name": "Caption title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.183Z", "updatedDate": "2025-05-16T18:12:35.183Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.183	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: async_migration_job; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.async_migration_job (id, jsonb) FROM stdin;
\.


--
-- Data for Name: audit_holdings_record; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.audit_holdings_record (id, jsonb) FROM stdin;
\.


--
-- Data for Name: audit_instance; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.audit_instance (id, jsonb) FROM stdin;
\.


--
-- Data for Name: audit_item; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.audit_item (id, jsonb) FROM stdin;
\.


--
-- Data for Name: bound_with_part; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.bound_with_part (id, jsonb, creation_date, created_by, itemid, holdingsrecordid) FROM stdin;
476a9ce4-72c9-4854-b2b8-8baf949a8db6	{"id": "476a9ce4-72c9-4854-b2b8-8baf949a8db6", "itemId": "f4b8c3d1-f461-4551-aa7b-5f45e64f236c", "metadata": {"createdDate": "2025-05-16T18:12:36.799Z", "updatedDate": "2025-05-16T18:12:36.799Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "704ea4ec-456c-4740-852b-0814d59f7d21"}	2025-05-16 18:12:36.799	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	f4b8c3d1-f461-4551-aa7b-5f45e64f236c	704ea4ec-456c-4740-852b-0814d59f7d21
831b1e02-8828-470d-bd80-60d48828ca2c	{"id": "831b1e02-8828-470d-bd80-60d48828ca2c", "itemId": "f4b8c3d1-f461-4551-aa7b-5f45e64f236c", "metadata": {"createdDate": "2025-05-16T18:12:36.796Z", "updatedDate": "2025-05-16T18:12:36.796Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "9e8dc8ce-68f3-4e75-8479-d548ce521157"}	2025-05-16 18:12:36.796	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	f4b8c3d1-f461-4551-aa7b-5f45e64f236c	9e8dc8ce-68f3-4e75-8479-d548ce521157
ab048eb7-179e-441f-8403-fcb2094eb329	{"id": "ab048eb7-179e-441f-8403-fcb2094eb329", "itemId": "f4b8c3d1-f461-4551-aa7b-5f45e64f236c", "metadata": {"createdDate": "2025-05-16T18:12:36.798Z", "updatedDate": "2025-05-16T18:12:36.798Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "247f1832-88be-4a84-9638-605ffde308b3"}	2025-05-16 18:12:36.798	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	f4b8c3d1-f461-4551-aa7b-5f45e64f236c	247f1832-88be-4a84-9638-605ffde308b3
de88cd2f-a515-41b5-b259-4373682a180b	{"id": "de88cd2f-a515-41b5-b259-4373682a180b", "itemId": "917e044f-173c-4445-8293-45a78ef49ace", "metadata": {"createdDate": "2025-05-16T18:12:36.977Z", "updatedDate": "2025-05-16T18:12:36.977Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "7a2443bc-fe66-40d5-9400-9a800fdf013e"}	2025-05-16 18:12:36.977	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	917e044f-173c-4445-8293-45a78ef49ace	7a2443bc-fe66-40d5-9400-9a800fdf013e
98a0fceb-82d8-4939-ab15-5b21509563f6	{"id": "98a0fceb-82d8-4939-ab15-5b21509563f6", "itemId": "56780446-1735-4514-a933-06abe668610b", "metadata": {"createdDate": "2025-05-16T18:12:36.978Z", "updatedDate": "2025-05-16T18:12:36.978Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "7fd55f10-6aec-4e25-a3cd-9ac7412ca26a"}	2025-05-16 18:12:36.978	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	56780446-1735-4514-a933-06abe668610b	7fd55f10-6aec-4e25-a3cd-9ac7412ca26a
1ab08b5d-a021-458b-932e-e4ab5d26045c	{"id": "1ab08b5d-a021-458b-932e-e4ab5d26045c", "itemId": "917e044f-173c-4445-8293-45a78ef49ace", "metadata": {"createdDate": "2025-05-16T18:12:36.979Z", "updatedDate": "2025-05-16T18:12:36.979Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "1ab1f67e-6ab8-40f0-8cc1-a199db309070"}	2025-05-16 18:12:36.979	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	917e044f-173c-4445-8293-45a78ef49ace	1ab1f67e-6ab8-40f0-8cc1-a199db309070
33002b09-2bed-41bc-9b70-fd4626f4ef25	{"id": "33002b09-2bed-41bc-9b70-fd4626f4ef25", "itemId": "56780446-1735-4514-a933-06abe668610b", "metadata": {"createdDate": "2025-05-16T18:12:36.983Z", "updatedDate": "2025-05-16T18:12:36.983Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "7af9a14d-6e92-4827-acab-eba65e08be6c"}	2025-05-16 18:12:36.983	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	56780446-1735-4514-a933-06abe668610b	7af9a14d-6e92-4827-acab-eba65e08be6c
e8a5468f-a853-4358-bfb4-1ec56795cba8	{"id": "e8a5468f-a853-4358-bfb4-1ec56795cba8", "itemId": "917e044f-173c-4445-8293-45a78ef49ace", "metadata": {"createdDate": "2025-05-16T18:12:36.985Z", "updatedDate": "2025-05-16T18:12:36.985Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "7fd55f10-6aec-4e25-a3cd-9ac7412ca26a"}	2025-05-16 18:12:36.985	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	917e044f-173c-4445-8293-45a78ef49ace	7fd55f10-6aec-4e25-a3cd-9ac7412ca26a
a246a5c6-b7f4-44d3-ad98-94c61af2bea7	{"id": "a246a5c6-b7f4-44d3-ad98-94c61af2bea7", "itemId": "917e044f-173c-4445-8293-45a78ef49ace", "metadata": {"createdDate": "2025-05-16T18:12:37.001Z", "updatedDate": "2025-05-16T18:12:37.001Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "7af9a14d-6e92-4827-acab-eba65e08be6c"}	2025-05-16 18:12:37.001	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	917e044f-173c-4445-8293-45a78ef49ace	7af9a14d-6e92-4827-acab-eba65e08be6c
4fbd003f-9dc7-4a76-83af-7bc61b7f25f3	{"id": "4fbd003f-9dc7-4a76-83af-7bc61b7f25f3", "itemId": "56780446-1735-4514-a933-06abe668610b", "metadata": {"createdDate": "2025-05-16T18:12:37.007Z", "updatedDate": "2025-05-16T18:12:37.007Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "holdingsRecordId": "7a2443bc-fe66-40d5-9400-9a800fdf013e"}	2025-05-16 18:12:37.007	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	56780446-1735-4514-a933-06abe668610b	7a2443bc-fe66-40d5-9400-9a800fdf013e
\.


--
-- Data for Name: call_number_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.call_number_type (id, jsonb, creation_date, created_by) FROM stdin;
d644be8f-deb5-4c4d-8c9e-2291b7c0f46f	{"id": "d644be8f-deb5-4c4d-8c9e-2291b7c0f46f", "name": "UDC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.698Z", "updatedDate": "2025-05-16T18:12:35.698Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.698	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
03dd64d0-5626-4ecd-8ece-4531e0069f35	{"id": "03dd64d0-5626-4ecd-8ece-4531e0069f35", "name": "Dewey Decimal classification", "source": "system", "metadata": {"createdDate": "2025-05-16T18:12:35.699Z", "updatedDate": "2025-05-16T18:12:35.699Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.699	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
95467209-6d7b-468b-94df-0f5d7ad2747d	{"id": "95467209-6d7b-468b-94df-0f5d7ad2747d", "name": "Library of Congress classification", "source": "system", "metadata": {"createdDate": "2025-05-16T18:12:35.694Z", "updatedDate": "2025-05-16T18:12:35.694Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.694	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
054d460d-d6b9-4469-9e37-7a78a2266655	{"id": "054d460d-d6b9-4469-9e37-7a78a2266655", "name": "National Library of Medicine classification", "source": "system", "metadata": {"createdDate": "2025-05-16T18:12:35.698Z", "updatedDate": "2025-05-16T18:12:35.698Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.698	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
827a2b64-cbf5-4296-8545-130876e4dfc0	{"id": "827a2b64-cbf5-4296-8545-130876e4dfc0", "name": "Source specified in subfield $2", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.701Z", "updatedDate": "2025-05-16T18:12:35.701Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.701	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
6caca63e-5651-4db6-9247-3205156e9699	{"id": "6caca63e-5651-4db6-9247-3205156e9699", "name": "Other scheme", "source": "system", "metadata": {"createdDate": "2025-05-16T18:12:35.722Z", "updatedDate": "2025-05-16T18:12:35.722Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.722	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5ba6b62e-6858-490a-8102-5b1369873835	{"id": "5ba6b62e-6858-490a-8102-5b1369873835", "name": "Title", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.713Z", "updatedDate": "2025-05-16T18:12:35.713Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.713	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
28927d76-e097-4f63-8510-e56f2b7a3ad0	{"id": "28927d76-e097-4f63-8510-e56f2b7a3ad0", "name": "Shelving control number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.714Z", "updatedDate": "2025-05-16T18:12:35.714Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.714	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
cd70562c-dd0b-42f6-aa80-ce803d24d4a1	{"id": "cd70562c-dd0b-42f6-aa80-ce803d24d4a1", "name": "Shelved separately", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.721Z", "updatedDate": "2025-05-16T18:12:35.721Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.721	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
828ae637-dfa3-4265-a1af-5279c436edff	{"id": "828ae637-dfa3-4265-a1af-5279c436edff", "name": "MOYS", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.723Z", "updatedDate": "2025-05-16T18:12:35.723Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.723	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
fc388041-6cd0-4806-8a74-ebe3b9ab4c6e	{"id": "fc388041-6cd0-4806-8a74-ebe3b9ab4c6e", "name": "Superintendent of Documents classification", "source": "system", "metadata": {"createdDate": "2025-05-16T18:12:35.731Z", "updatedDate": "2025-05-16T18:12:35.731Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.731	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
512173a7-bd09-490e-b773-17d83f2b63fe	{"id": "512173a7-bd09-490e-b773-17d83f2b63fe", "name": "LC Modified", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.732Z", "updatedDate": "2025-05-16T18:12:35.732Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.732	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: classification_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.classification_type (id, jsonb, creation_date, created_by) FROM stdin;
a7f4d03f-b0d8-496c-aebf-4e9cdb678200	{"id": "a7f4d03f-b0d8-496c-aebf-4e9cdb678200", "name": "NLM", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.751Z", "updatedDate": "2025-05-16T18:12:34.751Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.751	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
e8662436-75a8-4984-bebc-531e38c774a0	{"id": "e8662436-75a8-4984-bebc-531e38c774a0", "name": "UDC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.756Z", "updatedDate": "2025-05-16T18:12:34.756Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.756	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
ad615f6e-e28c-4343-b4a0-457397c5be3e	{"id": "ad615f6e-e28c-4343-b4a0-457397c5be3e", "name": "Canadian Classification", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.758Z", "updatedDate": "2025-05-16T18:12:34.758Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.758	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
74c08086-81a4-4466-93d8-d117ce8646db	{"id": "74c08086-81a4-4466-93d8-d117ce8646db", "name": "Additional Dewey", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.757Z", "updatedDate": "2025-05-16T18:12:34.757Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.757	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
42471af9-7d25-4f3a-bf78-60d29dcf463b	{"id": "42471af9-7d25-4f3a-bf78-60d29dcf463b", "name": "Dewey", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.762Z", "updatedDate": "2025-05-16T18:12:34.762Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.762	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
ce176ace-a53e-4b4d-aa89-725ed7b2edac	{"id": "ce176ace-a53e-4b4d-aa89-725ed7b2edac", "name": "LC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.815Z", "updatedDate": "2025-05-16T18:12:34.815Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.815	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
a83699eb-cc23-4307-8043-5a38a8dce335	{"id": "a83699eb-cc23-4307-8043-5a38a8dce335", "name": "LC (local)", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.818Z", "updatedDate": "2025-05-16T18:12:34.818Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.818	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9075b5f8-7d97-49e1-a431-73fdd468d476	{"id": "9075b5f8-7d97-49e1-a431-73fdd468d476", "name": "SUDOC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.819Z", "updatedDate": "2025-05-16T18:12:34.819Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.819	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9a60012a-0fcf-4da9-a1d1-148e818c27ad	{"id": "9a60012a-0fcf-4da9-a1d1-148e818c27ad", "name": "National Agricultural Library", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.824Z", "updatedDate": "2025-05-16T18:12:34.824Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.824	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
fb12264c-ff3b-47e0-8e09-b0aa074361f1	{"id": "fb12264c-ff3b-47e0-8e09-b0aa074361f1", "name": "GDC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.820Z", "updatedDate": "2025-05-16T18:12:34.820Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.82	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: contributor_name_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.contributor_name_type (id, jsonb, creation_date, created_by) FROM stdin;
e8b311a6-3b21-43f2-a269-dd9310cb2d0a	{"id": "e8b311a6-3b21-43f2-a269-dd9310cb2d0a", "name": "Meeting name", "metadata": {"createdDate": "2025-05-16T18:12:34.138Z", "updatedDate": "2025-05-16T18:12:34.138Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "ordering": "3"}	2025-05-16 18:12:34.138	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2e48e713-17f3-4c13-a9f8-23845bb210aa	{"id": "2e48e713-17f3-4c13-a9f8-23845bb210aa", "name": "Corporate name", "metadata": {"createdDate": "2025-05-16T18:12:34.139Z", "updatedDate": "2025-05-16T18:12:34.139Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "ordering": "2"}	2025-05-16 18:12:34.139	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2b94c631-fca9-4892-a730-03ee529ffe2a	{"id": "2b94c631-fca9-4892-a730-03ee529ffe2a", "name": "Personal name", "metadata": {"createdDate": "2025-05-16T18:12:34.134Z", "updatedDate": "2025-05-16T18:12:34.134Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "ordering": "1"}	2025-05-16 18:12:34.134	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: contributor_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.contributor_type (id, jsonb) FROM stdin;
6901fbf1-c038-42eb-a03e-cd65bf91f660	{"id": "6901fbf1-c038-42eb-a03e-cd65bf91f660", "code": "dgg", "name": "Degree granting institution", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.284+00:00", "updatedDate": "2025-05-16T18:12:33.284+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
45747710-39dc-47ec-b2b3-024d757f997e	{"id": "45747710-39dc-47ec-b2b3-024d757f997e", "code": "pte", "name": "Plaintiff-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.285+00:00", "updatedDate": "2025-05-16T18:12:33.285+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
81c01802-f61b-4548-954a-22aab027f6e5	{"id": "81c01802-f61b-4548-954a-22aab027f6e5", "code": "clr", "name": "Colorist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.291+00:00", "updatedDate": "2025-05-16T18:12:33.291+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0efdaf72-6126-430a-8256-69c42ff6866f	{"id": "0efdaf72-6126-430a-8256-69c42ff6866f", "code": "tcd", "name": "Technical director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.295+00:00", "updatedDate": "2025-05-16T18:12:33.295+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
21dda3dc-cebd-4018-8db2-4f6d50ce3d02	{"id": "21dda3dc-cebd-4018-8db2-4f6d50ce3d02", "code": "own", "name": "Owner", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.302+00:00", "updatedDate": "2025-05-16T18:12:33.302+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
846ac49c-749d-49fd-a05f-e7f2885d9eaf	{"id": "846ac49c-749d-49fd-a05f-e7f2885d9eaf", "code": "bkd", "name": "Book designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.308+00:00", "updatedDate": "2025-05-16T18:12:33.308+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5d92d9de-adf3-4dea-93b5-580e9a88e696	{"id": "5d92d9de-adf3-4dea-93b5-580e9a88e696", "code": "cpc", "name": "Copyright claimant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.306+00:00", "updatedDate": "2025-05-16T18:12:33.306+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
369783f6-78c8-4cd7-97ab-5029444e0c85	{"id": "369783f6-78c8-4cd7-97ab-5029444e0c85", "code": "gis", "name": "Geographic information specialist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.309+00:00", "updatedDate": "2025-05-16T18:12:33.309+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
86890f8f-2273-44e2-aa86-927c7f649b32	{"id": "86890f8f-2273-44e2-aa86-927c7f649b32", "code": "cpt", "name": "Complainant-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.315+00:00", "updatedDate": "2025-05-16T18:12:33.315+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
863e41e3-b9c5-44fb-abeb-a8ab536bb432	{"id": "863e41e3-b9c5-44fb-abeb-a8ab536bb432", "code": "edc", "name": "Editor of compilation", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.318+00:00", "updatedDate": "2025-05-16T18:12:33.318+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
4f7c335d-a9d9-4f38-87ef-9a5846b63e7f	{"id": "4f7c335d-a9d9-4f38-87ef-9a5846b63e7f", "code": "ppt", "name": "Puppeteer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.319+00:00", "updatedDate": "2025-05-16T18:12:33.319+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9deb29d1-3e71-4951-9413-a80adac703d0	{"id": "9deb29d1-3e71-4951-9413-a80adac703d0", "code": "edt", "name": "Editor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.326+00:00", "updatedDate": "2025-05-16T18:12:33.326+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7d60c4bf-5ddc-483a-b179-af6f1a76efbe	{"id": "7d60c4bf-5ddc-483a-b179-af6f1a76efbe", "code": "lie", "name": "Libelant-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.323+00:00", "updatedDate": "2025-05-16T18:12:33.323+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
af9a58fa-95df-4139-a06d-ecdab0b2317e	{"id": "af9a58fa-95df-4139-a06d-ecdab0b2317e", "code": "egr", "name": "Engraver", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.331+00:00", "updatedDate": "2025-05-16T18:12:33.331+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
18ba15a9-0502-4fa2-ad41-daab9d5ab7bb	{"id": "18ba15a9-0502-4fa2-ad41-daab9d5ab7bb", "code": "itr", "name": "Instrumentalist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.334+00:00", "updatedDate": "2025-05-16T18:12:33.334+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5c132335-8ad0-47bf-a4d1-6dda0a3a2654	{"id": "5c132335-8ad0-47bf-a4d1-6dda0a3a2654", "code": "auc", "name": "Auctioneer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.336+00:00", "updatedDate": "2025-05-16T18:12:33.336+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5c3abceb-6bd8-43aa-b08d-1187ae78b15b	{"id": "5c3abceb-6bd8-43aa-b08d-1187ae78b15b", "code": "fmo", "name": "Former owner", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.339+00:00", "updatedDate": "2025-05-16T18:12:33.339+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
06fef928-bd00-4c7f-bd3c-5bc93973f8e8	{"id": "06fef928-bd00-4c7f-bd3c-5bc93973f8e8", "code": "frg", "name": "Forger", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.343+00:00", "updatedDate": "2025-05-16T18:12:33.343+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
55e4a59b-2dfd-478d-9fe9-110fc24f0752	{"id": "55e4a59b-2dfd-478d-9fe9-110fc24f0752", "code": "brd", "name": "Broadcaster", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.349+00:00", "updatedDate": "2025-05-16T18:12:33.349+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6d5779a3-e692-4a24-a5ee-d1ce8a6eae47	{"id": "6d5779a3-e692-4a24-a5ee-d1ce8a6eae47", "code": "lbt", "name": "Librettist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.353+00:00", "updatedDate": "2025-05-16T18:12:33.353+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f90c67e8-d1fa-4fe9-b98b-cbc3f019c65f	{"id": "f90c67e8-d1fa-4fe9-b98b-cbc3f019c65f", "code": "bnd", "name": "Binder", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.349+00:00", "updatedDate": "2025-05-16T18:12:33.349+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
94d131ef-2814-49a0-a59c-49b6e7584b3d	{"id": "94d131ef-2814-49a0-a59c-49b6e7584b3d", "code": "stn", "name": "Standards body", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.365+00:00", "updatedDate": "2025-05-16T18:12:33.365+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
cb8fdd3f-7193-4096-934c-3efea46b1138	{"id": "cb8fdd3f-7193-4096-934c-3efea46b1138", "code": "wal", "name": "Writer of added lyrics", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.379+00:00", "updatedDate": "2025-05-16T18:12:33.379+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
097adac4-6576-4152-ace8-08fc59cb0218	{"id": "097adac4-6576-4152-ace8-08fc59cb0218", "code": "pdr", "name": "Project director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.390+00:00", "updatedDate": "2025-05-16T18:12:33.390+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
cd06cefa-acfe-48cb-a5a3-4c48be4a79ad	{"id": "cd06cefa-acfe-48cb-a5a3-4c48be4a79ad", "code": "rpy", "name": "Responsible party", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.401+00:00", "updatedDate": "2025-05-16T18:12:33.401+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fec9ae68-6b55-4dd6-9637-3a694fb6a82b	{"id": "fec9ae68-6b55-4dd6-9637-3a694fb6a82b", "code": "uvp", "name": "University place", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.419+00:00", "updatedDate": "2025-05-16T18:12:33.419+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9e99e803-c73d-4250-8605-403be57f83f9	{"id": "9e99e803-c73d-4250-8605-403be57f83f9", "code": "bpd", "name": "Bookplate designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.437+00:00", "updatedDate": "2025-05-16T18:12:33.437+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
756fcbfc-ef95-4bd0-99cc-1cc364c7b0cd	{"id": "756fcbfc-ef95-4bd0-99cc-1cc364c7b0cd", "code": "cns", "name": "Censor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.452+00:00", "updatedDate": "2025-05-16T18:12:33.452+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9f0a2cf0-7a9b-45a2-a403-f68d2850d07c	{"id": "9f0a2cf0-7a9b-45a2-a403-f68d2850d07c", "code": "ctb", "name": "Contributor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.464+00:00", "updatedDate": "2025-05-16T18:12:33.464+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2b45c004-805d-4e7f-864d-8664a23488dc	{"id": "2b45c004-805d-4e7f-864d-8664a23488dc", "code": "ltg", "name": "Lithographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.477+00:00", "updatedDate": "2025-05-16T18:12:33.477+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
206246b1-8e17-4588-bad8-78c82e3e6d54	{"id": "206246b1-8e17-4588-bad8-78c82e3e6d54", "code": "sht", "name": "Supporting host", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.493+00:00", "updatedDate": "2025-05-16T18:12:33.493+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
06b2cbd8-66bf-4956-9d90-97c9776365a4	{"id": "06b2cbd8-66bf-4956-9d90-97c9776365a4", "code": "ann", "name": "Annotator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.509+00:00", "updatedDate": "2025-05-16T18:12:33.509+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
22f8ea20-b4f0-4498-8125-7962f0037c2d	{"id": "22f8ea20-b4f0-4498-8125-7962f0037c2d", "code": "flm", "name": "Film editor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.518+00:00", "updatedDate": "2025-05-16T18:12:33.518+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e8b5040d-a5c7-47c1-96ca-6313c8b9c849	{"id": "e8b5040d-a5c7-47c1-96ca-6313c8b9c849", "code": "ato", "name": "Autographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.526+00:00", "updatedDate": "2025-05-16T18:12:33.526+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
57247637-c41b-498d-9c46-935469335485	{"id": "57247637-c41b-498d-9c46-935469335485", "code": "aqt", "name": "Author in quotations or text abstracts", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.536+00:00", "updatedDate": "2025-05-16T18:12:33.536+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3e86cb67-5407-4622-a540-71a978899404	{"id": "3e86cb67-5407-4622-a540-71a978899404", "code": "stg", "name": "Setting", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.545+00:00", "updatedDate": "2025-05-16T18:12:33.545+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d669122b-c021-46f5-a911-1e9df10b6542	{"id": "d669122b-c021-46f5-a911-1e9df10b6542", "code": "mfr", "name": "Manufacturer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.554+00:00", "updatedDate": "2025-05-16T18:12:33.554+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
630142eb-6b68-4cf7-8296-bdaba03b5760	{"id": "630142eb-6b68-4cf7-8296-bdaba03b5760", "code": "pta", "name": "Patent applicant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.566+00:00", "updatedDate": "2025-05-16T18:12:33.566+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
33aa4117-95d1-4eb5-986b-dfba809871f6	{"id": "33aa4117-95d1-4eb5-986b-dfba809871f6", "code": "drm", "name": "Draftsman", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.575+00:00", "updatedDate": "2025-05-16T18:12:33.575+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a60314d4-c3c6-4e29-92fa-86cc6ace4d56	{"id": "a60314d4-c3c6-4e29-92fa-86cc6ace4d56", "code": "pbl", "name": "Publisher", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.589+00:00", "updatedDate": "2025-05-16T18:12:33.589+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9593efce-a42d-4991-9aad-3a4dc07abb1e	{"id": "9593efce-a42d-4991-9aad-3a4dc07abb1e", "code": "asn", "name": "Associated name", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.354+00:00", "updatedDate": "2025-05-16T18:12:33.354+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6e09d47d-95e2-4d8a-831b-f777b8ef6d81	{"id": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "code": "aut", "name": "Author", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.368+00:00", "updatedDate": "2025-05-16T18:12:33.368+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5f27fcc6-4134-4916-afb8-fcbcfb6793d4	{"id": "5f27fcc6-4134-4916-afb8-fcbcfb6793d4", "code": "bdd", "name": "Binding designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.406+00:00", "updatedDate": "2025-05-16T18:12:33.406+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
32021771-311e-497b-9bf2-672492f322c7	{"id": "32021771-311e-497b-9bf2-672492f322c7", "code": "wdc", "name": "Woodcutter", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.423+00:00", "updatedDate": "2025-05-16T18:12:33.423+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
58461dca-efd4-4fd4-b380-d033e3540be5	{"id": "58461dca-efd4-4fd4-b380-d033e3540be5", "code": "tyg", "name": "Typographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.439+00:00", "updatedDate": "2025-05-16T18:12:33.439+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3add6049-0b63-4fec-9892-e3867e7358e2	{"id": "3add6049-0b63-4fec-9892-e3867e7358e2", "code": "ill", "name": "Illustrator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.468+00:00", "updatedDate": "2025-05-16T18:12:33.468+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
cbceda25-1f4d-43b7-96a5-f2911026a154	{"id": "cbceda25-1f4d-43b7-96a5-f2911026a154", "code": "clt", "name": "Collotyper", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.480+00:00", "updatedDate": "2025-05-16T18:12:33.480+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7d0a897c-4f83-493a-a0c5-5e040cdce75b	{"id": "7d0a897c-4f83-493a-a0c5-5e040cdce75b", "code": "apl", "name": "Appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.496+00:00", "updatedDate": "2025-05-16T18:12:33.496+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2129a478-c55c-4f71-9cd1-584cbbb381d4	{"id": "2129a478-c55c-4f71-9cd1-584cbbb381d4", "code": "fmk", "name": "Filmmaker", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.576+00:00", "updatedDate": "2025-05-16T18:12:33.576+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c0c46b4f-fd18-4d8a-96ac-aff91662206c	{"id": "c0c46b4f-fd18-4d8a-96ac-aff91662206c", "code": "sgd", "name": "Stage director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.592+00:00", "updatedDate": "2025-05-16T18:12:33.592+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5aa6e3d1-283c-4f6d-8694-3bdc52137b07	{"id": "5aa6e3d1-283c-4f6d-8694-3bdc52137b07", "code": "cos", "name": "Contestant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.604+00:00", "updatedDate": "2025-05-16T18:12:33.604+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3555bf7f-a6cc-4890-b050-9c428eabf579	{"id": "3555bf7f-a6cc-4890-b050-9c428eabf579", "code": "fnd", "name": "Funder", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.616+00:00", "updatedDate": "2025-05-16T18:12:33.616+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0d8dc4be-e87b-43df-90d4-1ed60c4e08c5	{"id": "0d8dc4be-e87b-43df-90d4-1ed60c4e08c5", "code": "dte", "name": "Dedicatee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.629+00:00", "updatedDate": "2025-05-16T18:12:33.629+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c7345998-fd17-406b-bce0-e08cb7b2671f	{"id": "c7345998-fd17-406b-bce0-e08cb7b2671f", "code": "cmt", "name": "Compositor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.644+00:00", "updatedDate": "2025-05-16T18:12:33.644+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
85962960-ef07-499d-bf49-63f137204f9a	{"id": "85962960-ef07-499d-bf49-63f137204f9a", "code": "rev", "name": "Reviewer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.664+00:00", "updatedDate": "2025-05-16T18:12:33.664+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7b21bffb-91e1-45bf-980a-40dd89cc26e4	{"id": "7b21bffb-91e1-45bf-980a-40dd89cc26e4", "code": "dst", "name": "Distributor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.677+00:00", "updatedDate": "2025-05-16T18:12:33.677+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a2c9e8b5-edb4-49dc-98ba-27f0b8b5cebf	{"id": "a2c9e8b5-edb4-49dc-98ba-27f0b8b5cebf", "code": "tyd", "name": "Type designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.690+00:00", "updatedDate": "2025-05-16T18:12:33.690+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
4b41e752-3646-4097-ae80-21fd02e913f7	{"id": "4b41e752-3646-4097-ae80-21fd02e913f7", "code": "aud", "name": "Author of dialog", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.702+00:00", "updatedDate": "2025-05-16T18:12:33.702+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2b7080f7-d03d-46af-86f0-40ea02867362	{"id": "2b7080f7-d03d-46af-86f0-40ea02867362", "code": "cph", "name": "Copyright holder", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.715+00:00", "updatedDate": "2025-05-16T18:12:33.715+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3c3ab522-2600-4b93-a121-8832146d5cdf	{"id": "3c3ab522-2600-4b93-a121-8832146d5cdf", "code": "rsp", "name": "Respondent", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.728+00:00", "updatedDate": "2025-05-16T18:12:33.728+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
1b51068c-506a-4b85-a815-175c17932448	{"id": "1b51068c-506a-4b85-a815-175c17932448", "code": "pat", "name": "Patron", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.361+00:00", "updatedDate": "2025-05-16T18:12:33.361+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
26ad4833-5d49-4999-97fc-44bc86a9fae0	{"id": "26ad4833-5d49-4999-97fc-44bc86a9fae0", "code": "fpy", "name": "First party", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.373+00:00", "updatedDate": "2025-05-16T18:12:33.373+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
468ac852-339e-43b7-8e94-7e2ce475cb00	{"id": "468ac852-339e-43b7-8e94-7e2ce475cb00", "code": "cas", "name": "Caster", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.383+00:00", "updatedDate": "2025-05-16T18:12:33.383+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b1e95783-5308-46b2-9853-bd7015c1774b	{"id": "b1e95783-5308-46b2-9853-bd7015c1774b", "code": "edm", "name": "Editor of moving image work", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.395+00:00", "updatedDate": "2025-05-16T18:12:33.395+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7156fd73-b8ca-4e09-a002-bb2afaaf259a	{"id": "7156fd73-b8ca-4e09-a002-bb2afaaf259a", "code": "rse", "name": "Respondent-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.405+00:00", "updatedDate": "2025-05-16T18:12:33.405+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
563bcaa7-7fe1-4206-8fc9-5ef8c7fbf998	{"id": "563bcaa7-7fe1-4206-8fc9-5ef8c7fbf998", "code": "osp", "name": "Onscreen presenter", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.414+00:00", "updatedDate": "2025-05-16T18:12:33.414+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
002c0eef-eb77-4c0b-a38e-117a09773d59	{"id": "002c0eef-eb77-4c0b-a38e-117a09773d59", "code": "mtk", "name": "Minute taker", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.427+00:00", "updatedDate": "2025-05-16T18:12:33.427+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
539872f1-f4a1-4e83-9d87-da235f64c520	{"id": "539872f1-f4a1-4e83-9d87-da235f64c520", "code": "org", "name": "Originator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.436+00:00", "updatedDate": "2025-05-16T18:12:33.436+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7131e7b8-84fa-48bd-a725-14050be38f9f	{"id": "7131e7b8-84fa-48bd-a725-14050be38f9f", "code": "act", "name": "Actor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.444+00:00", "updatedDate": "2025-05-16T18:12:33.444+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e46bdfe3-5923-4585-bca4-d9d930d41148	{"id": "e46bdfe3-5923-4585-bca4-d9d930d41148", "code": "dfd", "name": "Defendant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.451+00:00", "updatedDate": "2025-05-16T18:12:33.451+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ad9b7785-53a2-4bf4-8a01-572858e82941	{"id": "ad9b7785-53a2-4bf4-8a01-572858e82941", "code": "asg", "name": "Assignee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.457+00:00", "updatedDate": "2025-05-16T18:12:33.457+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7aac64ab-7f2a-4019-9705-e07133e3ad1a	{"id": "7aac64ab-7f2a-4019-9705-e07133e3ad1a", "code": "cre", "name": "Creator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.466+00:00", "updatedDate": "2025-05-16T18:12:33.466+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d517010e-908f-49d6-b1e8-8c1a5f9a7f1c	{"id": "d517010e-908f-49d6-b1e8-8c1a5f9a7f1c", "code": "aft", "name": "Author of afterword, colophon, etc.", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.474+00:00", "updatedDate": "2025-05-16T18:12:33.474+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5b2de939-879c-45b4-817d-c29fd16b78a0	{"id": "5b2de939-879c-45b4-817d-c29fd16b78a0", "code": "elg", "name": "Electrician", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.484+00:00", "updatedDate": "2025-05-16T18:12:33.484+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
52c08141-307f-4997-9799-db97076a2eb3	{"id": "52c08141-307f-4997-9799-db97076a2eb3", "code": "lit", "name": "Libelant-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.492+00:00", "updatedDate": "2025-05-16T18:12:33.492+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e2b5ceaf-663b-4cc0-91ba-bf036943ece8	{"id": "e2b5ceaf-663b-4cc0-91ba-bf036943ece8", "code": "prp", "name": "Production place", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.497+00:00", "updatedDate": "2025-05-16T18:12:33.497+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
88370fc3-bf69-45b6-b518-daf9a3877385	{"id": "88370fc3-bf69-45b6-b518-daf9a3877385", "code": "dub", "name": "Dubious author", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.505+00:00", "updatedDate": "2025-05-16T18:12:33.505+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ec0959b3-becc-4abd-87b0-3e02cf2665cc	{"id": "ec0959b3-becc-4abd-87b0-3e02cf2665cc", "code": "cli", "name": "Client", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.512+00:00", "updatedDate": "2025-05-16T18:12:33.512+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e2a1a9dc-4aec-4bb5-ae43-99bb0383516a	{"id": "e2a1a9dc-4aec-4bb5-ae43-99bb0383516a", "code": "adi", "name": "Art director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.521+00:00", "updatedDate": "2025-05-16T18:12:33.521+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
12101b05-afcb-4159-9ee4-c207378ef910	{"id": "12101b05-afcb-4159-9ee4-c207378ef910", "code": "drt", "name": "Director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.530+00:00", "updatedDate": "2025-05-16T18:12:33.530+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c04ff362-c80a-4543-88cf-fc6e49e7d201	{"id": "c04ff362-c80a-4543-88cf-fc6e49e7d201", "code": "csl", "name": "Consultant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.364+00:00", "updatedDate": "2025-05-16T18:12:33.364+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3665d2dd-24cc-4fb4-922a-699811daa41c	{"id": "3665d2dd-24cc-4fb4-922a-699811daa41c", "code": "dsr", "name": "Designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.378+00:00", "updatedDate": "2025-05-16T18:12:33.378+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
168b6ff3-7482-4fd0-bf07-48172b47876c	{"id": "168b6ff3-7482-4fd0-bf07-48172b47876c", "code": "mrk", "name": "Markup editor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.386+00:00", "updatedDate": "2025-05-16T18:12:33.386+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c86fc16d-61d8-4471-8089-76550daa04f0	{"id": "c86fc16d-61d8-4471-8089-76550daa04f0", "code": "dft", "name": "Defendant-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.398+00:00", "updatedDate": "2025-05-16T18:12:33.398+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8fbe6e92-87c9-4eff-b736-88cd02571465	{"id": "8fbe6e92-87c9-4eff-b736-88cd02571465", "code": "dnr", "name": "Donor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.418+00:00", "updatedDate": "2025-05-16T18:12:33.418+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
86b9292d-4dce-401d-861e-2df2cfaacb83	{"id": "86b9292d-4dce-401d-861e-2df2cfaacb83", "code": "rpt", "name": "Reporter", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.432+00:00", "updatedDate": "2025-05-16T18:12:33.432+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0eef1c70-bd77-429c-a790-48a8d82b4d8f	{"id": "0eef1c70-bd77-429c-a790-48a8d82b4d8f", "code": "trc", "name": "Transcriber", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.448+00:00", "updatedDate": "2025-05-16T18:12:33.448+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0ad74d5d-03b9-49bb-b9df-d692945ca66e	{"id": "0ad74d5d-03b9-49bb-b9df-d692945ca66e", "code": "cot", "name": "Contestant-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.462+00:00", "updatedDate": "2025-05-16T18:12:33.462+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
00311f78-e990-4d8b-907e-c67a3664fe15	{"id": "00311f78-e990-4d8b-907e-c67a3664fe15", "code": "dtc", "name": "Data contributor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.476+00:00", "updatedDate": "2025-05-16T18:12:33.476+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e1510ac5-a9e9-4195-b762-7cb82c5357c4	{"id": "e1510ac5-a9e9-4195-b762-7cb82c5357c4", "code": "cst", "name": "Costume designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.488+00:00", "updatedDate": "2025-05-16T18:12:33.488+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
38c09577-6652-4281-a391-4caabe4c09b6	{"id": "38c09577-6652-4281-a391-4caabe4c09b6", "code": "spn", "name": "Sponsor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.506+00:00", "updatedDate": "2025-05-16T18:12:33.506+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6358626f-aa02-4c40-8e73-fb202fa5fb4d	{"id": "6358626f-aa02-4c40-8e73-fb202fa5fb4d", "code": "cpe", "name": "Complainant-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.515+00:00", "updatedDate": "2025-05-16T18:12:33.515+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
13361ce8-7664-46c0-860d-ffbcc01414e0	{"id": "13361ce8-7664-46c0-860d-ffbcc01414e0", "code": "rps", "name": "Repository", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.524+00:00", "updatedDate": "2025-05-16T18:12:33.524+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2d046e17-742b-4d99-8e25-836cc141fee9	{"id": "2d046e17-742b-4d99-8e25-836cc141fee9", "code": "pbd", "name": "Publishing director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.533+00:00", "updatedDate": "2025-05-16T18:12:33.533+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ced7cdfc-a3e0-47c8-861b-3f558094b02e	{"id": "ced7cdfc-a3e0-47c8-861b-3f558094b02e", "code": "ant", "name": "Bibliographic antecedent", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.542+00:00", "updatedDate": "2025-05-16T18:12:33.542+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f9395f3d-cd46-413e-9504-8756c54f38a2	{"id": "f9395f3d-cd46-413e-9504-8756c54f38a2", "code": "pfr", "name": "Proofreader", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.551+00:00", "updatedDate": "2025-05-16T18:12:33.551+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d791c3b9-993a-4203-ac81-3fb3f14793ae	{"id": "d791c3b9-993a-4203-ac81-3fb3f14793ae", "code": "led", "name": "Lead", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.561+00:00", "updatedDate": "2025-05-16T18:12:33.561+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8ddb69bb-cd69-4898-a62d-b71649089e4a	{"id": "8ddb69bb-cd69-4898-a62d-b71649089e4a", "code": "cor", "name": "Collection registrar", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.573+00:00", "updatedDate": "2025-05-16T18:12:33.573+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f0061c4b-df42-432f-9d1a-3873bb27c8e6	{"id": "f0061c4b-df42-432f-9d1a-3873bb27c8e6", "code": "ape", "name": "Appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.584+00:00", "updatedDate": "2025-05-16T18:12:33.584+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c96df2ce-7b00-498a-bf37-3011f3ef1229	{"id": "c96df2ce-7b00-498a-bf37-3011f3ef1229", "code": "rpc", "name": "Radio producer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.599+00:00", "updatedDate": "2025-05-16T18:12:33.599+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
764c208a-493f-43af-8db7-3dd48efca45c	{"id": "764c208a-493f-43af-8db7-3dd48efca45c", "code": "exp", "name": "Expert", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.538+00:00", "updatedDate": "2025-05-16T18:12:33.538+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
abfa3014-7349-444b-aace-9d28efa5ede4	{"id": "abfa3014-7349-444b-aace-9d28efa5ede4", "code": "hst", "name": "Host", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.548+00:00", "updatedDate": "2025-05-16T18:12:33.548+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
50a6d58a-cea2-42a1-8c57-0c6fde225c93	{"id": "50a6d58a-cea2-42a1-8c57-0c6fde225c93", "code": "bsl", "name": "Bookseller", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.558+00:00", "updatedDate": "2025-05-16T18:12:33.558+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
1aae8ca3-4ddd-4549-a769-116b75f3c773	{"id": "1aae8ca3-4ddd-4549-a769-116b75f3c773", "code": "pht", "name": "Photographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.570+00:00", "updatedDate": "2025-05-16T18:12:33.570+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
05875ac5-a509-4a51-a6ee-b8051e37c7b0	{"id": "05875ac5-a509-4a51-a6ee-b8051e37c7b0", "code": "sce", "name": "Scenarist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.578+00:00", "updatedDate": "2025-05-16T18:12:33.578+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2c9cd812-7b00-47e8-81e5-1711f3b6fe38	{"id": "2c9cd812-7b00-47e8-81e5-1711f3b6fe38", "code": "pup", "name": "Publication place", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.587+00:00", "updatedDate": "2025-05-16T18:12:33.587+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
af09f37e-12f5-46db-a532-ccd6a8877f2d	{"id": "af09f37e-12f5-46db-a532-ccd6a8877f2d", "code": "tld", "name": "Television director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.593+00:00", "updatedDate": "2025-05-16T18:12:33.593+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b13f6a89-d2e3-4264-8418-07ad4de6a626	{"id": "b13f6a89-d2e3-4264-8418-07ad4de6a626", "code": "prd", "name": "Production personnel", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.602+00:00", "updatedDate": "2025-05-16T18:12:33.602+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d2df2901-fac7-45e1-a9ad-7a67b70ea65b	{"id": "d2df2901-fac7-45e1-a9ad-7a67b70ea65b", "code": "mon", "name": "Monitor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.613+00:00", "updatedDate": "2025-05-16T18:12:33.613+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
54fd209c-d552-43eb-850f-d31f557170b9	{"id": "54fd209c-d552-43eb-850f-d31f557170b9", "code": "rtm", "name": "Research team member", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.624+00:00", "updatedDate": "2025-05-16T18:12:33.624+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ab7a95da-590c-4955-b03b-9d8fbc6c1fe6	{"id": "ab7a95da-590c-4955-b03b-9d8fbc6c1fe6", "code": "rce", "name": "Recording engineer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.637+00:00", "updatedDate": "2025-05-16T18:12:33.637+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
61c9f06f-620a-4423-8c78-c698b9bb555f	{"id": "61c9f06f-620a-4423-8c78-c698b9bb555f", "code": "lel", "name": "Libelee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.643+00:00", "updatedDate": "2025-05-16T18:12:33.643+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
88a66ebf-0b18-4ed7-91e5-01bc7e8de441	{"id": "88a66ebf-0b18-4ed7-91e5-01bc7e8de441", "code": "lee", "name": "Libelee-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.652+00:00", "updatedDate": "2025-05-16T18:12:33.652+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3322b734-ce38-4cd4-815d-8983352837cc	{"id": "3322b734-ce38-4cd4-815d-8983352837cc", "code": "trl", "name": "Translator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.661+00:00", "updatedDate": "2025-05-16T18:12:33.661+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e603ffa2-8999-4091-b10d-96248c283c04	{"id": "e603ffa2-8999-4091-b10d-96248c283c04", "code": "lbr", "name": "Laboratory", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.667+00:00", "updatedDate": "2025-05-16T18:12:33.667+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a3642006-14ab-4816-b5ac-533e4971417a	{"id": "a3642006-14ab-4816-b5ac-533e4971417a", "code": "stl", "name": "Storyteller", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.673+00:00", "updatedDate": "2025-05-16T18:12:33.673+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fd0a47ec-58ce-43f6-8ecc-696ec17a98ab	{"id": "fd0a47ec-58ce-43f6-8ecc-696ec17a98ab", "code": "pop", "name": "Printer of plates", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.680+00:00", "updatedDate": "2025-05-16T18:12:33.680+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ac0baeb5-71e2-435f-aaf1-14b64e2ba700	{"id": "ac0baeb5-71e2-435f-aaf1-14b64e2ba700", "code": "spk", "name": "Speaker", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.687+00:00", "updatedDate": "2025-05-16T18:12:33.687+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
246858e3-4022-4991-9f1c-50901ccc1438	{"id": "246858e3-4022-4991-9f1c-50901ccc1438", "code": "prf", "name": "Performer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.692+00:00", "updatedDate": "2025-05-16T18:12:33.692+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f9e5b41b-8d5b-47d3-91d0-ca9004796337	{"id": "f9e5b41b-8d5b-47d3-91d0-ca9004796337", "code": "art", "name": "Artist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.699+00:00", "updatedDate": "2025-05-16T18:12:33.699+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
361f4bfd-a87d-463c-84d8-69346c3082f6	{"id": "361f4bfd-a87d-463c-84d8-69346c3082f6", "code": "oth", "name": "Other", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.603+00:00", "updatedDate": "2025-05-16T18:12:33.603+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ac64c865-4f29-4d51-8b43-7816a5217f04	{"id": "ac64c865-4f29-4d51-8b43-7816a5217f04", "code": "arr", "name": "Arranger", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.615+00:00", "updatedDate": "2025-05-16T18:12:33.615+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
66bfc19c-eeb0-4167-bd8d-448311aab929	{"id": "66bfc19c-eeb0-4167-bd8d-448311aab929", "code": "mcp", "name": "Music copyist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.627+00:00", "updatedDate": "2025-05-16T18:12:33.627+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
cf04404a-d628-432b-b190-6694c5a3dc4b	{"id": "cf04404a-d628-432b-b190-6694c5a3dc4b", "code": "rsr", "name": "Restorationist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.640+00:00", "updatedDate": "2025-05-16T18:12:33.640+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c8050073-f62b-4606-9688-02caa98bdc60	{"id": "c8050073-f62b-4606-9688-02caa98bdc60", "code": "crr", "name": "Corrector", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.662+00:00", "updatedDate": "2025-05-16T18:12:33.662+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c5988fb2-cd21-469c-b35e-37e443c01adc	{"id": "c5988fb2-cd21-469c-b35e-37e443c01adc", "code": "sad", "name": "Scientific advisor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.671+00:00", "updatedDate": "2025-05-16T18:12:33.671+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e0dc043c-0a4d-499b-a8a8-4cc9b0869cf3	{"id": "e0dc043c-0a4d-499b-a8a8-4cc9b0869cf3", "code": "cmm", "name": "Commentator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.687+00:00", "updatedDate": "2025-05-16T18:12:33.687+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3db02638-598e-44a3-aafa-cbae77533ee1	{"id": "3db02638-598e-44a3-aafa-cbae77533ee1", "code": "ccp", "name": "Conceptor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.700+00:00", "updatedDate": "2025-05-16T18:12:33.700+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5ee1e598-72b8-44d5-8edd-173e7bc4cf8c	{"id": "5ee1e598-72b8-44d5-8edd-173e7bc4cf8c", "code": "prc", "name": "Process contact", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.713+00:00", "updatedDate": "2025-05-16T18:12:33.713+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8210b9d7-8fe7-41b7-8c5f-6e0485b50725	{"id": "8210b9d7-8fe7-41b7-8c5f-6e0485b50725", "code": "prs", "name": "Production designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.725+00:00", "updatedDate": "2025-05-16T18:12:33.725+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e7e8fc17-7c97-4a37-8c12-f832ddca7a71	{"id": "e7e8fc17-7c97-4a37-8c12-f832ddca7a71", "code": "ive", "name": "Interviewee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.738+00:00", "updatedDate": "2025-05-16T18:12:33.738+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
cce475f7-ccfa-4e15-adf8-39f907788515	{"id": "cce475f7-ccfa-4e15-adf8-39f907788515", "code": "ths", "name": "Thesis advisor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.756+00:00", "updatedDate": "2025-05-16T18:12:33.756+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a79f874f-319e-4bc8-a2e1-f8b15fa186fe	{"id": "a79f874f-319e-4bc8-a2e1-f8b15fa186fe", "code": "cnd", "name": "Conductor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.768+00:00", "updatedDate": "2025-05-16T18:12:33.768+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b388c02a-19dc-4948-916d-3688007b9a2c	{"id": "b388c02a-19dc-4948-916d-3688007b9a2c", "code": "rcd", "name": "Recordist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.779+00:00", "updatedDate": "2025-05-16T18:12:33.779+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
754edaff-07bb-45eb-88bf-10a8b6842c38	{"id": "754edaff-07bb-45eb-88bf-10a8b6842c38", "code": "arc", "name": "Architect", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.785+00:00", "updatedDate": "2025-05-16T18:12:33.785+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
913233b3-b2a0-4635-8dad-49b6fc515fc5	{"id": "913233b3-b2a0-4635-8dad-49b6fc515fc5", "code": "wam", "name": "Writer of accompanying material", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.795+00:00", "updatedDate": "2025-05-16T18:12:33.795+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2c345cb7-0420-4a7d-93ce-b51fb636cce6	{"id": "2c345cb7-0420-4a7d-93ce-b51fb636cce6", "code": "nrt", "name": "Narrator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.805+00:00", "updatedDate": "2025-05-16T18:12:33.805+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
27aeee86-4099-466d-ba10-6d876e6f293b	{"id": "27aeee86-4099-466d-ba10-6d876e6f293b", "code": "com", "name": "Compiler", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.816+00:00", "updatedDate": "2025-05-16T18:12:33.816+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fec4d84b-0421-4d15-b53f-d5104f39b3ca	{"id": "fec4d84b-0421-4d15-b53f-d5104f39b3ca", "code": "res", "name": "Researcher", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.828+00:00", "updatedDate": "2025-05-16T18:12:33.828+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
53f075e1-53c0-423f-95ae-676df3d8c7a2	{"id": "53f075e1-53c0-423f-95ae-676df3d8c7a2", "code": "win", "name": "Writer of introduction", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.842+00:00", "updatedDate": "2025-05-16T18:12:33.842+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e4f2fd1c-ee79-4cf7-bc1a-fbaac616f804	{"id": "e4f2fd1c-ee79-4cf7-bc1a-fbaac616f804", "code": "len", "name": "Lender", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.606+00:00", "updatedDate": "2025-05-16T18:12:33.606+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3c1508ab-fbcc-4500-b319-10885570fe2f	{"id": "3c1508ab-fbcc-4500-b319-10885570fe2f", "code": "lsa", "name": "Landscape architect", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.614+00:00", "updatedDate": "2025-05-16T18:12:33.614+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
df7daf2f-7ab4-4c7b-a24d-d46695fa9072	{"id": "df7daf2f-7ab4-4c7b-a24d-d46695fa9072", "code": "orm", "name": "Organizer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.617+00:00", "updatedDate": "2025-05-16T18:12:33.617+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
94e6a5a8-b84f-44f7-b900-71cd10ea954e	{"id": "94e6a5a8-b84f-44f7-b900-71cd10ea954e", "code": "rcp", "name": "Addressee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.625+00:00", "updatedDate": "2025-05-16T18:12:33.625+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
60d3f16f-958a-45c2-bb39-69cc9eb3835e	{"id": "60d3f16f-958a-45c2-bb39-69cc9eb3835e", "code": "fds", "name": "Film distributor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.630+00:00", "updatedDate": "2025-05-16T18:12:33.630+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c9d28351-c862-433e-8957-c4721f30631f	{"id": "c9d28351-c862-433e-8957-c4721f30631f", "code": "acp", "name": "Art copyist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.638+00:00", "updatedDate": "2025-05-16T18:12:33.638+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ae8bc401-47da-4853-9b0b-c7c2c3ec324d	{"id": "ae8bc401-47da-4853-9b0b-c7c2c3ec324d", "code": "lil", "name": "Libelant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.657+00:00", "updatedDate": "2025-05-16T18:12:33.657+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a21a56ea-5136-439a-a513-0bffa53402de	{"id": "a21a56ea-5136-439a-a513-0bffa53402de", "code": "srv", "name": "Surveyor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.670+00:00", "updatedDate": "2025-05-16T18:12:33.670+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b318e49c-f2ad-498c-8106-57b5544f9bb0	{"id": "b318e49c-f2ad-498c-8106-57b5544f9bb0", "code": "prn", "name": "Production company", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.676+00:00", "updatedDate": "2025-05-16T18:12:33.676+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a7a25290-226d-4f81-b780-2efc1f7dfd26	{"id": "a7a25290-226d-4f81-b780-2efc1f7dfd26", "code": "med", "name": "Medium", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.684+00:00", "updatedDate": "2025-05-16T18:12:33.684+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a2231628-6a5a-48f4-8eac-7e6b0328f6fe	{"id": "a2231628-6a5a-48f4-8eac-7e6b0328f6fe", "code": "mfp", "name": "Manufacture place", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.697+00:00", "updatedDate": "2025-05-16T18:12:33.697+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e8423d78-7b08-4f81-8f34-4871d5e2b7af	{"id": "e8423d78-7b08-4f81-8f34-4871d5e2b7af", "code": "ctt", "name": "Contestee-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.707+00:00", "updatedDate": "2025-05-16T18:12:33.707+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
316cd382-a4fe-4939-b06e-e7199bfdbc7a	{"id": "316cd382-a4fe-4939-b06e-e7199bfdbc7a", "code": "cwt", "name": "Commentator for written text", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.715+00:00", "updatedDate": "2025-05-16T18:12:33.715+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d30f5556-6d79-4980-9528-c48ef60f3b31	{"id": "d30f5556-6d79-4980-9528-c48ef60f3b31", "code": "plt", "name": "Platemaker", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.723+00:00", "updatedDate": "2025-05-16T18:12:33.723+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0683aecf-42a8-432d-adb2-a8abaf2f15d5	{"id": "0683aecf-42a8-432d-adb2-a8abaf2f15d5", "code": "pma", "name": "Permitting agency", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.737+00:00", "updatedDate": "2025-05-16T18:12:33.737+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b76cb226-50f9-4d34-a3d0-48b475f83c80	{"id": "b76cb226-50f9-4d34-a3d0-48b475f83c80", "code": "jug", "name": "Jurisdiction governed", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.755+00:00", "updatedDate": "2025-05-16T18:12:33.755+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
901d01e5-66b1-48f0-99f9-b5e92e3d2d15	{"id": "901d01e5-66b1-48f0-99f9-b5e92e3d2d15", "code": "cmp", "name": "Composer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.764+00:00", "updatedDate": "2025-05-16T18:12:33.764+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2cb49b06-5aeb-4e84-8160-79d13c6357ed	{"id": "2cb49b06-5aeb-4e84-8160-79d13c6357ed", "code": "pth", "name": "Patent holder", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.775+00:00", "updatedDate": "2025-05-16T18:12:33.775+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
eecb30c5-a061-4790-8fa5-cf24d0fa472b	{"id": "eecb30c5-a061-4790-8fa5-cf24d0fa472b", "code": "ivr", "name": "Interviewer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.788+00:00", "updatedDate": "2025-05-16T18:12:33.788+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8999f7cb-6d9a-4be7-aeed-4cc6aae35a8c	{"id": "8999f7cb-6d9a-4be7-aeed-4cc6aae35a8c", "code": "cll", "name": "Calligrapher", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.803+00:00", "updatedDate": "2025-05-16T18:12:33.803+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
515caf91-3dde-4769-b784-50c9e23400d5	{"id": "515caf91-3dde-4769-b784-50c9e23400d5", "code": "mrb", "name": "Marbler", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.704+00:00", "updatedDate": "2025-05-16T18:12:33.704+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e79ca231-af4c-4724-8fe1-eabafd2e0bec	{"id": "e79ca231-af4c-4724-8fe1-eabafd2e0bec", "code": "mod", "name": "Moderator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.711+00:00", "updatedDate": "2025-05-16T18:12:33.711+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e038262b-25f8-471b-93ea-2afe287b00a3	{"id": "e038262b-25f8-471b-93ea-2afe287b00a3", "code": "ilu", "name": "Illuminator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.720+00:00", "updatedDate": "2025-05-16T18:12:33.720+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3ed655b0-505b-43fe-a4c6-397789449a5b	{"id": "3ed655b0-505b-43fe-a4c6-397789449a5b", "code": "tlp", "name": "Television producer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.727+00:00", "updatedDate": "2025-05-16T18:12:33.727+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9e7651f8-a4f0-4d02-81b4-578ef9303d1b	{"id": "9e7651f8-a4f0-4d02-81b4-578ef9303d1b", "code": "std", "name": "Set designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.734+00:00", "updatedDate": "2025-05-16T18:12:33.734+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8af7e981-65f9-4407-80ae-1bacd11315d5	{"id": "8af7e981-65f9-4407-80ae-1bacd11315d5", "code": "mte", "name": "Metal-engraver", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.745+00:00", "updatedDate": "2025-05-16T18:12:33.745+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
223da16e-5a03-4f5c-b8c3-0eb79f662bcb	{"id": "223da16e-5a03-4f5c-b8c3-0eb79f662bcb", "code": "scl", "name": "Sculptor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.751+00:00", "updatedDate": "2025-05-16T18:12:33.751+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
44eaf0db-85dd-4888-ac8d-a5976dd483a6	{"id": "44eaf0db-85dd-4888-ac8d-a5976dd483a6", "code": "rth", "name": "Research team head", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.760+00:00", "updatedDate": "2025-05-16T18:12:33.760+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
94b839e8-cabe-4d58-8918-8a5058fe5501	{"id": "94b839e8-cabe-4d58-8918-8a5058fe5501", "code": "rst", "name": "Respondent-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.772+00:00", "updatedDate": "2025-05-16T18:12:33.772+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
12a73179-1283-4828-8fd9-065e18dc2e78	{"id": "12a73179-1283-4828-8fd9-065e18dc2e78", "code": "sgn", "name": "Signer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.782+00:00", "updatedDate": "2025-05-16T18:12:33.782+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
de1ea2dc-8d9d-4dfa-b86e-8ce9d8b0c2f2	{"id": "de1ea2dc-8d9d-4dfa-b86e-8ce9d8b0c2f2", "code": "wde", "name": "Wood engraver", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.792+00:00", "updatedDate": "2025-05-16T18:12:33.792+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7c5c2fd5-3283-4f96-be89-3bb3e8fa6942	{"id": "7c5c2fd5-3283-4f96-be89-3bb3e8fa6942", "code": "wst", "name": "Writer of supplementary textual content", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.797+00:00", "updatedDate": "2025-05-16T18:12:33.797+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
68dcc037-901e-46a9-9b4e-028548cd750f	{"id": "68dcc037-901e-46a9-9b4e-028548cd750f", "code": "ptt", "name": "Plaintiff-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.801+00:00", "updatedDate": "2025-05-16T18:12:33.801+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
453e4f4a-cda9-4cfa-b93d-3faeb18a85db	{"id": "453e4f4a-cda9-4cfa-b93d-3faeb18a85db", "code": "rsg", "name": "Restager", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.808+00:00", "updatedDate": "2025-05-16T18:12:33.808+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
115fa75c-385b-4a8e-9a2b-b13de9f21bcf	{"id": "115fa75c-385b-4a8e-9a2b-b13de9f21bcf", "code": "wpr", "name": "Writer of preface", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.812+00:00", "updatedDate": "2025-05-16T18:12:33.812+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7e5b0859-80c1-4e78-a5e7-61979862c1fa	{"id": "7e5b0859-80c1-4e78-a5e7-61979862c1fa", "code": "str", "name": "Stereotyper", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.818+00:00", "updatedDate": "2025-05-16T18:12:33.818+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
201a378e-23dd-4aab-bfe0-e5bc3c855f9c	{"id": "201a378e-23dd-4aab-bfe0-e5bc3c855f9c", "code": "elt", "name": "Electrotyper", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.825+00:00", "updatedDate": "2025-05-16T18:12:33.825+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
398a0a2f-752d-4496-8737-e6df7c29aaa7	{"id": "398a0a2f-752d-4496-8737-e6df7c29aaa7", "code": "lyr", "name": "Lyricist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.833+00:00", "updatedDate": "2025-05-16T18:12:33.833+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
97082157-5900-4c4c-a6d8-2e6c13f22ef1	{"id": "97082157-5900-4c4c-a6d8-2e6c13f22ef1", "code": "isb", "name": "Issuing body", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.838+00:00", "updatedDate": "2025-05-16T18:12:33.838+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e04bea27-813b-4765-9ba1-e98e0fca7101	{"id": "e04bea27-813b-4765-9ba1-e98e0fca7101", "code": "dln", "name": "Delineator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.847+00:00", "updatedDate": "2025-05-16T18:12:33.847+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7bebb5a2-9332-4ba7-a258-875143b5d754	{"id": "7bebb5a2-9332-4ba7-a258-875143b5d754", "code": "csp", "name": "Consultant to a project", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.742+00:00", "updatedDate": "2025-05-16T18:12:33.742+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
41a0378d-5362-4c1a-b103-592ff354be1c	{"id": "41a0378d-5362-4c1a-b103-592ff354be1c", "code": "jud", "name": "Judge", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.797+00:00", "updatedDate": "2025-05-16T18:12:33.797+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b998a229-68e7-4a3d-8cfd-b73c10844e96	{"id": "b998a229-68e7-4a3d-8cfd-b73c10844e96", "code": "anm", "name": "Animator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.808+00:00", "updatedDate": "2025-05-16T18:12:33.808+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d04782ec-b969-4eac-9428-0eb52d97c644	{"id": "d04782ec-b969-4eac-9428-0eb52d97c644", "code": "pre", "name": "Presenter", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.819+00:00", "updatedDate": "2025-05-16T18:12:33.819+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b38c4e20-9aa0-43f4-a1a0-f547e54873f7	{"id": "b38c4e20-9aa0-43f4-a1a0-f547e54873f7", "code": "red", "name": "Redaktor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.830+00:00", "updatedDate": "2025-05-16T18:12:33.830+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
825a7d9f-7596-4007-9684-9bee72625cfc	{"id": "825a7d9f-7596-4007-9684-9bee72625cfc", "code": "dgs", "name": "Degree supervisor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.844+00:00", "updatedDate": "2025-05-16T18:12:33.844+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
54f69767-5712-47aa-bdb7-39c31aa8295e	{"id": "54f69767-5712-47aa-bdb7-39c31aa8295e", "code": "evp", "name": "Event place", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.856+00:00", "updatedDate": "2025-05-16T18:12:33.856+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
593862b4-a655-47c3-92b9-2b305b14cce7	{"id": "593862b4-a655-47c3-92b9-2b305b14cce7", "code": "chr", "name": "Choreographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.868+00:00", "updatedDate": "2025-05-16T18:12:33.868+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
bd13d6d3-e604-4b80-9c5f-4d68115ba616	{"id": "bd13d6d3-e604-4b80-9c5f-4d68115ba616", "code": "crt", "name": "Court reporter", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.891+00:00", "updatedDate": "2025-05-16T18:12:33.891+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d836488a-8d0e-42ad-9091-b63fe885fe03	{"id": "d836488a-8d0e-42ad-9091-b63fe885fe03", "code": "att", "name": "Attributed name", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.904+00:00", "updatedDate": "2025-05-16T18:12:33.904+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2fba7b2e-26bc-4ac5-93cb-73e31e554377	{"id": "2fba7b2e-26bc-4ac5-93cb-73e31e554377", "code": "spy", "name": "Second party", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.916+00:00", "updatedDate": "2025-05-16T18:12:33.916+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
81b2174a-06b9-48f5-8c49-6cbaf7b869fe	{"id": "81b2174a-06b9-48f5-8c49-6cbaf7b869fe", "code": "his", "name": "Host institution", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.939+00:00", "updatedDate": "2025-05-16T18:12:33.939+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2a3e2d58-3a21-4e35-b7e4-cffb197750e3	{"id": "2a3e2d58-3a21-4e35-b7e4-cffb197750e3", "code": "cng", "name": "Cinematographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.951+00:00", "updatedDate": "2025-05-16T18:12:33.951+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5e9333a6-bc92-43c0-a306-30811bb71e61	{"id": "5e9333a6-bc92-43c0-a306-30811bb71e61", "code": "lgd", "name": "Lighting designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.962+00:00", "updatedDate": "2025-05-16T18:12:33.962+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3179eb17-275e-44f8-8cad-3a9514799bd0	{"id": "3179eb17-275e-44f8-8cad-3a9514799bd0", "code": "sll", "name": "Seller", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.976+00:00", "updatedDate": "2025-05-16T18:12:33.976+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ca3b9559-f178-41e8-aa88-6b2c367025f9	{"id": "ca3b9559-f178-41e8-aa88-6b2c367025f9", "code": "app", "name": "Applicant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.989+00:00", "updatedDate": "2025-05-16T18:12:33.989+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3ebe73f4-0895-4979-a5e3-2b3e9c63acd6	{"id": "3ebe73f4-0895-4979-a5e3-2b3e9c63acd6", "code": "dfe", "name": "Defendant-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.001+00:00", "updatedDate": "2025-05-16T18:12:34.001+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
21430354-f17a-4ac1-8545-1a5907cd15e5	{"id": "21430354-f17a-4ac1-8545-1a5907cd15e5", "code": "inv", "name": "Inventor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.014+00:00", "updatedDate": "2025-05-16T18:12:34.014+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a986c8f2-b36a-400d-b09f-9250a753563c	{"id": "a986c8f2-b36a-400d-b09f-9250a753563c", "code": "brl", "name": "Braille embosser", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.026+00:00", "updatedDate": "2025-05-16T18:12:34.026+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3b4709f1-5286-4c42-9423-4620fff78141	{"id": "3b4709f1-5286-4c42-9423-4620fff78141", "code": "prv", "name": "Provider", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.040+00:00", "updatedDate": "2025-05-16T18:12:34.040+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ec56cc25-e470-46f7-a429-72f438c0513b	{"id": "ec56cc25-e470-46f7-a429-72f438c0513b", "code": "wit", "name": "Witness", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.814+00:00", "updatedDate": "2025-05-16T18:12:33.814+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6b566426-f325-4182-ac31-e1c4e0b2aa19	{"id": "6b566426-f325-4182-ac31-e1c4e0b2aa19", "code": "ren", "name": "Renderer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.827+00:00", "updatedDate": "2025-05-16T18:12:33.827+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b7000ced-c847-4b43-8f29-c5325e6279a8	{"id": "b7000ced-c847-4b43-8f29-c5325e6279a8", "code": "cov", "name": "Cover designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.841+00:00", "updatedDate": "2025-05-16T18:12:33.841+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
99f6b0b7-c22f-460d-afe0-ee0877bc66d1	{"id": "99f6b0b7-c22f-460d-afe0-ee0877bc66d1", "code": "lso", "name": "Licensor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.851+00:00", "updatedDate": "2025-05-16T18:12:33.851+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6ccd61f4-c408-46ec-b359-a761b4781477	{"id": "6ccd61f4-c408-46ec-b359-a761b4781477", "code": "etr", "name": "Etcher", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.865+00:00", "updatedDate": "2025-05-16T18:12:33.865+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
61afcb8a-8c53-445b-93b9-38e799721f82	{"id": "61afcb8a-8c53-445b-93b9-38e799721f82", "code": "enj", "name": "Enacting jurisdiction", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.876+00:00", "updatedDate": "2025-05-16T18:12:33.876+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
1c623f6e-25bf-41ec-8110-6bde712dfa79	{"id": "1c623f6e-25bf-41ec-8110-6bde712dfa79", "code": "sds", "name": "Sound designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.883+00:00", "updatedDate": "2025-05-16T18:12:33.883+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a8d59132-aa1e-4a62-b5bd-b26b7d7a16b9	{"id": "a8d59132-aa1e-4a62-b5bd-b26b7d7a16b9", "code": "lse", "name": "Licensee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.899+00:00", "updatedDate": "2025-05-16T18:12:33.899+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f6bd4f15-4715-4b0e-9258-61dac047f106	{"id": "f6bd4f15-4715-4b0e-9258-61dac047f106", "code": "ins", "name": "Inscriber", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.913+00:00", "updatedDate": "2025-05-16T18:12:33.913+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
08cb225a-302c-4d5a-a6a3-fa90850babcd	{"id": "08cb225a-302c-4d5a-a6a3-fa90850babcd", "code": "pra", "name": "Praeses", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.923+00:00", "updatedDate": "2025-05-16T18:12:33.923+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0d2580f5-fe16-4d64-a5eb-f0247cccb129	{"id": "0d2580f5-fe16-4d64-a5eb-f0247cccb129", "code": "dto", "name": "Dedicator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.930+00:00", "updatedDate": "2025-05-16T18:12:33.930+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f5f9108a-9afc-4ea9-9b99-4f83dcf51204	{"id": "f5f9108a-9afc-4ea9-9b99-4f83dcf51204", "code": "fmd", "name": "Film director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.939+00:00", "updatedDate": "2025-05-16T18:12:33.939+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f26858bc-4468-47be-8e30-d5db4c0b1e88	{"id": "f26858bc-4468-47be-8e30-d5db4c0b1e88", "code": "dis", "name": "Dissertant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.946+00:00", "updatedDate": "2025-05-16T18:12:33.946+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f74dfba3-ea20-471b-8c4f-5d9b7895d3b5	{"id": "f74dfba3-ea20-471b-8c4f-5d9b7895d3b5", "code": "ldr", "name": "Laboratory director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.957+00:00", "updatedDate": "2025-05-16T18:12:33.957+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a5c024f1-3c81-492c-ab5e-73d2bc5dcad7	{"id": "a5c024f1-3c81-492c-ab5e-73d2bc5dcad7", "code": "let", "name": "Libelee-appellant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.971+00:00", "updatedDate": "2025-05-16T18:12:33.971+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
396f4b4d-5b0a-4fb4-941b-993ebf63db2e	{"id": "396f4b4d-5b0a-4fb4-941b-993ebf63db2e", "code": "anl", "name": "Analyst", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.978+00:00", "updatedDate": "2025-05-16T18:12:33.978+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
22286157-3058-434c-9009-8f8d100fc74a	{"id": "22286157-3058-434c-9009-8f8d100fc74a", "code": "ctg", "name": "Cartographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.983+00:00", "updatedDate": "2025-05-16T18:12:33.983+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6a983219-b6cd-4dd7-bfa4-bcb0b43590d4	{"id": "6a983219-b6cd-4dd7-bfa4-bcb0b43590d4", "code": "wat", "name": "Writer of added text", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.996+00:00", "updatedDate": "2025-05-16T18:12:33.996+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e1edbaae-5365-4fcb-bb6a-7aae38bbed9c	{"id": "e1edbaae-5365-4fcb-bb6a-7aae38bbed9c", "code": "msd", "name": "Musical director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.009+00:00", "updatedDate": "2025-05-16T18:12:34.009+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6847c9ab-e2f8-4c9e-8dc6-1a97c6836c1c	{"id": "6847c9ab-e2f8-4c9e-8dc6-1a97c6836c1c", "code": "sng", "name": "Singer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.023+00:00", "updatedDate": "2025-05-16T18:12:34.023+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
319cb290-a549-4ae8-a0ed-a65fe155cac8	{"id": "319cb290-a549-4ae8-a0ed-a65fe155cac8", "code": "crp", "name": "Correspondent", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.853+00:00", "updatedDate": "2025-05-16T18:12:33.853+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d67decd7-3dbe-4ac7-8072-ef18f5cd3e09	{"id": "d67decd7-3dbe-4ac7-8072-ef18f5cd3e09", "code": "cur", "name": "Curator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.860+00:00", "updatedDate": "2025-05-16T18:12:33.860+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d6a6d28c-1bfc-46df-b2ba-6cb377a6151e	{"id": "d6a6d28c-1bfc-46df-b2ba-6cb377a6151e", "code": "prm", "name": "Printmaker", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.864+00:00", "updatedDate": "2025-05-16T18:12:33.864+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
40fe62fb-4319-4313-ac88-ac4912b1e1fa	{"id": "40fe62fb-4319-4313-ac88-ac4912b1e1fa", "code": "aus", "name": "Screenwriter", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.870+00:00", "updatedDate": "2025-05-16T18:12:33.870+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
1f20d444-79f6-497a-ae0d-98a92e504c58	{"id": "1f20d444-79f6-497a-ae0d-98a92e504c58", "code": "aui", "name": "Author of introduction, etc.", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.879+00:00", "updatedDate": "2025-05-16T18:12:33.879+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
35a3feaf-1c13-4221-8cfa-d6879faf714c	{"id": "35a3feaf-1c13-4221-8cfa-d6879faf714c", "code": "adp", "name": "Adapter", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.886+00:00", "updatedDate": "2025-05-16T18:12:33.886+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
366821b5-5319-4888-8867-0ffb2d7649d1	{"id": "366821b5-5319-4888-8867-0ffb2d7649d1", "code": "eng", "name": "Engineer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.891+00:00", "updatedDate": "2025-05-16T18:12:33.891+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2665431e-aad4-44d1-9218-04053d1cfd53	{"id": "2665431e-aad4-44d1-9218-04053d1cfd53", "code": "fmp", "name": "Film producer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.895+00:00", "updatedDate": "2025-05-16T18:12:33.895+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
36b921fe-6c34-45c8-908b-5701f0763e1b	{"id": "36b921fe-6c34-45c8-908b-5701f0763e1b", "code": "cou", "name": "Court governed", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.903+00:00", "updatedDate": "2025-05-16T18:12:33.903+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
867f3d13-779a-454e-8a06-a1b9fb37ba2a	{"id": "867f3d13-779a-454e-8a06-a1b9fb37ba2a", "code": "scr", "name": "Scribe", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.911+00:00", "updatedDate": "2025-05-16T18:12:33.911+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
02c1c664-1d71-4f7b-a656-1abf1209848f	{"id": "02c1c664-1d71-4f7b-a656-1abf1209848f", "code": "prt", "name": "Printer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.919+00:00", "updatedDate": "2025-05-16T18:12:33.919+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
300171aa-95e1-45b0-86c6-2855fcaf9ef4	{"id": "300171aa-95e1-45b0-86c6-2855fcaf9ef4", "code": "opn", "name": "Opponent", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.927+00:00", "updatedDate": "2025-05-16T18:12:33.927+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7c62ecb4-544c-4c26-8765-f6f6d34031a0	{"id": "7c62ecb4-544c-4c26-8765-f6f6d34031a0", "code": "dpt", "name": "Depositor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.934+00:00", "updatedDate": "2025-05-16T18:12:33.934+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
003e8b5e-426c-4d33-b940-233b1b89dfbd	{"id": "003e8b5e-426c-4d33-b940-233b1b89dfbd", "code": "pan", "name": "Panelist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.943+00:00", "updatedDate": "2025-05-16T18:12:33.943+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
08553068-8495-49c2-9c18-d29ab656fef0	{"id": "08553068-8495-49c2-9c18-d29ab656fef0", "code": "mus", "name": "Musician", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.950+00:00", "updatedDate": "2025-05-16T18:12:33.950+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9d81737c-ec6c-49d8-9771-50e1ab4d7ad7	{"id": "9d81737c-ec6c-49d8-9771-50e1ab4d7ad7", "code": "dtm", "name": "Data manager", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.954+00:00", "updatedDate": "2025-05-16T18:12:33.954+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
245cfa8e-8709-4f1f-969b-894b94bc029f	{"id": "245cfa8e-8709-4f1f-969b-894b94bc029f", "code": "blw", "name": "Blurb writer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.961+00:00", "updatedDate": "2025-05-16T18:12:33.961+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
28f7eb9e-f923-4a77-9755-7571381b2a47	{"id": "28f7eb9e-f923-4a77-9755-7571381b2a47", "code": "ctr", "name": "Contractor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.966+00:00", "updatedDate": "2025-05-16T18:12:33.966+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3bd0b539-4440-4971-988c-5330daa14e3a	{"id": "3bd0b539-4440-4971-988c-5330daa14e3a", "code": "dnc", "name": "Dancer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.973+00:00", "updatedDate": "2025-05-16T18:12:33.973+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c9c3bbe8-d305-48ef-ab2a-5eff941550e3	{"id": "c9c3bbe8-d305-48ef-ab2a-5eff941550e3", "code": "bkp", "name": "Book producer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.981+00:00", "updatedDate": "2025-05-16T18:12:33.981+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fcfc0b86-b083-4ab8-8a75-75a66638ed2e	{"id": "fcfc0b86-b083-4ab8-8a75-75a66638ed2e", "code": "rdd", "name": "Radio director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.853+00:00", "updatedDate": "2025-05-16T18:12:33.853+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
dd44e44e-a153-4ab6-9a7c-f3d23b6c4676	{"id": "dd44e44e-a153-4ab6-9a7c-f3d23b6c4676", "code": "col", "name": "Collector", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.867+00:00", "updatedDate": "2025-05-16T18:12:33.867+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
1ce93f32-3e10-46e2-943f-77f3c8a41d7d	{"id": "1ce93f32-3e10-46e2-943f-77f3c8a41d7d", "code": "vac", "name": "Voice actor", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.876+00:00", "updatedDate": "2025-05-16T18:12:33.876+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
94bb3440-591f-41af-80fa-e124006faa49	{"id": "94bb3440-591f-41af-80fa-e124006faa49", "code": "con", "name": "Conservator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.888+00:00", "updatedDate": "2025-05-16T18:12:33.888+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9fc0bffb-6dd9-4218-9a44-81be4a5059d4	{"id": "9fc0bffb-6dd9-4218-9a44-81be4a5059d4", "code": "cts", "name": "Contestee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.901+00:00", "updatedDate": "2025-05-16T18:12:33.901+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2230246a-1fdb-4f06-a08a-004fd4b929bf	{"id": "2230246a-1fdb-4f06-a08a-004fd4b929bf", "code": "ptf", "name": "Plaintiff", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.914+00:00", "updatedDate": "2025-05-16T18:12:33.914+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e38a0c64-f1d3-4b03-a364-34d6b402841c	{"id": "e38a0c64-f1d3-4b03-a364-34d6b402841c", "code": "ppm", "name": "Papermaker", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.924+00:00", "updatedDate": "2025-05-16T18:12:33.924+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
28de45ae-f0ca-46fe-9f89-283313b3255b	{"id": "28de45ae-f0ca-46fe-9f89-283313b3255b", "code": "abr", "name": "Abridger", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.936+00:00", "updatedDate": "2025-05-16T18:12:33.936+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
acad26a9-e288-4385-bea1-0560bb884b7a	{"id": "acad26a9-e288-4385-bea1-0560bb884b7a", "code": "bjd", "name": "Bookjacket designer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.948+00:00", "updatedDate": "2025-05-16T18:12:33.948+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0d022d0d-902d-4273-8013-0a2a753d9d76	{"id": "0d022d0d-902d-4273-8013-0a2a753d9d76", "code": "rbr", "name": "Rubricator", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.959+00:00", "updatedDate": "2025-05-16T18:12:33.959+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
255be0dd-54d0-4161-9c6c-4d1f58310303	{"id": "255be0dd-54d0-4161-9c6c-4d1f58310303", "code": "ard", "name": "Artistic director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.975+00:00", "updatedDate": "2025-05-16T18:12:33.975+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d32885eb-b82c-4391-abb2-4582c8ee02b3	{"id": "d32885eb-b82c-4391-abb2-4582c8ee02b3", "code": "dpc", "name": "Depicted", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.986+00:00", "updatedDate": "2025-05-16T18:12:33.986+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f72a24d1-f404-4275-9350-158fe3a20b21	{"id": "f72a24d1-f404-4275-9350-158fe3a20b21", "code": "tch", "name": "Teacher", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.998+00:00", "updatedDate": "2025-05-16T18:12:33.998+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9945290f-bcd7-4515-81fd-09e23567b75d	{"id": "9945290f-bcd7-4515-81fd-09e23567b75d", "code": "coe", "name": "Contestant-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.011+00:00", "updatedDate": "2025-05-16T18:12:34.011+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b02cbeb7-8ca7-4bf4-8d58-ce943b4d5ea3	{"id": "b02cbeb7-8ca7-4bf4-8d58-ce943b4d5ea3", "code": "stm", "name": "Stage manager", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.024+00:00", "updatedDate": "2025-05-16T18:12:34.024+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
81bbe282-dca7-4763-bf5a-fe28c8939988	{"id": "81bbe282-dca7-4763-bf5a-fe28c8939988", "code": "pro", "name": "Producer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.037+00:00", "updatedDate": "2025-05-16T18:12:34.037+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b47d8841-112e-43be-b992-eccb5747eb50	{"id": "b47d8841-112e-43be-b992-eccb5747eb50", "code": "prg", "name": "Programmer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.988+00:00", "updatedDate": "2025-05-16T18:12:33.988+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f3aa0070-71bd-4c39-9a9b-ec2fd03ac26d	{"id": "f3aa0070-71bd-4c39-9a9b-ec2fd03ac26d", "code": "cte", "name": "Contestee-appellee", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:33.993+00:00", "updatedDate": "2025-05-16T18:12:33.993+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3cbd0832-328e-48f5-96c4-6f7bcf341461	{"id": "3cbd0832-328e-48f5-96c4-6f7bcf341461", "code": "pmn", "name": "Production manager", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.000+00:00", "updatedDate": "2025-05-16T18:12:34.000+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2576c328-61f1-4684-83cf-4376a66f7731	{"id": "2576c328-61f1-4684-83cf-4376a66f7731", "code": "fld", "name": "Field director", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.005+00:00", "updatedDate": "2025-05-16T18:12:34.005+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c6005151-7005-4ee7-8d6d-a6b72d25377a	{"id": "c6005151-7005-4ee7-8d6d-a6b72d25377a", "code": "vdg", "name": "Videographer", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.013+00:00", "updatedDate": "2025-05-16T18:12:34.013+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ee04a129-f2e4-4fd7-8342-7a73a0700665	{"id": "ee04a129-f2e4-4fd7-8342-7a73a0700665", "code": "mdc", "name": "Metadata contact", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.021+00:00", "updatedDate": "2025-05-16T18:12:34.021+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
036b6349-27c8-4b68-8875-79cb8e0fd459	{"id": "036b6349-27c8-4b68-8875-79cb8e0fd459", "code": "fac", "name": "Facsimilist", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.027+00:00", "updatedDate": "2025-05-16T18:12:34.027+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
12b7418a-0c90-4337-90b7-16d2d3157b68	{"id": "12b7418a-0c90-4337-90b7-16d2d3157b68", "code": "sec", "name": "Secretary", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.034+00:00", "updatedDate": "2025-05-16T18:12:34.034+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
bf1a8165-54bf-411c-a5ea-b6bbbb9c55df	{"id": "bf1a8165-54bf-411c-a5ea-b6bbbb9c55df", "code": "wac", "name": "Writer of added commentary", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.043+00:00", "updatedDate": "2025-05-16T18:12:34.043+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5c1e0a9e-1fdc-47a5-8d06-c12af63cbc5a	{"id": "5c1e0a9e-1fdc-47a5-8d06-c12af63cbc5a", "code": "hnr", "name": "Honoree", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.031+00:00", "updatedDate": "2025-05-16T18:12:34.031+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d5e6972c-9e2f-4788-8dd6-10e859e20945	{"id": "d5e6972c-9e2f-4788-8dd6-10e859e20945", "code": "dbp", "name": "Distribution place", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.039+00:00", "updatedDate": "2025-05-16T18:12:34.039+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8f9d96f5-32ad-43d7-8122-18063a617fc8	{"id": "8f9d96f5-32ad-43d7-8122-18063a617fc8", "code": "cpl", "name": "Complainant", "source": "marcrelator", "metadata": {"createdDate": "2025-05-16T18:12:34.046+00:00", "updatedDate": "2025-05-16T18:12:34.046+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
\.


--
-- Data for Name: electronic_access_relationship; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.electronic_access_relationship (id, jsonb, creation_date, created_by) FROM stdin;
f5d0068e-6272-458e-8a81-b85e7b9a14aa	{"id": "f5d0068e-6272-458e-8a81-b85e7b9a14aa", "name": "Resource", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.207Z", "updatedDate": "2025-05-16T18:12:35.207Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.207	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
3b430592-2e09-4b48-9a0c-0636d66b9fb3	{"id": "3b430592-2e09-4b48-9a0c-0636d66b9fb3", "name": "Version of resource", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.203Z", "updatedDate": "2025-05-16T18:12:35.203Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.203	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
ef03d582-219c-4221-8635-bc92f1107021	{"id": "ef03d582-219c-4221-8635-bc92f1107021", "name": "No display constant generated", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.209Z", "updatedDate": "2025-05-16T18:12:35.209Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.209	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5bfe1b7b-f151-4501-8cfa-23b321d5cd1e	{"id": "5bfe1b7b-f151-4501-8cfa-23b321d5cd1e", "name": "Related resource", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.207Z", "updatedDate": "2025-05-16T18:12:35.207Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.207	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
f50c90c9-bae0-4add-9cd0-db9092dbc9dd	{"id": "f50c90c9-bae0-4add-9cd0-db9092dbc9dd", "name": "No information provided", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.210Z", "updatedDate": "2025-05-16T18:12:35.210Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.21	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: holdings_note_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.holdings_note_type (id, jsonb, creation_date, created_by) FROM stdin;
e19eabab-a85c-4aef-a7b2-33bd9acef24e	{"id": "e19eabab-a85c-4aef-a7b2-33bd9acef24e", "name": "Binding", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.568Z", "updatedDate": "2025-05-16T18:12:35.568Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.568	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
88914775-f677-4759-b57b-1a33b90b24e0	{"id": "88914775-f677-4759-b57b-1a33b90b24e0", "name": "Electronic bookplate", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.567Z", "updatedDate": "2025-05-16T18:12:35.567Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.567	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c4407cc7-d79f-4609-95bd-1cefb2e2b5c5	{"id": "c4407cc7-d79f-4609-95bd-1cefb2e2b5c5", "name": "Copy note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.574Z", "updatedDate": "2025-05-16T18:12:35.574Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.574	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
db9b4787-95f0-4e78-becf-26748ce6bdeb	{"id": "db9b4787-95f0-4e78-becf-26748ce6bdeb", "name": "Provenance", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.572Z", "updatedDate": "2025-05-16T18:12:35.572Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.572	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
d6510242-5ec3-42ed-b593-3585d2e48fd6	{"id": "d6510242-5ec3-42ed-b593-3585d2e48fd6", "name": "Action note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.576Z", "updatedDate": "2025-05-16T18:12:35.576Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.576	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b160f13a-ddba-4053-b9c4-60ec5ea45d56	{"id": "b160f13a-ddba-4053-b9c4-60ec5ea45d56", "name": "Note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.584Z", "updatedDate": "2025-05-16T18:12:35.584Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.584	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
6a41b714-8574-4084-8d64-a9373c3fbb59	{"id": "6a41b714-8574-4084-8d64-a9373c3fbb59", "name": "Reproduction", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.583Z", "updatedDate": "2025-05-16T18:12:35.583Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.583	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: holdings_record; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.holdings_record (id, jsonb, creation_date, created_by, instanceid, permanentlocationid, temporarylocationid, effectivelocationid, holdingstypeid, callnumbertypeid, illpolicyid, sourceid) FROM stdin;
c4a15834-0184-4a6f-9c0c-0ca5bad8286d	{"id": "c4a15834-0184-4a6f-9c0c-0ca5bad8286d", "hrid": "hold000000000001", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.319Z", "updatedDate": "2025-05-16T18:12:36.319Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "K1 .M44", "instanceId": "69640328-788e-43fc-9c3c-af39e243f3b7", "electronicAccess": [{"uri": "https://search.proquest.com/publication/1396348", "publicNote": "via ProQuest, the last 12 months are not available due to an embargo", "relationshipId": "f5d0068e-6272-458e-8a81-b85e7b9a14aa", "materialsSpecification": "1.2012 -"}, {"uri": "https://www.emeraldinsight.com/loi/jepp", "publicNote": "via Emerald", "relationshipId": "f5d0068e-6272-458e-8a81-b85e7b9a14aa", "materialsSpecification": "1.2012 -"}, {"uri": "https://www.emeraldinsight.com/journal/jepp", "publicNote": "via Emerald, national license", "relationshipId": "f5d0068e-6272-458e-8a81-b85e7b9a14aa", "materialsSpecification": "1.2012 - 5.2016"}], "holdingsStatements": [{"statement": "1.2012 -"}], "statisticalCodeIds": [], "administrativeNotes": ["cataloging note"], "effectiveLocationId": "53cf956f-c1df-410b-8bea-27f712cca7c0", "permanentLocationId": "53cf956f-c1df-410b-8bea-27f712cca7c0", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.319	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	69640328-788e-43fc-9c3c-af39e243f3b7	53cf956f-c1df-410b-8bea-27f712cca7c0	\N	53cf956f-c1df-410b-8bea-27f712cca7c0	\N	\N	\N	\N
e6d7e91a-4dbc-4a70-9b38-e000d2fbdc79	{"id": "e6d7e91a-4dbc-4a70-9b38-e000d2fbdc79", "hrid": "hold000000000010", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.317Z", "updatedDate": "2025-05-16T18:12:36.317Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "some-callnumber", "instanceId": "cf23adf0-61ba-4887-bf82-956c4aae2260", "electronicAccess": [], "holdingsStatements": [{"statement": "Line 1b"}, {"statement": "Line 2b"}], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.317	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	cf23adf0-61ba-4887-bf82-956c4aae2260	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	\N
0c45bb50-7c9b-48b0-86eb-178a494e25fe	{"id": "0c45bb50-7c9b-48b0-86eb-178a494e25fe", "hrid": "hold000000000002", "notes": [{"note": " Subscription cancelled per Evans Current Periodicals Selector Review. acq", "staffOnly": true, "holdingsNoteTypeId": "b160f13a-ddba-4053-b9c4-60ec5ea45d56"}, {"note": "Asked Ebsco to check with publisher and ask what years were paid since we are missing (2001:Oct.-Dec.), (All of 2002), & (2003:Jan.-Feb.). 20030305. evaldez", "staffOnly": false, "holdingsNoteTypeId": "b160f13a-ddba-4053-b9c4-60ec5ea45d56"}, {"note": "Backorder:v.87(2001:Oct.-Dec)-v.88(2002). eluza", "staffOnly": false, "holdingsNoteTypeId": "b160f13a-ddba-4053-b9c4-60ec5ea45d56"}, {"note": "WITH 2010 TREAT ISSUE S AS DISCARDS. dgill", "staffOnly": false, "holdingsNoteTypeId": "b160f13a-ddba-4053-b9c4-60ec5ea45d56"}], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.301Z", "updatedDate": "2025-05-16T18:12:36.301Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": ["ABW4508", "442882"], "callNumber": "K1 .M44", "copyNumber": "1", "instanceId": "69640328-788e-43fc-9c3c-af39e243f3b7", "receiptStatus": "Not currently received", "retentionPolicy": "Permanently retained.", "electronicAccess": [{"uri": "http://www.ebscohost.com", "relationshipId": "3b430592-2e09-4b48-9a0c-0636d66b9fb3", "materialsSpecification": "1984-"}, {"uri": "http://www.jstor.com", "publicNote": "Most recent 4 years not available.", "relationshipId": "3b430592-2e09-4b48-9a0c-0636d66b9fb3", "materialsSpecification": "1984-"}], "acquisitionMethod": "Purchase", "holdingsStatements": [{"statement": "v.70-84 (1984-1998)"}, {"statement": "v.85:no. 1-11 (1999:Jan.-Nov.)"}, {"statement": "v.87:no.1-9 (2001:Jan.-Sept.)"}, {"statement": "v.89:no.2-12 (2003:Feb.-Dec.)"}, {"statement": "v.90-95 (2004-2009)"}], "statisticalCodeIds": ["775b6ad4-9c35-4d29-bf78-8775a9b42226"], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": [{"statement": "no.1-23 "}]}	2025-05-16 18:12:36.301	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	69640328-788e-43fc-9c3c-af39e243f3b7	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	\N
fb7b70f1-b898-4924-a991-0e4b6312bb5f	{"id": "fb7b70f1-b898-4924-a991-0e4b6312bb5f", "hrid": "hold000000000005", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.334Z", "updatedDate": "2025-05-16T18:12:36.334Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "PR6056.I4588 B749 2016", "instanceId": "7fbd5d84-62d1-44c6-9c45-6cb173998bbd", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "53cf956f-c1df-410b-8bea-27f712cca7c0", "permanentLocationId": "53cf956f-c1df-410b-8bea-27f712cca7c0", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.334	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	7fbd5d84-62d1-44c6-9c45-6cb173998bbd	53cf956f-c1df-410b-8bea-27f712cca7c0	\N	53cf956f-c1df-410b-8bea-27f712cca7c0	\N	\N	\N	\N
65032151-39a5-4cef-8810-5350eb316300	{"id": "65032151-39a5-4cef-8810-5350eb316300", "hrid": "hold000000000006", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.345Z", "updatedDate": "2025-05-16T18:12:36.345Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "MCN FICTION", "instanceId": "f31a36de-fcf8-44f9-87ef-a55d06ad21ae", "electronicAccess": [], "holdingsStatements": [{"statement": "Line 1b"}, {"statement": "Line 2b"}], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "b241764c-1466-4e1d-a028-1a3684a5da87", "permanentLocationId": "b241764c-1466-4e1d-a028-1a3684a5da87", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.345	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	f31a36de-fcf8-44f9-87ef-a55d06ad21ae	b241764c-1466-4e1d-a028-1a3684a5da87	\N	b241764c-1466-4e1d-a028-1a3684a5da87	\N	\N	\N	\N
67cd0046-e4f1-4e4f-9024-adf0b0039d09	{"id": "67cd0046-e4f1-4e4f-9024-adf0b0039d09", "hrid": "hold000000000007", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.359Z", "updatedDate": "2025-05-16T18:12:36.359Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "D15.H63 A3 2002", "instanceId": "a89eccf0-57a6-495e-898d-32b9b2210f2f", "electronicAccess": [], "holdingsStatements": [{"statement": "Line 1b"}, {"statement": "Line 2b"}], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "f34d27c6-a8eb-461b-acd6-5dea81771e70", "permanentLocationId": "f34d27c6-a8eb-461b-acd6-5dea81771e70", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.359	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	a89eccf0-57a6-495e-898d-32b9b2210f2f	f34d27c6-a8eb-461b-acd6-5dea81771e70	\N	f34d27c6-a8eb-461b-acd6-5dea81771e70	\N	\N	\N	\N
65cb2bf0-d4c2-4886-8ad0-b76f1ba75d61	{"id": "65cb2bf0-d4c2-4886-8ad0-b76f1ba75d61", "hrid": "hold000000000004", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.369Z", "updatedDate": "2025-05-16T18:12:36.369Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "PR6056.I4588 B749 2016", "instanceId": "7fbd5d84-62d1-44c6-9c45-6cb173998bbd", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.369	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	7fbd5d84-62d1-44c6-9c45-6cb173998bbd	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	\N
133a7916-f05e-4df4-8f7f-09eb2a7076d1	{"id": "133a7916-f05e-4df4-8f7f-09eb2a7076d1", "hrid": "hold000000000003", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.391Z", "updatedDate": "2025-05-16T18:12:36.391Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "R11.A38", "instanceId": "30fcc8e7-a019-43f4-b642-2edc389f4501", "electronicAccess": [], "holdingsStatements": [{"statement": "v1-128, July 1946-December 2016"}], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.391	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	30fcc8e7-a019-43f4-b642-2edc389f4501	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	\N
247f1832-88be-4a84-9638-605ffde308b3	{"id": "247f1832-88be-4a84-9638-605ffde308b3", "hrid": "BW-2", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.708Z", "updatedDate": "2025-05-16T18:12:36.708Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "1958 A 8050", "instanceId": "85010f04-b914-4ac7-ba30-be2b52f79708", "holdingsTypeId": "0c422f92-0f4d-4d32-8cbe-390ebc33a3e5", "callNumberPrefix": "A", "callNumberTypeId": "6caca63e-5651-4db6-9247-3205156e9699", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.708	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	85010f04-b914-4ac7-ba30-be2b52f79708	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	0c422f92-0f4d-4d32-8cbe-390ebc33a3e5	6caca63e-5651-4db6-9247-3205156e9699	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
7a2443bc-fe66-40d5-9400-9a800fdf013e	{"id": "7a2443bc-fe66-40d5-9400-9a800fdf013e", "hrid": "bwhol0010", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.887Z", "updatedDate": "2025-05-16T18:12:36.887Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "Holdings magazine Q1", "instanceId": "28d36163-0425-4452-b1f8-1dc4467c52b1", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.887	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	28d36163-0425-4452-b1f8-1dc4467c52b1	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
55f48dc6-efa7-4cfe-bc7c-4786efe493e3	{"id": "55f48dc6-efa7-4cfe-bc7c-4786efe493e3", "hrid": "hold000000000012", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.357Z", "updatedDate": "2025-05-16T18:12:36.357Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "instanceId": "bbd4a5e1-c9f3-44b9-bfdf-d184e04f0ba0", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "f34d27c6-a8eb-461b-acd6-5dea81771e70", "permanentLocationId": "f34d27c6-a8eb-461b-acd6-5dea81771e70", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.357	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	bbd4a5e1-c9f3-44b9-bfdf-d184e04f0ba0	f34d27c6-a8eb-461b-acd6-5dea81771e70	\N	f34d27c6-a8eb-461b-acd6-5dea81771e70	\N	\N	\N	\N
68872d8a-bf16-420b-829f-206da38f6c10	{"id": "68872d8a-bf16-420b-829f-206da38f6c10", "hrid": "hold000000000008", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.393Z", "updatedDate": "2025-05-16T18:12:36.393Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "some-callnumber", "instanceId": "6506b79b-7702-48b2-9774-a1c538fdd34e", "electronicAccess": [], "holdingsStatements": [{"statement": "Line 1b"}, {"statement": "Line 2b"}], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.393	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	6506b79b-7702-48b2-9774-a1c538fdd34e	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	\N
13767c78-f8d0-425e-801d-cc5bd475856a	{"id": "13767c78-f8d0-425e-801d-cc5bd475856a", "hrid": "bwho000000001", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.710Z", "updatedDate": "2025-05-16T18:12:36.710Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "DE3", "instanceId": "ce9dd893-c812-49d5-8973-d55d018894c4", "holdingsTypeId": "03c9c400-b9e3-4a07-ac0e-05ab470233ed", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.71	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	ce9dd893-c812-49d5-8973-d55d018894c4	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	03c9c400-b9e3-4a07-ac0e-05ab470233ed	\N	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
7af9a14d-6e92-4827-acab-eba65e08be6c	{"id": "7af9a14d-6e92-4827-acab-eba65e08be6c", "hrid": "bwhol0011", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.889Z", "updatedDate": "2025-05-16T18:12:36.889Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "Holdings magazine Q2", "instanceId": "858b9600-bd76-44ff-a83e-f82dcf5ed12b", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.889	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	858b9600-bd76-44ff-a83e-f82dcf5ed12b	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
e9285a1c-1dfc-4380-868c-e74073003f43	{"id": "e9285a1c-1dfc-4380-868c-e74073003f43", "hrid": "hold000000000011", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.374Z", "updatedDate": "2025-05-16T18:12:36.374Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "M1366.S67 T73 2017", "instanceId": "e54b1f4d-7d05-4b1a-9368-3c36b75d8ac6", "electronicAccess": [], "holdingsStatements": [{"statement": "Line 1b"}, {"statement": "Line 2b"}], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.374	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e54b1f4d-7d05-4b1a-9368-3c36b75d8ac6	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	\N
9e8dc8ce-68f3-4e75-8479-d548ce521157	{"id": "9e8dc8ce-68f3-4e75-8479-d548ce521157", "hrid": "BW-1", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.713Z", "updatedDate": "2025-05-16T18:12:36.713Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "1958 A 8050", "instanceId": "ce9dd893-c812-49d5-8973-d55d018894c4", "holdingsTypeId": "0c422f92-0f4d-4d32-8cbe-390ebc33a3e5", "callNumberPrefix": "A", "callNumberTypeId": "6caca63e-5651-4db6-9247-3205156e9699", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.713	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	ce9dd893-c812-49d5-8973-d55d018894c4	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	0c422f92-0f4d-4d32-8cbe-390ebc33a3e5	6caca63e-5651-4db6-9247-3205156e9699	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
1ab1f67e-6ab8-40f0-8cc1-a199db309070	{"id": "1ab1f67e-6ab8-40f0-8cc1-a199db309070", "hrid": "bwhol0013", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.891Z", "updatedDate": "2025-05-16T18:12:36.891Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "Holdings magazine Q4", "instanceId": "2b0312ca-2f57-494f-9fdb-aa13339b8049", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.891	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	2b0312ca-2f57-494f-9fdb-aa13339b8049	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
e3ff6133-b9a2-4d4c-a1c9-dc1867d4df19	{"id": "e3ff6133-b9a2-4d4c-a1c9-dc1867d4df19", "hrid": "hold000000000009", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.377Z", "updatedDate": "2025-05-16T18:12:36.377Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "callNumber": "TK5105.88815 . A58 2004 FT MEADE", "instanceId": "5bf370e0-8cca-4d9c-82e4-5170ab2a0a39", "illPolicyId": "46970b40-918e-47a4-a45d-b1677a2d3d46", "shelvingTitle": " TK5105.88815", "holdingsTypeId": "03c9c400-b9e3-4a07-ac0e-05ab470233ed", "callNumberTypeId": "512173a7-bd09-490e-b773-17d83f2b63fe", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": ["b5968c9e-cddc-4576-99e3-8e60aed8b0dd"], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.377	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	5bf370e0-8cca-4d9c-82e4-5170ab2a0a39	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	03c9c400-b9e3-4a07-ac0e-05ab470233ed	512173a7-bd09-490e-b773-17d83f2b63fe	46970b40-918e-47a4-a45d-b1677a2d3d46	\N
704ea4ec-456c-4740-852b-0814d59f7d21	{"id": "704ea4ec-456c-4740-852b-0814d59f7d21", "hrid": "BW-3", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.712Z", "updatedDate": "2025-05-16T18:12:36.712Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "1958 A 8050", "instanceId": "cd3288a4-898c-4347-a003-2d810ef70f03", "holdingsTypeId": "0c422f92-0f4d-4d32-8cbe-390ebc33a3e5", "callNumberPrefix": "A", "callNumberTypeId": "6caca63e-5651-4db6-9247-3205156e9699", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.712	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	cd3288a4-898c-4347-a003-2d810ef70f03	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	0c422f92-0f4d-4d32-8cbe-390ebc33a3e5	6caca63e-5651-4db6-9247-3205156e9699	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
7fd55f10-6aec-4e25-a3cd-9ac7412ca26a	{"id": "7fd55f10-6aec-4e25-a3cd-9ac7412ca26a", "hrid": "bwhol0012", "notes": [], "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.890Z", "updatedDate": "2025-05-16T18:12:36.890Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "sourceId": "f32d531e-df79-46b3-8932-cdd35f7a2264", "formerIds": [], "callNumber": "Holdings magazine Q3", "instanceId": "87d0c31e-a466-4deb-9348-7fea0f68bc22", "electronicAccess": [], "holdingsStatements": [], "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "holdingsStatementsForIndexes": [], "holdingsStatementsForSupplements": []}	2025-05-16 18:12:36.89	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	87d0c31e-a466-4deb-9348-7fea0f68bc22	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	\N	\N	f32d531e-df79-46b3-8932-cdd35f7a2264
\.


--
-- Data for Name: holdings_records_source; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.holdings_records_source (id, jsonb, creation_date, created_by) FROM stdin;
f32d531e-df79-46b3-8932-cdd35f7a2264	{"id": "f32d531e-df79-46b3-8932-cdd35f7a2264", "name": "FOLIO", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.681Z", "updatedDate": "2025-05-16T18:12:35.681Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.681	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
036ee84a-6afd-4c3c-9ad3-4a12ab875f59	{"id": "036ee84a-6afd-4c3c-9ad3-4a12ab875f59", "name": "MARC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.683Z", "updatedDate": "2025-05-16T18:12:35.683Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.683	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: holdings_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.holdings_type (id, jsonb, creation_date, created_by) FROM stdin;
03c9c400-b9e3-4a07-ac0e-05ab470233ed	{"id": "03c9c400-b9e3-4a07-ac0e-05ab470233ed", "name": "Monograph", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.316Z", "updatedDate": "2025-05-16T18:12:35.316Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.316	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
0c422f92-0f4d-4d32-8cbe-390ebc33a3e5	{"id": "0c422f92-0f4d-4d32-8cbe-390ebc33a3e5", "name": "Physical", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.323Z", "updatedDate": "2025-05-16T18:12:35.323Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.323	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
996f93e2-5b5e-4cf2-9168-33ced1f95eed	{"id": "996f93e2-5b5e-4cf2-9168-33ced1f95eed", "name": "Electronic", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.320Z", "updatedDate": "2025-05-16T18:12:35.320Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.32	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
e6da6c98-6dd0-41bc-8b4b-cfd4bbd9c3ae	{"id": "e6da6c98-6dd0-41bc-8b4b-cfd4bbd9c3ae", "name": "Serial", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.321Z", "updatedDate": "2025-05-16T18:12:35.321Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.321	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
dc35d0ae-e877-488b-8e97-6e41444e6d0a	{"id": "dc35d0ae-e877-488b-8e97-6e41444e6d0a", "name": "Multi-part monograph", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.321Z", "updatedDate": "2025-05-16T18:12:35.321Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.321	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: hrid_settings; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

COPY quesnelia_mod_inventory_storage.hrid_settings (id, jsonb, creation_date, created_by, lock) FROM stdin;
a501f2a8-5b31-48b2-874d-2191e48db8cd	{"id": "a501f2a8-5b31-48b2-874d-2191e48db8cd", "items": {"prefix": "it", "startNumber": 1}, "holdings": {"prefix": "ho", "startNumber": 1}, "metadata": {"createdDate": "2025-05-16T18:12:31.784Z", "updatedDate": "2025-05-16T18:12:31.788Z", "createdByUserId": "00000000-0000-0000-0000-000000000000", "updatedByUserId": "00000000-0000-0000-0000-000000000000"}, "instances": {"prefix": "in", "startNumber": 1}, "commonRetainLeadingZeroes": true}	2025-05-16 18:12:31.784918	00000000-0000-0000-0000-000000000000	t
\.


--
-- Data for Name: identifier_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.identifier_type (id, jsonb, creation_date, created_by) FROM stdin;
2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5	{"id": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5", "name": "Other standard identifier", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.399Z", "updatedDate": "2025-05-16T18:12:32.399Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.399	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5d164f4b-0b15-4e42-ae75-cfcf85318ad9	{"id": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9", "name": "Control number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.403Z", "updatedDate": "2025-05-16T18:12:32.403Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.403	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
650ef996-35e3-48ec-bf3a-a0d078a0ca37	{"id": "650ef996-35e3-48ec-bf3a-a0d078a0ca37", "name": "UkMac", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.401Z", "updatedDate": "2025-05-16T18:12:32.401Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.401	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b5d8cdc4-9441-487c-90cf-0c7ec97728eb	{"id": "b5d8cdc4-9441-487c-90cf-0c7ec97728eb", "name": "Publisher or distributor number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.404Z", "updatedDate": "2025-05-16T18:12:32.404Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.404	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
7e591197-f335-4afb-bc6d-a6d76ca3bace	{"id": "7e591197-f335-4afb-bc6d-a6d76ca3bace", "name": "System control number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.407Z", "updatedDate": "2025-05-16T18:12:32.407Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.407	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
8261054f-be78-422d-bd51-4ed9f33c3422	{"id": "8261054f-be78-422d-bd51-4ed9f33c3422", "name": "ISBN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.429Z", "updatedDate": "2025-05-16T18:12:32.429Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.429	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c858e4f2-2b6b-4385-842b-60532ee34abb	{"id": "c858e4f2-2b6b-4385-842b-60532ee34abb", "name": "Cancelled LCCN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.427+00:00", "updatedDate": "2025-05-16T18:12:32.427+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	\N	\N
5069054d-bc3a-4212-a4e8-e2013a02386f	{"id": "5069054d-bc3a-4212-a4e8-e2013a02386f", "name": "Cancelled GPO item number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.431Z", "updatedDate": "2025-05-16T18:12:32.431Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.431	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
fc4e3f2a-887a-46e5-8057-aeeb271a4e56	{"id": "fc4e3f2a-887a-46e5-8057-aeeb271a4e56", "name": "Cancelled system control number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.441+00:00", "updatedDate": "2025-05-16T18:12:32.441+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	\N	\N
ebfd00b6-61d3-4d87-a6d8-810c941176d5	{"id": "ebfd00b6-61d3-4d87-a6d8-810c941176d5", "name": "ISMN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.438+00:00", "updatedDate": "2025-05-16T18:12:32.438+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	\N	\N
7f907515-a1bf-4513-8a38-92e1a07c539d	{"id": "7f907515-a1bf-4513-8a38-92e1a07c539d", "name": "ASIN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.454Z", "updatedDate": "2025-05-16T18:12:32.454Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.454	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
3fbacad6-0240-4823-bce8-bb122cfdf229	{"id": "3fbacad6-0240-4823-bce8-bb122cfdf229", "name": "StEdNL", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.455Z", "updatedDate": "2025-05-16T18:12:32.455Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.455	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
1795ea23-6856-48a5-a772-f356e16a8a6c	{"id": "1795ea23-6856-48a5-a772-f356e16a8a6c", "name": "UPC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.465+00:00", "updatedDate": "2025-05-16T18:12:32.465+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	\N	\N
593b78cb-32f3-44d1-ba8c-63fd5e6989e6	{"id": "593b78cb-32f3-44d1-ba8c-63fd5e6989e6", "name": "CODEN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.466Z", "updatedDate": "2025-05-16T18:12:32.466Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.466	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5860f255-a27f-4916-a830-262aa900a6b9	{"id": "5860f255-a27f-4916-a830-262aa900a6b9", "name": "Linking ISSN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.460Z", "updatedDate": "2025-05-16T18:12:32.460Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.46	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
37b65e79-0392-450d-adc6-e2a1f47de452	{"id": "37b65e79-0392-450d-adc6-e2a1f47de452", "name": "Report number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.471Z", "updatedDate": "2025-05-16T18:12:32.471Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.471	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
4f07ea37-6c7f-4836-add2-14249e628ed1	{"id": "4f07ea37-6c7f-4836-add2-14249e628ed1", "name": "Invalid ISMN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.475+00:00", "updatedDate": "2025-05-16T18:12:32.475+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	\N	\N
351ebc1c-3aae-4825-8765-c6d50dbf011f	{"id": "351ebc1c-3aae-4825-8765-c6d50dbf011f", "name": "GPO item number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.483Z", "updatedDate": "2025-05-16T18:12:32.483Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.483	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b3ea81fb-3324-4c64-9efc-7c0c93d5943c	{"id": "b3ea81fb-3324-4c64-9efc-7c0c93d5943c", "name": "Invalid UPC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.479+00:00", "updatedDate": "2025-05-16T18:12:32.479+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	\N	\N
27fd35a6-b8f6-41f2-aa0e-9c663ceb250c	{"id": "27fd35a6-b8f6-41f2-aa0e-9c663ceb250c", "name": "Invalid ISSN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.485Z", "updatedDate": "2025-05-16T18:12:32.485Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.485	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
eb7b2717-f149-4fec-81a3-deefb8f5ee6b	{"id": "eb7b2717-f149-4fec-81a3-deefb8f5ee6b", "name": "URN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.501Z", "updatedDate": "2025-05-16T18:12:32.501Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.501	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5130aed5-1095-4fb6-8f6f-caa3d6cc7aae	{"id": "5130aed5-1095-4fb6-8f6f-caa3d6cc7aae", "name": "Local identifier", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.524Z", "updatedDate": "2025-05-16T18:12:32.524Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.524	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
39554f54-d0bb-4f0a-89a4-e422f6136316	{"id": "39554f54-d0bb-4f0a-89a4-e422f6136316", "name": "DOI", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.493Z", "updatedDate": "2025-05-16T18:12:32.493Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.493	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c858e4f2-2b6b-4385-842b-60732ee14abb	{"id": "c858e4f2-2b6b-4385-842b-60732ee14abb", "name": "LCCN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.506Z", "updatedDate": "2025-05-16T18:12:32.506Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.506	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
fcca2643-406a-482a-b760-7a7f8aec640e	{"id": "fcca2643-406a-482a-b760-7a7f8aec640e", "name": "Invalid ISBN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.514Z", "updatedDate": "2025-05-16T18:12:32.514Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.514	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
913300b2-03ed-469a-8179-c1092c991227	{"id": "913300b2-03ed-469a-8179-c1092c991227", "name": "ISSN", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.522Z", "updatedDate": "2025-05-16T18:12:32.522Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.522	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
8e3dd25e-db82-4b06-8311-90d41998c109	{"id": "8e3dd25e-db82-4b06-8311-90d41998c109", "name": "Standard technical report number", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.496Z", "updatedDate": "2025-05-16T18:12:32.496Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.496	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
3187432f-9434-40a8-8782-35a111a1491e	{"id": "3187432f-9434-40a8-8782-35a111a1491e", "name": "BNB", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.518Z", "updatedDate": "2025-05-16T18:12:32.518Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.518	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
439bfbae-75bc-4f74-9fc7-b2a2d47ce3ef	{"id": "439bfbae-75bc-4f74-9fc7-b2a2d47ce3ef", "name": "OCLC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.498Z", "updatedDate": "2025-05-16T18:12:32.498Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.498	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
216b156b-215e-4839-a53e-ade35cb5702a	{"id": "216b156b-215e-4839-a53e-ade35cb5702a", "name": "Handle", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.519Z", "updatedDate": "2025-05-16T18:12:32.519Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.519	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: ill_policy; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.ill_policy (id, jsonb, creation_date, created_by) FROM stdin;
37fc2702-7ec9-482a-a4e3-5ed9a122ece1	{"id": "37fc2702-7ec9-482a-a4e3-5ed9a122ece1", "name": "Unknown lending policy", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.260Z", "updatedDate": "2025-05-16T18:12:35.260Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.26	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c51f7aa9-9997-45e6-94d6-b502445aae9d	{"id": "c51f7aa9-9997-45e6-94d6-b502445aae9d", "name": "Unknown reproduction policy", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.263Z", "updatedDate": "2025-05-16T18:12:35.263Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.263	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9e49924b-f649-4b36-ab57-e66e639a9b0e	{"id": "9e49924b-f649-4b36-ab57-e66e639a9b0e", "name": "Limited lending policy", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.270Z", "updatedDate": "2025-05-16T18:12:35.270Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.27	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
6bc6a71f-d6e2-4693-87f1-f495afddff00	{"id": "6bc6a71f-d6e2-4693-87f1-f495afddff00", "name": "Will not reproduce", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.280Z", "updatedDate": "2025-05-16T18:12:35.280Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.28	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
46970b40-918e-47a4-a45d-b1677a2d3d46	{"id": "46970b40-918e-47a4-a45d-b1677a2d3d46", "name": "Will lend", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.271Z", "updatedDate": "2025-05-16T18:12:35.271Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.271	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2b870182-a23d-48e8-917d-9421e5c3ce13	{"id": "2b870182-a23d-48e8-917d-9421e5c3ce13", "name": "Will lend hard copy only", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.285Z", "updatedDate": "2025-05-16T18:12:35.285Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.285	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b0f97013-87f5-4bab-87f2-ac4a5191b489	{"id": "b0f97013-87f5-4bab-87f2-ac4a5191b489", "name": "Will not lend", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.287Z", "updatedDate": "2025-05-16T18:12:35.287Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.287	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2a572e7b-dfe5-4dee-8a62-b98d26a802e6	{"id": "2a572e7b-dfe5-4dee-8a62-b98d26a802e6", "name": "Will reproduce", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.286Z", "updatedDate": "2025-05-16T18:12:35.286Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.286	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: instance; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance (id, jsonb, creation_date, created_by, instancestatusid, modeofissuanceid, instancetypeid, complete_updated_date) FROM stdin;
e6bc03c6-c137-4221-b679-a7c5c31f986c	{"id": "e6bc03c6-c137-4221-b679-a7c5c31f986c", "hrid": "inst000000000027", "notes": [], "title": "Organisations- und Prozessentwicklung Harald Augustin (Hrsg.)", "series": [{"value": "Umsetzung der DIN EN ISO 9001:2015  / Harald Augustin (Hrsg.) ; Band 1"}, {"value": "Berichte aus der Betriebswirtschaft"}, {"value": "Umsetzung der DIN EN ISO 9001:2015 Band 1"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:35.990Z", "updatedDate": "2025-05-16T18:12:35.990Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "DIN EN ISO 9001:2015"}, {"value": "Standard"}, {"value": "Organisatorischer Wandel"}, {"value": "Prozessmanagement"}, {"value": "Einführung"}, {"value": "Industrie"}, {"value": "Deutschland"}], "languages": ["ger"], "identifiers": [{"value": "3844057420", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9783844057423", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9783844057423", "identifierTypeId": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5"}, {"value": "(OCoLC)1024095011", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-101)1150175923", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-599)DNB1150175923", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Aachen", "publisher": "Shaker Verlag", "dateOfPublication": "2017"}], "contributors": [{"name": "Augustin, Harald", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Shaker Verlag GmbH", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "658.4013", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}, {"classificationNumber": "650", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [{"uri": "http://d-nb.info/1150175923/04", "linkText": "Electronic resource (PDF)", "publicNote": "Address for accessing the table of content. PDF file"}], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2017}, "statusUpdatedDate": "2025-05-16T18:12:35.991+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["x, 113 Seiten Illustrationen 21 cm, 223 g"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:35.99	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.010082+00
1640f178-f243-4e4a-bf1c-9e1e62b3171d	{"id": "1640f178-f243-4e4a-bf1c-9e1e62b3171d", "hrid": "inst000000000005", "notes": [{"note": "Enthält 9 Beiträge", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "Futures, biometrics and neuroscience research Luiz Moutinho, Mladen Sokele, editors", "series": [{"value": "Innovative research methodologies in management  / Luiz Moutinho, Mladen Sokele ; Volume 2"}, {"value": "Innovative research methodologies in management Volume 2"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.013Z", "updatedDate": "2025-05-16T18:12:36.013Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Betriebswirtschaftslehre"}, {"value": "Management"}, {"value": "Wissenschaftliche Methode"}], "languages": ["eng"], "identifiers": [{"value": "101073931X", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "3319643991", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9783319643991", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9783319644004", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "(OCoLC)ocn992783736", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(OCoLC)992783736", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-599)GBV101073931X", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Cham", "publisher": "Palgrave Macmillan", "dateOfPublication": "[2018]"}], "contributors": [{"name": "Moutinho, Luiz", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Sokele, Mladen", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [{"uri": "http://www.gbv.de/dms/zbw/101073931X.pdf", "linkText": "Electronic resource (PDF)", "publicNote": "Address for accessing the table of content. PDF file"}], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2018}, "statusUpdatedDate": "2025-05-16T18:12:36.014+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["xxix, 224 Seiten Illustrationen"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.013	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.018523+00
5b1eb450-ff9f-412d-a9e7-887f6eaeb5b4	{"id": "5b1eb450-ff9f-412d-a9e7-887f6eaeb5b4", "hrid": "inst000000000010", "notes": [{"note": "Dissertation New York University 1993", "staffOnly": false}, {"note": "Mikrofiche-Ausgabe", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "Concepts of fashion 1921 - 1987 microform a study of garments worn by selected winners of the Miss America Pageant Marian Ann J. Matwiejczyk-Montgomery", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.017Z", "updatedDate": "2025-05-16T18:12:36.017Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Hochschulschrift"}], "languages": ["eng"], "identifiers": [{"value": "1008673218", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "(DE-599)GBV1008673218", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Ann Arbor, MI", "publisher": "University Microfims International", "dateOfPublication": "1993"}], "contributors": [{"name": "Matwiejczyk-Montgomery, Marian Ann J", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 1993}, "statusUpdatedDate": "2025-05-16T18:12:36.017+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.017	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.026771+00
e54b1f4d-7d05-4b1a-9368-3c36b75d8ac6	{"id": "e54b1f4d-7d05-4b1a-9368-3c36b75d8ac6", "hrid": "inst000000000025", "notes": [{"note": "Title from disc label.", "staffOnly": false}, {"note": "All compositions written by Omar Sosa and Seckou Keita, except tracks 6, 8 and 10 written by Omar Sosa.", "staffOnly": false}, {"note": "Produced by Steve Argüelles and Omar Sosa.", "staffOnly": false}, {"note": "Omar Sosa, grand piano, Fender Rhodes, sampler, microKorg, vocals ; Seckou Keita, kora, talking drum, djembe, sabar, vocals ; Wu Tong, sheng, bawu ; Mieko Miyazaki, koto ; Gustavo Ovalles, bata drums, culo'e puya, maracas, guataca, calabaza, clave ; E'Joung-Ju, geojungo ; Mosin Khan Kawa, nagadi ; Dominique Huchet, bird effects.", "staffOnly": false}], "title": "Transparent water", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:35.996Z", "updatedDate": "2025-05-16T18:12:35.996Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "World music."}, {"value": "Jazz"}], "languages": ["und"], "identifiers": [{"value": "ocn968777846", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "9786316800312", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "6316800312", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "OTA-1031 Otá Records", "identifierTypeId": "b5d8cdc4-9441-487c-90cf-0c7ec97728eb"}, {"value": "(OCoLC)968777846", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "[Place of publication not identified]: ", "publisher": "Otá Records, ", "dateOfPublication": "[2017]"}], "contributors": [{"name": "Sosa, Omar", "contributorTypeId": "9f0a2cf0-7a9b-45a2-a403-f68d2850d07c", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Keita, Seckou, 1977-", "contributorTypeId": "9f0a2cf0-7a9b-45a2-a403-f68d2850d07c", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "3be24c14-3551-4180-9292-26a786649c8b", "previouslyHeld": false, "classifications": [{"classificationNumber": "M1366.S67", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": ["5cb91d15-96b1-4b8a-bf60-ec310538da66"], "publicationPeriod": {"start": 2017}, "statusUpdatedDate": "2025-05-16T18:12:35.996+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["1 audio disc: digital; 4 3/4 in."], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:35.996	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	3be24c14-3551-4180-9292-26a786649c8b	2025-05-16 18:12:36.380553+00
1b74ab75-9f41-4837-8662-a1d99118008d	{"id": "1b74ab75-9f41-4837-8662-a1d99118008d", "hrid": "inst000000000018", "notes": [], "title": "A journey through Europe Bildtontraeger high-speed lines European Commission, Directorate-General for Mobility and Transport", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.045Z", "updatedDate": "2025-05-16T18:12:36.045Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Europäische Union"}, {"value": "Hochgeschwindigkeitszug"}, {"value": "Verkehrsnetz"}, {"value": "Hochgeschwindigkeitsverkehr"}, {"value": "Schienenverkehr"}, {"value": "EU-Verkehrspolitik"}, {"value": "EU-Staaten"}], "languages": ["ger", "eng", "spa", "fre", "ita", "dut", "por"], "identifiers": [{"value": "643935371", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "9789279164316", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "10.2768/21035", "identifierTypeId": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5"}, {"value": "MI-32-10-386-57-Z", "identifierTypeId": "b5d8cdc4-9441-487c-90cf-0c7ec97728eb"}, {"value": "(DE-599)GBV643935371", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [], "contributors": [{"name": "Europäische Kommission Generaldirektion Mobilität und Verkehr", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}], "instanceTypeId": "225faa14-f9bf-4ecd-990d-69433c912434", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.045+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["1 DVD-Video (14 Min.) farb. 12 cm"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.045	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	225faa14-f9bf-4ecd-990d-69433c912434	2025-05-16 18:12:36.049668+00
54cc0262-76df-4cac-acca-b10e9bc5c79a	{"id": "54cc0262-76df-4cac-acca-b10e9bc5c79a", "hrid": "inst000000000023", "notes": [], "title": "On the signature of complex system a decomposed approach Gaofeng Da, Ping Shing Chan, Maochao Xu", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.050Z", "updatedDate": "2025-05-16T18:12:36.050Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": ["eng"], "identifiers": [{"value": "1011184508", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "(DE-599)GBV1011184508", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [], "contributors": [{"name": "Da, Gaofeng", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Chan, Ping Shing", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Xu, Maochao", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.050+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.05	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.061837+00
7ab22f0a-c9cd-449a-9137-c76e5055ca37	{"id": "7ab22f0a-c9cd-449a-9137-c76e5055ca37", "hrid": "inst000000000016", "notes": [{"note": "Enthält 16 Beiträge", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "Includes bibliographical references and index", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "Introduction / Mike Odugbo Odey and Toyin Falola -- Part I: Dimensions and assessments of poverty reduction policies and programs in Sub-Saharan Africa -- Poverty in post-colonial Africa: the legacy of contested perspectives / Sati U. Fwatshak -- Scaling up power infrastructure investment in Sub-Saharan Africa for poverty alleviation / Aori R. Nyambati -- The impact of anti-corruption conventions in Sub-Saharan Africa / Daniel Barkley and Claire Maduka -- The besieged continent: interrogating contemporary issues of corruption and poverty in Africa / Idris S. Jimada -- PEPFAR and preventing HIV transmission: evidence from Sub-Saharan Africa / Daniel Barkley and Opeyemi Adeniyi -- Reflections on the current challenges of poverty reduction in Africa / Loveday N. Gbara -- A critical analysis of poverty reduction strategies in post-colonial Africa / Okokhere O. Felix -- Part II: Problems of good governance and institutional failures in West-Africa -- Weaknesses and failures of poverty reduction policies and programs in Nigeria since 1960 / Mike O. Odey -- In the web of neo-liberalism and deepening contradictions? Assessing poverty reform strategies in West Africa since the mid-1980s / Okpeh O. Okpeh, Jr. -- An assessment of abuse of the elderly as an aspect of poverty in Akwa-Ibom State, Nigeria / Ekot O. Mildred -- Reflections on the interface between poverty and food insecurity in Nigeria / Funso A. Adesola -- An appraisal of poverty reduction program in Bayelsa State of Nigeria: \\\\\\"In-Care of the People\\\\\\" (COPE) / Ezi Beedie -- A comparative analysis of incidence of poverty in three urban centers in Ghana from 1945-1990 / Wilhelmina J. Donkoh -- Part III: Dimensions of poverty in east and southern Africa -- Landlessness, national politics, and the future of land reforms in Kenya / Shanguhyia S. Martin -- Extra-version and development in northwestern Ethiopia: the case of the Humera Agricultural Project (1967-1975) / Luca Pudu -- Affirmative action as a theological-pastoral challenge in the south-African democratic context / Elijah M. Baloyi.", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "Poverty reduction strategies in Africa edited by Toyin Falola and Mike Odugbo Odey", "series": [{"value": "Global Africa 3"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.082Z", "updatedDate": "2025-05-16T18:12:36.082Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Poverty--Government policy--Africa, Sub-Saharan"}, {"value": "Armut"}, {"value": "Bekämpfung"}, {"value": "Armutsbekämpfung"}, {"value": "Subsahara-Afrika"}, {"value": "Westafrika"}, {"value": "Africa, Sub-Saharan--Economic conditions--21st century"}, {"value": "Subsaharisches Afrika"}, {"value": "Africa, Sub-Saharan Economic conditions 21st century"}, {"value": "Poverty Government policy Africa, Sub-Saharan"}], "languages": ["eng"], "identifiers": [{"value": "2017004333", "identifierTypeId": "c858e4f2-2b6b-4385-842b-60732ee14abb"}, {"value": "9781138240667", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9781315282978", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "(DE-599)GBV880159367", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "London", "publisher": "Routledge", "dateOfPublication": "2018"}], "contributors": [{"name": "Falola, Toyin", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Odey, Mike Odugbo", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "HV438.A357", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}, {"classificationNumber": "362.50967", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [{"uri": "http://www.gbv.de/dms/zbw/880159367.pdf", "linkText": "Electronic resource (PDF)", "publicNote": "Address for accessing the table of content. PDF file"}], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2018}, "statusUpdatedDate": "2025-05-16T18:12:36.083+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["xiv, 300 Seiten"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.082	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.091283+00
3c4ae3f3-b460-4a89-a2f9-78ce3145e4fc	{"id": "3c4ae3f3-b460-4a89-a2f9-78ce3145e4fc", "hrid": "inst000000000008", "notes": [], "title": "The chess player’s mating guide Computer Datei Robert Ris", "series": [{"value": "Fritztrainer Tactics"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.132Z", "updatedDate": "2025-05-16T18:12:36.132Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "DVD-ROM"}], "languages": ["eng"], "identifiers": [{"value": "858092093", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "(DE-599)GBV858092093", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Hamburg", "publisher": "Chessbase GmbH", "dateOfPublication": "[2016]-"}], "contributors": [{"name": "Ris, Robert", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "ChessBase GmbH Hamburg", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}], "instanceTypeId": "c208544b-9e28-44fa-a13c-f4093d72f798", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2016}, "statusUpdatedDate": "2025-05-16T18:12:36.132+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.132	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	c208544b-9e28-44fa-a13c-f4093d72f798	2025-05-16 18:12:36.137975+00
bbd4a5e1-c9f3-44b9-bfdf-d184e04f0ba0	{"id": "bbd4a5e1-c9f3-44b9-bfdf-d184e04f0ba0", "hrid": "inst000000000029", "notes": [], "title": "Water resources of East Feliciana Parish, Louisiana", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.088Z", "updatedDate": "2025-05-16T18:12:36.088Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [], "publication": [], "contributors": [{"name": "White, Vincent E.", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": ["f5e8210f-7640-459b-a71f-552567f92369"], "statusUpdatedDate": "2025-05-16T18:12:36.089+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.088	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.368771+00
a317b304-528c-424f-961c-39174933b454	{"id": "a317b304-528c-424f-961c-39174933b454", "hrid": "inst000000000026", "notes": [], "title": "Umsetzung der DIN EN ISO 9001:2015 Harald Augustin (Hrsg.)", "series": [{"value": "Berichte aus der Betriebswirtschaft"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.039Z", "updatedDate": "2025-05-16T18:12:36.039Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": ["ger"], "identifiers": [{"value": "(DE-599)GBV101484262X", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Aachen", "publisher": "Shaker Verlag", "dateOfPublication": "2017"}], "contributors": [{"name": "Augustin, Harald", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2017}, "statusUpdatedDate": "2025-05-16T18:12:36.040+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.039	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.04958+00
00f10ab9-d845-4334-92d2-ff55862bf4f9	{"id": "00f10ab9-d845-4334-92d2-ff55862bf4f9", "hrid": "inst000000000002", "notes": [], "title": "American Bar Association journal.", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.124Z", "updatedDate": "2025-05-16T18:12:36.124Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Law--United States--Periodicals"}, {"value": "Advocatuur.--gtt"}, {"value": "Droit--Périodiques"}, {"value": "LAW--unbist"}, {"value": "LAWYERS--unbist"}, {"value": "UNITED STATES--unbist"}, {"value": "Law.--fast"}, {"value": "United States.--fast"}], "languages": ["eng"], "indexTitle": "American Bar Association journal.", "identifiers": [{"value": "15017355", "identifierTypeId": "c858e4f2-2b6b-4385-842b-60732ee14abb"}, {"value": "1964851", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "236213576", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "0002-7596", "identifierTypeId": "913300b2-03ed-469a-8179-c1092c991227"}, {"value": "0002-7596", "identifierTypeId": "913300b2-03ed-469a-8179-c1092c991227"}, {"value": "(ICU)BID9651294", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(OCoLC)1479565", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(OCoLC)1964851", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(OCoLC)236213576", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "2363771", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Chicago, Ill.", "publisher": "American Bar Association"}], "contributors": [{"name": "American Bar Association", "contributorTypeId": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "contributorTypeText": "", "contributorNameTypeId": "d376e36c-b759-4fed-8502-7130d1eeff39"}, {"name": "American Bar Association. Journal", "contributorTypeId": "06b2cbd8-66bf-4956-9d90-97c9776365a4", "contributorTypeText": "", "contributorNameTypeId": "d376e36c-b759-4fed-8502-7130d1eeff39"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "K1 .M385", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}, {"classificationNumber": "KB1 .A437", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}, {"classificationNumber": "347.05 A512", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": ["Began with vol. 1, no. 1 (Jan. 1915); ceased with v. 69, [no.12] (Dec. 1983)"], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": ["volume nc rdacarrier"], "statusUpdatedDate": "2025-05-16T18:12:36.130+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["69 v. : ill. ; 23-30 cm."], "publicationFrequency": ["Monthly, 1921-83", "Quarterly, 1915-20"], "natureOfContentTermIds": []}	2025-05-16 18:12:36.124	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.133306+00
549fad9e-7f8e-4d8e-9a71-00d251817866	{"id": "549fad9e-7f8e-4d8e-9a71-00d251817866", "hrid": "inst000000000028", "notes": [], "title": "Agile Organisation, Risiko- und Change Management Harald Augustin (Hrsg.)", "series": [{"value": "Umsetzung der DIN EN ISO 9001:2015  / Harald Augustin (Hrsg.) ; Band 2"}, {"value": "Berichte aus der Betriebswirtschaft"}, {"value": "Umsetzung der DIN EN ISO 9001:2015 Band 2"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.202Z", "updatedDate": "2025-05-16T18:12:36.202Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "DIN EN ISO 9001:2015"}, {"value": "Standard"}, {"value": "Risikomanagement"}, {"value": "Einführung"}, {"value": "Organisatorischer Wandel"}, {"value": "Industrie"}, {"value": "Deutschland"}], "languages": ["ger"], "identifiers": [{"value": "3844057439", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9783844057430", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9783844057430", "identifierTypeId": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5"}, {"value": "(OCoLC)1024128245", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-101)1150176652", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-599)DNB1150176652", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Aachen", "publisher": "Shaker Verlag", "dateOfPublication": "2017"}], "contributors": [{"name": "Augustin, Harald", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Shaker Verlag GmbH", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "658.4013", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}, {"classificationNumber": "650", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [{"uri": "http://d-nb.info/1150176652/04", "linkText": "Electronic resource (PDF)", "publicNote": "Address for accessing the table of content. PDF file"}], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2017}, "statusUpdatedDate": "2025-05-16T18:12:36.202+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["x, 148 Seiten Illustrationen 21 cm, 188 g"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.202	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.209957+00
04489a01-f3cd-4f9e-9be4-d9c198703f45	{"id": "04489a01-f3cd-4f9e-9be4-d9c198703f45", "hrid": "inst000000000015", "notes": [{"note": "Literaturangaben", "staffOnly": false}, {"note": "Introduction: The environment in colonial Africa -- British Cameroon grasslands of Bamenda : geography and history -- Heterogeneous societies and ethnic identity : Fulani and cattle migrations -- Resource conflicts : farmers, pastoralists, cattle taxes and disputes over grazing and land -- Towards a resolution : the land settlement question -- Transforming British Bamenda : cattle wealth and development -- Semi-autonomy for pastoralists : native authority and court for the Fulani -- Modernizing the minds : introduction Western education to the pastoral Fulani -- Managing development : grazing innovations -- Continuity and change : the limits of colonial modernization", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "Environment and identity politics in colonial Africa Fulani migrations and land conflict by Emmanuel M. Mbah", "series": [{"value": "Global Africa 2"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.246Z", "updatedDate": "2025-05-16T18:12:36.246Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Fula (African people)--Cameroon--Bamenda Highlands"}, {"value": "Fula (African people)--Land tenure"}, {"value": "Land settlement patterns--Cameroon--Bamenda Highlands"}, {"value": "Cattle--Environmental aspects--Cameroon--Bamenda Highlands"}, {"value": "Grazing--Environmental aspects--Cameroon--Bamenda Highlands"}, {"value": "Kolonie"}, {"value": "Fulbe"}, {"value": "Regionale Mobilität"}, {"value": "Weidewirtschaft"}, {"value": "Ethnische Beziehungen"}, {"value": "Konflikt"}, {"value": "Grundeigentum"}, {"value": "Natürliche Ressourcen"}, {"value": "Cameroon--Ethnic relations"}, {"value": "Great Britain--Colonies--Africa--Administration"}, {"value": "Großbritannien"}, {"value": "Kamerun--Nordwest"}, {"value": "Cameroon Ethnic relations"}, {"value": "Great Britain Colonies Africa Administration"}, {"value": "Cattle Environmental aspects Cameroon Bamenda Highlands"}, {"value": "Fula (African people) Land tenure"}, {"value": "Fula (African people) Cameroon Bamenda Highlands"}, {"value": "Grazing Environmental aspects Cameroon Bamenda Highlands"}, {"value": "Land settlement patterns Cameroon Bamenda Highlands"}, {"value": "Geschichte 1916-1960"}], "languages": ["eng"], "identifiers": [{"value": "2016030844", "identifierTypeId": "c858e4f2-2b6b-4385-842b-60732ee14abb"}, {"value": "9781138239555", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9781315294179", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "(OCoLC)961183745", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-599)GBV869303589", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "London New York, NY", "publisher": "Routledge Taylor & Francis Group", "dateOfPublication": "2017"}], "contributors": [{"name": "Mbah, Emmanuel M", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "DT571.F84", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}, {"classificationNumber": "967.1100496322", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2017}, "statusUpdatedDate": "2025-05-16T18:12:36.246+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["175 Seiten Karten"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.246	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.249549+00
f31a36de-fcf8-44f9-87ef-a55d06ad21ae	{"id": "f31a36de-fcf8-44f9-87ef-a55d06ad21ae", "hrid": "inst000000000012", "notes": [], "title": "The Girl on the Train", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.079Z", "updatedDate": "2025-05-16T18:12:36.079Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "B01LO7PJOE", "identifierTypeId": "7f907515-a1bf-4513-8a38-92e1a07c539d"}], "publication": [], "contributors": [{"name": "Creator A", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}, {"name": "Creator B", "contributorNameTypeId": "e8b311a6-3b21-43f2-a269-dd9310cb2d0a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [{"alternativeTitle": "First alternative title"}, {"alternativeTitle": "Second alternative title"}], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.079+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": ["44cd89f3-2e76-469f-a955-cc57cb9e0395"]}	2025-05-16 18:12:36.079	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.58971+00
5bf370e0-8cca-4d9c-82e4-5170ab2a0a39	{"id": "5bf370e0-8cca-4d9c-82e4-5170ab2a0a39", "hrid": "inst000000000022", "notes": [{"note": "Includes bibliographical references and index.", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "The development of the Semantic Web, with machine-readable content, has the potential to revolutionize the World Wide Web and its uses. A Semantic Web Primer provides an introduction and guide to this continuously evolving field, describing its key ideas, languages, and technologies. Suitable for use as a textbook or for independent study by professionals, it concentrates on undergraduate-level fundamental concepts and techniques that will enable readers to proceed with building applications on their own and includes exercises, project descriptions, and annotated references to relevant online materials. The third edition of this widely used text has been thoroughly updated, with significant new material that reflects a rapidly developing field. Treatment of the different languages (OWL2, rules) expands the coverage of RDF and OWL, defining the data model independently of XML and including coverage of N3/Turtle and RDFa. A chapter is devoted to OWL2, the new W3C standard. This edition also features additional coverage of the query language SPARQL, the rule language RIF and the possibility of interaction between rules and ontology languages and applications. The chapter on Semantic Web applications reflects the rapid developments of the past few years. A new chapter offers ideas for term projects", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "A semantic web primer", "series": [{"value": "Cooperative information systems"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.162Z", "updatedDate": "2025-05-16T18:12:36.162Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statusId": "9634a5ab-9228-4703-baf2-4d12ebc77d56", "subjects": [{"value": "Semantic Web"}], "languages": ["eng"], "indexTitle": "Semantic web primer", "identifiers": [{"value": "0262012103", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9780262012102", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "2003065165", "identifierTypeId": "c858e4f2-2b6b-4385-842b-60732ee14abb"}], "publication": [{"role": "Publisher", "place": "Cambridge, Mass. ", "publisher": "MIT Press", "dateOfPublication": "c2004"}], "contributors": [{"name": "Antoniou, Grigoris", "contributorTypeId": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "contributorTypeText": "", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Van Harmelen, Frank", "contributorTypeId": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "contributorTypeText": "", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "catalogedDate": "2019-04-05", "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "025.04", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}, {"classificationNumber": "TK5105.88815 .A58 2004", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "modeOfIssuanceId": "9d18a02f-5897-4c31-9106-c9abb5c7ae8b", "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2004}, "statusUpdatedDate": "2025-05-16T18:12:36.162+0000", "statisticalCodeIds": ["b5968c9e-cddc-4576-99e3-8e60aed8b0dd"], "administrativeNotes": [], "physicalDescriptions": ["xx, 238 p. : ill. ; 24 cm."], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.162	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	9d18a02f-5897-4c31-9106-c9abb5c7ae8b	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.596818+00
81825729-e824-4d52-9d15-1695e9bf1831	{"id": "81825729-e824-4d52-9d15-1695e9bf1831", "hrid": "inst000000000014", "notes": [{"note": "Literaturangaben", "staffOnly": false}, {"note": "Introduction: Dissent, protest and dispute Africa / Emmanuel M. Mbah and Toyin Falola -- The music of heaven, the music of Earth, and the music of brats: Tuareg Islam, the Devil, and musical performance / Susan J. Rasmussen -- Finding social change backstage and behind the scenes in South African theatre / Nathanael Vlachos -- Soccer and political (ex)pression in Africa: the case of Cameroon / Alain Lawo-Sukam -- Child labor resistance in southern Nigeria, 1916-1938 / Adam Paddock -- M'Fain goes home: African soldiers in the Gabon campaign of 1940 / Mark Reeves -- \\\\\\"Disgraceful disturbances\\\\\\": TANU, the Tanganyikan Rifles, and the 1964 mutiny / Charles Thomas -- The role of ethnicity in political formation in Kenya: 1963-2007 / Tade O. Okediji and Wahutu J. Siguru -- Land, boundaries, chiefs and wars / Toyin Falola -- Borders and boundaries within Ethiopia: dilemmas of group identity, representation and agency / Alexander Meckelburg -- Rural agrarian land conflicts in postcolonial Nigeria's central region / Sati Fwatshak -- The evolution of the Mungiki militia in Kenya, 1990 to 2010 / Felix Kiruthu -- Refugee-warriors and other people's wars in post-colonial Africa: the experience of Rwandese and South African military exiles (1960-94) / Tim Stapleton -- Oiling the guns and gunning for oil: the youth and Niger Delta oil conflicts in Nigeria / Christian C. Madubuko.", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "Dissent, protest and dispute in Africa edited by Emmanuel M. Mbah and Toyin Falola", "series": [{"value": "Global Africa 1"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.084Z", "updatedDate": "2025-05-16T18:12:36.084Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Social conflict--Africa--History--20th century"}, {"value": "Social conflict--Africa--History--21st century"}, {"value": "Political participation--Africa"}, {"value": "Land tenure--Africa"}, {"value": "Africa--Social conditions--20th century"}, {"value": "Africa--Social conditions--21st century"}, {"value": "Africa--Politics and government--20th century"}, {"value": "Africa--Politics and government--21st century"}, {"value": "Africa Politics and government 20th century"}, {"value": "Africa Politics and government 21st century"}, {"value": "Africa Social conditions 20th century"}, {"value": "Africa Social conditions 21st century"}, {"value": "Land tenure Africa"}, {"value": "Political participation Africa"}, {"value": "Social conflict Africa History 20th century"}, {"value": "Social conflict Africa History 21st century"}], "languages": ["eng"], "identifiers": [{"value": "2016022536", "identifierTypeId": "c858e4f2-2b6b-4385-842b-60732ee14abb"}, {"value": "9781138220034", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9781315413099", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "(DE-599)GBV86011306X", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "London New York", "publisher": "Routledge, Taylor & Francis Group", "dateOfPublication": "2017"}], "contributors": [{"name": "Mbah, Emmanuel M", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Falola, Toyin", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "HN773", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}, {"classificationNumber": "303.6/9096", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [{"uri": "https://external.dandelon.com/download/attachments/dandelon/ids/DE0069AE502CCFE91E537C1258123001D0DCA.pdf", "linkText": "Electronic resource (PDF)", "publicNote": "Address for accessing the table of content. PDF file"}], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2017}, "statusUpdatedDate": "2025-05-16T18:12:36.085+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["xi, 293 Seiten"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.084	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.092498+00
62ca5b43-0f11-40af-a6b4-1a9ee2db33cb	{"id": "62ca5b43-0f11-40af-a6b4-1a9ee2db33cb", "hrid": "inst000000000020", "notes": [{"note": "Mikrofilm-Ausg. 1957 1 Mikrofilm", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "The Neurotic Heroine in Tennessee Williams microform C.N. Stavrou", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.134Z", "updatedDate": "2025-05-16T18:12:36.134Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": ["eng"], "identifiers": [{"value": "53957015X", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "(DE-599)GBV53957015X", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "New York", "publisher": "Columbia University", "dateOfPublication": "1955"}], "contributors": [{"name": "Stavrou, C.N", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 1955}, "statusUpdatedDate": "2025-05-16T18:12:36.134+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["1 Mikrofilm 26-34 S."], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.134	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.138422+00
6eee8eb9-db1a-46e2-a8ad-780f19974efa	{"id": "6eee8eb9-db1a-46e2-a8ad-780f19974efa", "hrid": "inst000000000011", "notes": [], "title": "DC Motor Control Experiment Objekt for introduction to control systems Herbert Werner", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.182Z", "updatedDate": "2025-05-16T18:12:36.182Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": ["ger"], "identifiers": [{"value": "727867881", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "(DE-599)GBV727867881", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Hamburg", "publisher": "Techn. Univ., Inst. für Regelungstechnik", "dateOfPublication": "[2016]"}], "contributors": [{"name": "Werner, Herbert", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Technische Universität Hamburg-Harburg Institut für Regelungstechnik", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}], "instanceTypeId": "c1e95c2b-4efc-48cf-9e71-edb622cf0c22", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2016}, "statusUpdatedDate": "2025-05-16T18:12:36.182+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["1 Koffer (Inhalt: 1 Motor mit Platine auf Plattform, 1 Netzteil, 1 USB-Kabel)"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.182	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	c1e95c2b-4efc-48cf-9e71-edb622cf0c22	2025-05-16 18:12:36.184086+00
c1d3be12-ecec-4fab-9237-baf728575185	{"id": "c1d3be12-ecec-4fab-9237-baf728575185", "hrid": "inst000000000009", "notes": [{"note": "Cities are sites of great wealth and poverty, of hope and despair, of social and economic dynamism, as well as tradition and established power. Social scientists and humanities scholars have over the past three decades generated an impressive range of perspectives for making sense of the vast complexities of cities. These perspectives tell both of the economic, social and political dynamism cities generate, and point to possible lines of future development. The four volumes, The City: Post-Modernity, will focus more exclusively on the contemporary city, looking at the subject through the lenses of globalization and post-colonialism, amongst others", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "The city post-modernity edited by Alan Latham", "series": [{"value": "SAGE benchmarks in culture and society"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.213Z", "updatedDate": "2025-05-16T18:12:36.213Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Stadt"}, {"value": "Postmoderne"}, {"value": "Aufsatzsammlung"}], "languages": ["eng"], "identifiers": [{"value": "1010770160", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "9781473937703", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "(DE-599)GBV1010770160", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Los Angeles London New Delhi Singapore Washington DC Melbourne", "publisher": "SAGE", "dateOfPublication": "2018"}], "contributors": [{"name": "Latham, Alan", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "H", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}, {"classificationNumber": "300", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2018}, "statusUpdatedDate": "2025-05-16T18:12:36.214+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.213	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.218315+00
f7e82a1e-fc06-4b82-bb1d-da326cb378ce	{"id": "f7e82a1e-fc06-4b82-bb1d-da326cb378ce", "hrid": "inst000000000013", "notes": [], "title": "Global Africa", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.048Z", "updatedDate": "2025-05-16T18:12:36.048Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Monografische Reihe"}], "languages": ["eng"], "identifiers": [{"value": "(OCoLC)981117973", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-599)ZDB2905315-8", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "London New York", "publisher": "Routledge, Taylor & Francis Group", "dateOfPublication": "2017-"}], "contributors": [], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "300", "classificationTypeId": "42471af9-7d25-4f3a-bf78-60d29dcf463b"}], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2017}, "statusUpdatedDate": "2025-05-16T18:12:36.048+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["Bände"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.048	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.051328+00
8be05cf5-fb4f-4752-8094-8e179d08fb99	{"id": "8be05cf5-fb4f-4752-8094-8e179d08fb99", "hrid": "inst000000000004", "notes": [{"note": "Titel und Angaben zu beteiligter Person vom Begleitheft", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "In English with segments in Anglo-Saxon and Latin", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "Anglo-Saxon manuscripts in microfiche facsimile Volume 25 Corpus Christi College, Cambridge II, MSS 12, 144, 162, 178, 188, 198, 265, 285, 322, 326, 449 microform A. N. Doane (editor and director), Matthew T. Hussey (associate editor), Phillip Pulsiano (founding editor)", "series": [{"value": "Medieval and Renaissance Texts and Studies volume 497"}, {"value": "volume 497"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.135Z", "updatedDate": "2025-05-16T18:12:36.135Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": ["eng", "ang", "lat"], "identifiers": [{"value": "880391235", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "9780866989732", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "0866989730", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9780866985529", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "0866985522", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "(OCoLC)962073864", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(OCoLC)ocn962073864", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(OCoLC)962073864", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}, {"value": "(DE-599)GBV880391235", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [{"place": "Tempe, Arizona", "publisher": "ACMRS, Arizona Center for Medieval and Renaissance Studies", "dateOfPublication": "2016"}], "contributors": [{"name": "Lucas, Peter J", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Arizona Center for Medieval and Renaissance Studies", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 2016}, "statusUpdatedDate": "2025-05-16T18:12:36.135+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["69 Mikrofiches 1 Begleitbuch (XII, 167 Seiten)"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.135	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.138547+00
87d0c31e-a466-4deb-9348-7fea0f68bc22	{"id": "87d0c31e-a466-4deb-9348-7fea0f68bc22", "hrid": "bwinst0006", "notes": [], "title": "Magazine - Q3", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.861Z", "updatedDate": "2025-05-16T18:12:36.861Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "bw", "identifierTypeId": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5"}], "publication": [], "contributors": [], "staffSuppress": false, "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.861+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.861	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.928593+00
28d36163-0425-4452-b1f8-1dc4467c52b1	{"id": "28d36163-0425-4452-b1f8-1dc4467c52b1", "hrid": "bwinst0004", "notes": [], "title": "Magazine - Q1", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.860Z", "updatedDate": "2025-05-16T18:12:36.860Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "bw", "identifierTypeId": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5"}], "publication": [], "contributors": [], "staffSuppress": false, "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.860+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.86	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.954095+00
6b4ae089-e1ee-431f-af83-e1133f8e3da0	{"id": "6b4ae089-e1ee-431f-af83-e1133f8e3da0", "hrid": "inst000000000019", "notes": [], "title": "MobiCom'17 5 mmNets'17, October 16, 2017, Snowbird, UT, USA / general chairs: Haitham Hassanieh (University of Illinois at Urbana Champaign, USA), Xinyu Zhang (University of California San Diego, USA)", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.177Z", "updatedDate": "2025-05-16T18:12:36.177Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": ["eng"], "identifiers": [{"value": "1011273942", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "9781450351430", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "(DE-599)GBV1011273942", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [], "contributors": [{"name": "ACM Workshop on Millimeter Wave Networks and Sensing Systems 1. 2017 Snowbird, Utah", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}, {"name": "Hassanieh, Haitham", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Zhang, Xinyu", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "MobiCom 23. 2017 Snowbird, Utah", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}, {"name": "Association for Computing Machinery Special Interest Group on Mobility of Systems Users, Data, and Computing", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}, {"name": "ACM Workshop on Millimeter Wave Networks and Sensing Systems 1 2017.10.16 Snowbird, Utah", "contributorNameTypeId": "e8b311a6-3b21-43f2-a269-dd9310cb2d0a"}, {"name": "mmNets 1 2017.10.16 Snowbird, Utah", "contributorNameTypeId": "e8b311a6-3b21-43f2-a269-dd9310cb2d0a"}, {"name": "Annual International Conference on Mobile Computing and Networking (ACM MobiCom) 23 2017.10.16-20 Snowbird, Utah", "contributorNameTypeId": "e8b311a6-3b21-43f2-a269-dd9310cb2d0a"}], "instanceTypeId": "a2c91e87-6bab-44d6-8adb-1fd02481fc4f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [{"alternativeTitle": "1st First ACM Workshop Millimeter Wave Networks Sensing Systems"}], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.178+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.177	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	a2c91e87-6bab-44d6-8adb-1fd02481fc4f	2025-05-16 18:12:36.184002+00
ce00bca2-9270-4c6b-b096-b83a2e56e8e9	{"id": "ce00bca2-9270-4c6b-b096-b83a2e56e8e9", "hrid": "inst000000000007", "notes": [], "title": "Cantatas for bass 4 Ich habe genug : BWV 82 / Johann Sebastian Bach ; Matthias Goerne, baritone ; Freiburger Barockorchester, Gottfried von der Goltz, violin and conductor", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.211Z", "updatedDate": "2025-05-16T18:12:36.211Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": ["ger"], "identifiers": [{"value": "1011162431", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}, {"value": "(DE-599)GBV1011162431", "identifierTypeId": "7e591197-f335-4afb-bc6d-a6d76ca3bace"}], "publication": [], "contributors": [{"name": "Bach, Johann Sebastian", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Arfken, Katharina", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Goltz, Gottfried von der", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Freiburger Barockorchester", "contributorNameTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210aa"}], "instanceTypeId": "3be24c14-3551-4180-9292-26a786649c8b", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [{"alternativeTitle": "Ich habe genung"}, {"alternativeTitle": "Abweichender Titel Ich habe genung"}], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.211+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["Track 10-14"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.211	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	3be24c14-3551-4180-9292-26a786649c8b	2025-05-16 18:12:36.217638+00
cf23adf0-61ba-4887-bf82-956c4aae2260	{"id": "cf23adf0-61ba-4887-bf82-956c4aae2260", "hrid": "inst000000000024", "notes": [], "title": "Temeraire", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.087Z", "updatedDate": "2025-05-16T18:12:36.087Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "1447294130", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9781447294130", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}], "publication": [], "contributors": [{"name": "Novik, Naomi", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.087+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.087	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.629696+00
30fcc8e7-a019-43f4-b642-2edc389f4501	{"id": "30fcc8e7-a019-43f4-b642-2edc389f4501", "hrid": "inst000000000003", "notes": [{"note": "Print subscription cancelled by Dec. 2016.", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "May 1988-: A Yorke medical. Also known as the Green journal", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "Publisher: Excerpta Medica, 2008-; New York, NY : Elsevier Inc. 2013-", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "Supplements issued irregularly, 1982.", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "Official journal of the Association of Professors of Medicine 2005-", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}, {"note": "Indexed quinquennially in: American journal of medicine 5 year cumulative index", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "The American Journal of Medicine", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.187Z", "updatedDate": "2025-05-16T18:12:36.187Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Clinical medicine-Periodicals"}, {"value": "Medicine"}, {"value": "Geneeskunde"}], "languages": ["eng"], "identifiers": [{"value": "AJMEAZ", "identifierTypeId": "593b78cb-32f3-44d1-ba8c-63fd5e6989e6"}, {"value": "0002-9343", "identifierTypeId": "913300b2-03ed-469a-8179-c1092c991227"}, {"value": "med49002270", "identifierTypeId": "c858e4f2-2b6b-4385-842b-60732ee14abb"}], "publication": [{"place": "New York", "publisher": "Dun-Donnelley Pub. Co. ", "dateOfPublication": "1946-"}], "contributors": [], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [{"classificationNumber": "RC60 .A5", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}, {"classificationNumber": "W1 AM493", "classificationTypeId": "a7f4d03f-b0d8-496c-aebf-4e9cdb678200"}], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [{"alternativeTitle": "The American journal of medicine (online)"}, {"alternativeTitle": "Am. J. med"}, {"alternativeTitle": "Green journal"}], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 1946}, "statusUpdatedDate": "2025-05-16T18:12:36.189+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["v., ill. 27 cm."], "publicationFrequency": [], "natureOfContentTermIds": ["0abeee3d-8ad2-4b04-92ff-221b4fce1075"]}	2025-05-16 18:12:36.187	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.625019+00
69640328-788e-43fc-9c3c-af39e243f3b7	{"id": "69640328-788e-43fc-9c3c-af39e243f3b7", "hrid": "inst000000000001", "notes": [], "title": "ABA Journal", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.137Z", "updatedDate": "2025-05-16T18:12:36.137Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "0747-0088", "identifierTypeId": "913300b2-03ed-469a-8179-c1092c991227"}, {"value": "84641839", "identifierTypeId": "c858e4f2-2b6b-4385-842b-60732ee14abb"}], "publication": [{"place": "Chicago, Ill.", "publisher": "American Bar Association", "dateOfPublication": "1915-1983"}], "contributors": [], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"end": 1983, "start": 1915}, "statusUpdatedDate": "2025-05-16T18:12:36.137+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": ["0abeee3d-8ad2-4b04-92ff-221b4fce1075"]}	2025-05-16 18:12:36.137	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.650571+00
7fbd5d84-62d1-44c6-9c45-6cb173998bbd	{"id": "7fbd5d84-62d1-44c6-9c45-6cb173998bbd", "hrid": "inst000000000006", "notes": [{"note": "Bridget Jones finds herself unexpectedly pregnant at the eleventh hour. However, her joyful pregnancy is dominated by one crucial but awkward question --who is the father? Could it be honorable, decent, notable human rights lawyer, Mark Darcy? Or, is it charming, witty, and totally despicable, Daniel Cleaver?", "staffOnly": false, "instanceNoteTypeId": "6a2533a7-4de2-4e64-8466-074c2fa9308c"}], "title": "Bridget Jones's Baby: the diaries", "series": [], "source": "FOLIO", "_version": 1, "editions": ["First American Edition"], "metadata": {"createdDate": "2025-05-16T18:12:36.216Z", "updatedDate": "2025-05-16T18:12:36.216Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [{"value": "Jones, Bridget"}, {"value": "Pregnant women"}, {"value": "England"}, {"value": "Humorous fiction"}, {"value": "Diary fiction"}], "languages": ["eng"], "identifiers": [{"value": "ocn956625961", "identifierTypeId": "5d164f4b-0b15-4e42-ae75-cfcf85318ad9"}], "publication": [{"place": "New York", "publisher": "Alfred A. Knopf", "dateOfPublication": "2016"}], "contributors": [{"name": "Fielding, Helen", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "staffSuppress": true, "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": true, "classifications": [{"classificationNumber": "PR6056.I4588", "classificationTypeId": "ce176ace-a53e-4b4d-aa89-725ed7b2edac"}], "instanceFormats": [], "electronicAccess": [{"uri": "http://www.folio.org/", "linkText": "Electronic resource (audio streaming)", "publicNote": "Access to audio file", "materialsSpecification": "Novel"}], "holdingsRecords2": [], "publicationRange": ["A publication range"], "alternativeTitles": [], "discoverySuppress": true, "instanceFormatIds": [], "publicationPeriod": {"start": 2016}, "statusUpdatedDate": "2025-05-16T18:12:36.216+0000", "statisticalCodeIds": [], "administrativeNotes": ["Cataloging data"], "physicalDescriptions": ["219 pages ; 20 cm."], "publicationFrequency": ["A frequency description"], "natureOfContentTermIds": []}	2025-05-16 18:12:36.216	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.651434+00
2b0312ca-2f57-494f-9fdb-aa13339b8049	{"id": "2b0312ca-2f57-494f-9fdb-aa13339b8049", "hrid": "bwinst0007", "notes": [], "title": "Magazine - Q4", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.864Z", "updatedDate": "2025-05-16T18:12:36.864Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "bw", "identifierTypeId": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5"}], "publication": [], "contributors": [], "staffSuppress": false, "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.865+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.864	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.930121+00
a89eccf0-57a6-495e-898d-32b9b2210f2f	{"id": "a89eccf0-57a6-495e-898d-32b9b2210f2f", "hrid": "inst000000000017", "notes": [], "title": "Interesting Times", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.047Z", "updatedDate": "2025-05-16T18:12:36.047Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "0552142352", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9780552142352", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}], "publication": [], "contributors": [{"name": "Pratchett, Terry", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.047+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.047	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.504262+00
6506b79b-7702-48b2-9774-a1c538fdd34e	{"id": "6506b79b-7702-48b2-9774-a1c538fdd34e", "hrid": "inst000000000021", "notes": [], "title": "Nod", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:35.969Z", "updatedDate": "2025-05-16T18:12:35.969Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "0956687695", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}, {"value": "9780956687695", "identifierTypeId": "8261054f-be78-422d-bd51-4ed9f33c3422"}], "publication": [], "contributors": [{"name": "Barnes, Adrian", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:35.970+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:35.969	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.592176+00
858b9600-bd76-44ff-a83e-f82dcf5ed12b	{"id": "858b9600-bd76-44ff-a83e-f82dcf5ed12b", "hrid": "bwinst0005", "notes": [], "title": "Magazine - Q2", "series": [], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.863Z", "updatedDate": "2025-05-16T18:12:36.863Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subjects": [], "languages": [], "identifiers": [{"value": "bw", "identifierTypeId": "2e8b3b6c-0e7d-4e48-bca2-b0b23b376af5"}], "publication": [], "contributors": [], "staffSuppress": false, "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "statusUpdatedDate": "2025-05-16T18:12:36.863+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": [], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.863	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	\N	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.930246+00
85010f04-b914-4ac7-ba30-be2b52f79708	{"id": "85010f04-b914-4ac7-ba30-be2b52f79708", "hrid": "bwinst0002", "tags": {"tagList": []}, "notes": [], "title": "Metod att beräkna en index för landets vattenkrafttillgång / av Åke Rusck och Gösta Nilsson", "series": [{"value": "Svenska Vattenkraftforeningens Publikationer ; 352 (1942:11)"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.676Z", "updatedDate": "2025-05-16T18:12:36.676Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statusId": "9634a5ab-9228-4703-baf2-4d12ebc77d56", "subjects": [], "languages": ["swe"], "identifiers": [{"value": "836918598", "identifierTypeId": "439bfbae-75bc-4f74-9fc7-b2a2d47ce3ef"}], "publication": [{"place": "Stockholm", "publisher": "Svenska Vattenkraftföreningen", "dateOfPublication": "1942"}], "contributors": [{"name": "Rusck, Åke", "primary": true, "contributorTypeId": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "contributorTypeText": "", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}, {"name": "Nilsson, Gösta", "primary": false, "contributorTypeId": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "contributorTypeText": "", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "modeOfIssuanceId": "9d18a02f-5897-4c31-9106-c9abb5c7ae8b", "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 1942}, "statusUpdatedDate": "2025-05-16T18:12:36.677+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["17 p. ; illustrations"], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.676	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	9d18a02f-5897-4c31-9106-c9abb5c7ae8b	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.716022+00
cd3288a4-898c-4347-a003-2d810ef70f03	{"id": "cd3288a4-898c-4347-a003-2d810ef70f03", "hrid": "bwinst0003", "tags": {"tagList": []}, "notes": [], "title": "Elpannan och dess ekonomiska förutsättningar / av Hakon Wærn", "series": [{"value": "Svenska Vattenkraftforeningens Publikationer ; 351 (1942:10)"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.678Z", "updatedDate": "2025-05-16T18:12:36.678Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statusId": "9634a5ab-9228-4703-baf2-4d12ebc77d56", "subjects": [], "languages": ["swe"], "identifiers": [{"value": "255752480", "identifierTypeId": "439bfbae-75bc-4f74-9fc7-b2a2d47ce3ef"}], "publication": [{"place": "Stockholm", "publisher": "Svenska Vattenkraftföreningen", "dateOfPublication": "1942"}], "contributors": [{"name": "Wærn, Hakon", "primary": true, "contributorTypeId": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "contributorTypeText": "", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "modeOfIssuanceId": "9d18a02f-5897-4c31-9106-c9abb5c7ae8b", "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 1942}, "statusUpdatedDate": "2025-05-16T18:12:36.678+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["23 p."], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.678	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	9d18a02f-5897-4c31-9106-c9abb5c7ae8b	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.716183+00
ce9dd893-c812-49d5-8973-d55d018894c4	{"id": "ce9dd893-c812-49d5-8973-d55d018894c4", "hrid": "bwinst0001", "tags": {"tagList": []}, "notes": [], "title": "Rapport från inspektionsresa till svenska betongdammar i augusti 1939, med särskild hänsyn till sprickbildningsfrågan och användandet av specialcement / av S. Giertz-Hedström", "series": [{"value": "Svenska Vattenkraftforeningens Publikationer ; 354 (1942:16)"}], "source": "FOLIO", "_version": 1, "editions": [], "metadata": {"createdDate": "2025-05-16T18:12:36.680Z", "updatedDate": "2025-05-16T18:12:36.680Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statusId": "9634a5ab-9228-4703-baf2-4d12ebc77d56", "subjects": [], "languages": ["swe"], "identifiers": [], "publication": [{"place": "Stockholm", "publisher": "Svenska Vattenkraftföreningen", "dateOfPublication": "1942"}], "contributors": [{"name": "Giertz-Hedström, S.", "primary": true, "contributorTypeId": "6e09d47d-95e2-4d8a-831b-f777b8ef6d81", "contributorTypeText": "", "contributorNameTypeId": "2b94c631-fca9-4892-a730-03ee529ffe2a"}], "instanceTypeId": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "previouslyHeld": false, "classifications": [], "instanceFormats": [], "electronicAccess": [], "holdingsRecords2": [], "modeOfIssuanceId": "9d18a02f-5897-4c31-9106-c9abb5c7ae8b", "publicationRange": [], "alternativeTitles": [], "discoverySuppress": false, "instanceFormatIds": [], "publicationPeriod": {"start": 1942}, "statusUpdatedDate": "2025-05-16T18:12:36.680+0000", "statisticalCodeIds": [], "administrativeNotes": [], "physicalDescriptions": ["16 p."], "publicationFrequency": [], "natureOfContentTermIds": []}	2025-05-16 18:12:36.68	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	\N	9d18a02f-5897-4c31-9106-c9abb5c7ae8b	6312d172-f0cf-40f6-b27d-9fa8feaf332f	2025-05-16 18:12:36.755997+00
\.


--
-- Data for Name: instance_format; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance_format (id, jsonb) FROM stdin;
7bfe7e83-d4aa-46d1-b2a9-f612b18d11f4	{"id": "7bfe7e83-d4aa-46d1-b2a9-f612b18d11f4", "code": "hd", "name": "microform -- microfilm reel", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.425+00:00", "updatedDate": "2025-05-16T18:12:34.425+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f0e689e8-e62d-4aac-b1c1-198ac9114aca	{"id": "f0e689e8-e62d-4aac-b1c1-198ac9114aca", "code": "mo", "name": "projected image -- film roll", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.435+00:00", "updatedDate": "2025-05-16T18:12:34.435+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e3179f91-3032-43ee-be97-f0464f359d9c	{"id": "e3179f91-3032-43ee-be97-f0464f359d9c", "code": "vz", "name": "video -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.436+00:00", "updatedDate": "2025-05-16T18:12:34.436+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7fde4e21-00b5-4de4-a90a-08a84a601aeb	{"id": "7fde4e21-00b5-4de4-a90a-08a84a601aeb", "code": "sq", "name": "audio -- audio roll", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.436+00:00", "updatedDate": "2025-05-16T18:12:34.436+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
0d9b1c3d-2d13-4f18-9472-cc1b91bf1752	{"id": "0d9b1c3d-2d13-4f18-9472-cc1b91bf1752", "code": "sb", "name": "audio -- audio belt", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.439+00:00", "updatedDate": "2025-05-16T18:12:34.439+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fc3e32a0-9c85-4454-a42e-39fca788a7dc	{"id": "fc3e32a0-9c85-4454-a42e-39fca788a7dc", "code": "he", "name": "microform -- microfiche", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.442+00:00", "updatedDate": "2025-05-16T18:12:34.442+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
88f58dc0-4243-4c6b-8321-70244ff34a83	{"id": "88f58dc0-4243-4c6b-8321-70244ff34a83", "code": "cb", "name": "computer -- computer chip cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.447+00:00", "updatedDate": "2025-05-16T18:12:34.447+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
788aa9a6-5f0b-4c52-957b-998266ee3bd3	{"id": "788aa9a6-5f0b-4c52-957b-998266ee3bd3", "code": "hg", "name": "microform -- microopaque", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.448+00:00", "updatedDate": "2025-05-16T18:12:34.448+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
d16b19d1-507f-4a22-bb8a-b3f713a73221	{"id": "d16b19d1-507f-4a22-bb8a-b3f713a73221", "code": "ch", "name": "computer -- computer tape reel", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.450+00:00", "updatedDate": "2025-05-16T18:12:34.450+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
53f44ae4-167b-4cc2-9a63-4375c0ad9f58	{"id": "53f44ae4-167b-4cc2-9a63-4375c0ad9f58", "code": "gd", "name": "projected image -- filmslip", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.455+00:00", "updatedDate": "2025-05-16T18:12:34.455+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
33009ba2-b742-4aab-b592-68b27451e94f	{"id": "33009ba2-b742-4aab-b592-68b27451e94f", "code": "hh", "name": "microform -- microfilm slip", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.454+00:00", "updatedDate": "2025-05-16T18:12:34.454+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b1c69d78-4afb-4d8b-9624-8b3cfa5288ad	{"id": "b1c69d78-4afb-4d8b-9624-8b3cfa5288ad", "code": "pp", "name": "microscopic -- microscope slide", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.460+00:00", "updatedDate": "2025-05-16T18:12:34.460+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5913bb96-e881-4087-9e71-33a43f68e12e	{"id": "5913bb96-e881-4087-9e71-33a43f68e12e", "code": "nb", "name": "unmediated -- sheet", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.461+00:00", "updatedDate": "2025-05-16T18:12:34.461+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5cb91d15-96b1-4b8a-bf60-ec310538da66	{"id": "5cb91d15-96b1-4b8a-bf60-ec310538da66", "code": "sd", "name": "audio -- audio disc", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.464+00:00", "updatedDate": "2025-05-16T18:12:34.464+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f4f30334-568b-4dd2-88b5-db8401607daf	{"id": "f4f30334-568b-4dd2-88b5-db8401607daf", "code": "ca", "name": "computer -- computer tape cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.469+00:00", "updatedDate": "2025-05-16T18:12:34.469+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e62f4860-b3b0-462e-92b6-e032336ab663	{"id": "e62f4860-b3b0-462e-92b6-e032336ab663", "code": "eh", "name": "stereographic -- stereograph card", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.473+00:00", "updatedDate": "2025-05-16T18:12:34.473+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
431cc9a0-4572-4613-b267-befb0f3d457f	{"id": "431cc9a0-4572-4613-b267-befb0f3d457f", "code": "vf", "name": "video -- videocassette", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.478+00:00", "updatedDate": "2025-05-16T18:12:34.478+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e5aeb29a-cf0a-4d97-8c39-7756c10d423c	{"id": "e5aeb29a-cf0a-4d97-8c39-7756c10d423c", "code": "cf", "name": "computer -- computer tape cassette", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.476+00:00", "updatedDate": "2025-05-16T18:12:34.476+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a0f2612b-f24f-4dc8-a139-89c3da5a38f1	{"id": "a0f2612b-f24f-4dc8-a139-89c3da5a38f1", "code": "hz", "name": "microform -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.479+00:00", "updatedDate": "2025-05-16T18:12:34.479+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fc9bfed9-2cb0-465f-8758-33af5bba750b	{"id": "fc9bfed9-2cb0-465f-8758-33af5bba750b", "code": "hb", "name": "microform -- microfilm cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.483+00:00", "updatedDate": "2025-05-16T18:12:34.483+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f5e8210f-7640-459b-a71f-552567f92369	{"id": "f5e8210f-7640-459b-a71f-552567f92369", "code": "cr", "name": "computer -- online resource", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.492+00:00", "updatedDate": "2025-05-16T18:12:34.492+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7612aa96-61a6-41bd-8ed2-ff1688e794e1	{"id": "7612aa96-61a6-41bd-8ed2-ff1688e794e1", "code": "st", "name": "audio -- audiotape reel", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.516+00:00", "updatedDate": "2025-05-16T18:12:34.516+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c3f41d5e-e192-4828-805c-6df3270c1910	{"id": "c3f41d5e-e192-4828-805c-6df3270c1910", "code": "es", "name": "stereographic -- stereograph disc", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.526+00:00", "updatedDate": "2025-05-16T18:12:34.526+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
549e3381-7d49-44f6-8232-37af1cb5ecf3	{"id": "549e3381-7d49-44f6-8232-37af1cb5ecf3", "code": "ck", "name": "computer -- computer card", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.535+00:00", "updatedDate": "2025-05-16T18:12:34.535+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a3549b8c-3282-4a14-9ec3-c1cf294043b9	{"id": "a3549b8c-3282-4a14-9ec3-c1cf294043b9", "code": "sz", "name": "audio -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.545+00:00", "updatedDate": "2025-05-16T18:12:34.545+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ba0d7429-7ccf-419d-8bfb-e6a1200a8d20	{"id": "ba0d7429-7ccf-419d-8bfb-e6a1200a8d20", "code": "vr", "name": "video -- videotape reel", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.560+00:00", "updatedDate": "2025-05-16T18:12:34.560+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
926662e9-2486-4bb9-ba3b-59bd2e7f2a0c	{"id": "926662e9-2486-4bb9-ba3b-59bd2e7f2a0c", "code": "nr", "name": "unmediated -- object", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.575+00:00", "updatedDate": "2025-05-16T18:12:34.575+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8d511d33-5e85-4c5d-9bce-6e3c9cd0c324	{"id": "8d511d33-5e85-4c5d-9bce-6e3c9cd0c324", "code": "nc", "name": "unmediated -- volume", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.583+00:00", "updatedDate": "2025-05-16T18:12:34.583+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6d749f00-97bd-4eab-9828-57167558f514	{"id": "6d749f00-97bd-4eab-9828-57167558f514", "code": "ss", "name": "audio -- audiocassette", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.594+00:00", "updatedDate": "2025-05-16T18:12:34.594+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
55d3b8aa-304e-4967-8b78-55926d7809ac	{"id": "55d3b8aa-304e-4967-8b78-55926d7809ac", "code": "pz", "name": "microscopic -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.485+00:00", "updatedDate": "2025-05-16T18:12:34.485+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5642320a-2ab9-475c-8ca2-4af7551cf296	{"id": "5642320a-2ab9-475c-8ca2-4af7551cf296", "code": "sg", "name": "audio -- audio cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.498+00:00", "updatedDate": "2025-05-16T18:12:34.498+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "readOnly": true}
8e04d356-2645-4f97-8de8-9721cf11ccef	{"id": "8e04d356-2645-4f97-8de8-9721cf11ccef", "code": "gf", "name": "projected image -- filmstrip", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.502+00:00", "updatedDate": "2025-05-16T18:12:34.502+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5fa3e09f-2192-41a9-b4bf-9eb8aef0af0a	{"id": "5fa3e09f-2192-41a9-b4bf-9eb8aef0af0a", "code": "no", "name": "unmediated -- card", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.514+00:00", "updatedDate": "2025-05-16T18:12:34.514+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fe1b9adb-e0cf-4e05-905f-ce9986279404	{"id": "fe1b9adb-e0cf-4e05-905f-ce9986279404", "code": "cz", "name": "computer -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.519+00:00", "updatedDate": "2025-05-16T18:12:34.519+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
affd5809-2897-42ca-b958-b311f3e0dcfb	{"id": "affd5809-2897-42ca-b958-b311f3e0dcfb", "code": "nn", "name": "unmediated -- flipchart", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.529+00:00", "updatedDate": "2025-05-16T18:12:34.529+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e05f2613-05df-4b4d-9292-2ee9aa778ecc	{"id": "e05f2613-05df-4b4d-9292-2ee9aa778ecc", "code": "ce", "name": "computer -- computer disc cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.543+00:00", "updatedDate": "2025-05-16T18:12:34.543+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
485e3e1d-9f46-42b6-8c65-6bb7bd4b37f8	{"id": "485e3e1d-9f46-42b6-8c65-6bb7bd4b37f8", "code": "se", "name": "audio -- audio cylinder", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.550+00:00", "updatedDate": "2025-05-16T18:12:34.550+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
68e7e339-f35c-4be2-b161-0b94d7569b7b	{"id": "68e7e339-f35c-4be2-b161-0b94d7569b7b", "code": "na", "name": "unmediated -- roll", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.558+00:00", "updatedDate": "2025-05-16T18:12:34.558+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7f857834-b2e2-48b1-8528-6a1fe89bf979	{"id": "7f857834-b2e2-48b1-8528-6a1fe89bf979", "code": "vd", "name": "video -- videodisc", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.575+00:00", "updatedDate": "2025-05-16T18:12:34.575+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
7c9b361d-66b6-4e4c-ae4b-2c01f655612c	{"id": "7c9b361d-66b6-4e4c-ae4b-2c01f655612c", "code": "ez", "name": "stereographic -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.579+00:00", "updatedDate": "2025-05-16T18:12:34.579+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
f7107ab3-9c09-4bcb-a637-368f39e0b140	{"id": "f7107ab3-9c09-4bcb-a637-368f39e0b140", "code": "gc", "name": "projected image -- filmstrip cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.593+00:00", "updatedDate": "2025-05-16T18:12:34.593+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
98f0caa9-d38e-427b-9ec4-454de81a94d7	{"id": "98f0caa9-d38e-427b-9ec4-454de81a94d7", "code": "zu", "name": "unspecified -- unspecified", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.499+00:00", "updatedDate": "2025-05-16T18:12:34.499+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
55a66581-3921-4b50-9981-4fe53bf35e7f	{"id": "55a66581-3921-4b50-9981-4fe53bf35e7f", "code": "mr", "name": "projected image -- film reel", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.516+00:00", "updatedDate": "2025-05-16T18:12:34.516+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6a679992-b37e-4b57-b6ea-96be6b51d2b4	{"id": "6a679992-b37e-4b57-b6ea-96be6b51d2b4", "code": "sw", "name": "audio -- audio wire reel", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.531+00:00", "updatedDate": "2025-05-16T18:12:34.531+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
cb96199a-21fb-4f11-b003-99291d8c9752	{"id": "cb96199a-21fb-4f11-b003-99291d8c9752", "code": "hj", "name": "microform -- microfilm roll", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.547+00:00", "updatedDate": "2025-05-16T18:12:34.547+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
5bfb7b4f-9cd5-4577-a364-f95352146a56	{"id": "5bfb7b4f-9cd5-4577-a364-f95352146a56", "code": "si", "name": "audio -- sound track reel", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.561+00:00", "updatedDate": "2025-05-16T18:12:34.561+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9166e7c9-7edb-4180-b57e-e495f551297f	{"id": "9166e7c9-7edb-4180-b57e-e495f551297f", "code": "mz", "name": "projected image -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.576+00:00", "updatedDate": "2025-05-16T18:12:34.576+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
cb3004a3-2a85-4ed4-8084-409f93d6d8ba	{"id": "cb3004a3-2a85-4ed4-8084-409f93d6d8ba", "code": "ha", "name": "microform -- aperture card", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.595+00:00", "updatedDate": "2025-05-16T18:12:34.595+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
47b226c0-853c-40f4-ba2e-2bd5ba82b665	{"id": "47b226c0-853c-40f4-ba2e-2bd5ba82b665", "code": "mf", "name": "projected image -- film cassette", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.501+00:00", "updatedDate": "2025-05-16T18:12:34.501+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
eb860cea-b842-4a8b-ab8d-0739856f0c2c	{"id": "eb860cea-b842-4a8b-ab8d-0739856f0c2c", "code": "gt", "name": "projected image -- overhead transparency", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.517+00:00", "updatedDate": "2025-05-16T18:12:34.517+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
132d70db-53b3-4999-bd79-0fac3b8b9b98	{"id": "132d70db-53b3-4999-bd79-0fac3b8b9b98", "code": "vc", "name": "video -- video cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.532+00:00", "updatedDate": "2025-05-16T18:12:34.532+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b71e5ec6-a15d-4261-baf9-aea6be7af15b	{"id": "b71e5ec6-a15d-4261-baf9-aea6be7af15b", "code": "hc", "name": "microform -- microfilm cassette", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.548+00:00", "updatedDate": "2025-05-16T18:12:34.548+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b2b39d2f-856b-4419-93d3-ed1851f91b9f	{"id": "b2b39d2f-856b-4419-93d3-ed1851f91b9f", "code": "gs", "name": "projected image -- slide", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.563+00:00", "updatedDate": "2025-05-16T18:12:34.563+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2802b285-9f27-4c86-a9d7-d2ac08b26a79	{"id": "2802b285-9f27-4c86-a9d7-d2ac08b26a79", "code": "nz", "name": "unmediated -- other", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.564+00:00", "updatedDate": "2025-05-16T18:12:34.564+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6bf2154b-df6e-4f11-97d0-6541231ac2be	{"id": "6bf2154b-df6e-4f11-97d0-6541231ac2be", "code": "mc", "name": "projected image -- film cartridge", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.578+00:00", "updatedDate": "2025-05-16T18:12:34.578+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
b72e66e2-d946-4b01-a696-8fab07051ff8	{"id": "b72e66e2-d946-4b01-a696-8fab07051ff8", "code": "hf", "name": "microform -- microfiche cassette", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.596+00:00", "updatedDate": "2025-05-16T18:12:34.596+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
ac9de2b9-0914-4a54-8805-463686a5489e	{"id": "ac9de2b9-0914-4a54-8805-463686a5489e", "code": "cd", "name": "computer -- computer disc", "source": "rdacarrier", "metadata": {"createdDate": "2025-05-16T18:12:34.597+00:00", "updatedDate": "2025-05-16T18:12:34.597+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
\.


--
-- Data for Name: instance_note_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance_note_type (id, jsonb, creation_date, created_by) FROM stdin;
49475f04-35ef-4f8a-aa7f-92773594ca76	{"id": "49475f04-35ef-4f8a-aa7f-92773594ca76", "name": "Issuing Body note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.439Z", "updatedDate": "2025-05-16T18:12:35.439Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.439	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
1d51e8b2-dee7-43f5-983c-a40757b9cdfa	{"id": "1d51e8b2-dee7-43f5-983c-a40757b9cdfa", "name": "Additional Physical Form Available note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.442Z", "updatedDate": "2025-05-16T18:12:35.442Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.442	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c636881b-8927-4480-ad1b-8d7b27b4bbfe	{"id": "c636881b-8927-4480-ad1b-8d7b27b4bbfe", "name": "Biographical or Historical Data", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.456Z", "updatedDate": "2025-05-16T18:12:35.456Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.456	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
95f62ca7-5df5-4a51-9890-d0ec3a34665f	{"id": "95f62ca7-5df5-4a51-9890-d0ec3a34665f", "name": "System Details note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.465Z", "updatedDate": "2025-05-16T18:12:35.465Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.465	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
aecfda7a-e8aa-46d6-9046-9b0b8c231b85	{"id": "aecfda7a-e8aa-46d6-9046-9b0b8c231b85", "name": "Supplement note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.472Z", "updatedDate": "2025-05-16T18:12:35.472Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.472	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
806cb024-80d2-47c2-8bbf-b91091c85f68	{"id": "806cb024-80d2-47c2-8bbf-b91091c85f68", "name": "Former Title Complexity note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.479Z", "updatedDate": "2025-05-16T18:12:35.479Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.479	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
42be8949-6f69-4c55-874b-60b744ac1103	{"id": "42be8949-6f69-4c55-874b-60b744ac1103", "name": "Original Version note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.487Z", "updatedDate": "2025-05-16T18:12:35.487Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.487	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
1c7acba3-523d-4237-acd2-e88549bfc660	{"id": "1c7acba3-523d-4237-acd2-e88549bfc660", "name": "Accumulation and Frequency of Use note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.500Z", "updatedDate": "2025-05-16T18:12:35.500Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.5	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
3d931c23-6ae8-4e5a-8802-dc8c2e21ea19	{"id": "3d931c23-6ae8-4e5a-8802-dc8c2e21ea19", "name": "Type of computer file or data note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.508Z", "updatedDate": "2025-05-16T18:12:35.508Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.508	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
e814a32e-02da-4773-8f3a-6629cdb7ecdf	{"id": "e814a32e-02da-4773-8f3a-6629cdb7ecdf", "name": "Restrictions on Access note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.514Z", "updatedDate": "2025-05-16T18:12:35.514Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.514	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
a6a5550f-4981-4b48-b821-a57d5c8ca3b3	{"id": "a6a5550f-4981-4b48-b821-a57d5c8ca3b3", "name": "Accessibility note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.521Z", "updatedDate": "2025-05-16T18:12:35.521Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.521	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
86b6e817-e1bc-42fb-bab0-70e7547de6c1	{"id": "86b6e817-e1bc-42fb-bab0-70e7547de6c1", "name": "Bibliography note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.526Z", "updatedDate": "2025-05-16T18:12:35.526Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.526	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
cf635f41-29e7-4dd0-8598-33f230157074	{"id": "cf635f41-29e7-4dd0-8598-33f230157074", "name": "Numbering peculiarities note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.533Z", "updatedDate": "2025-05-16T18:12:35.533Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.533	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5ba8e385-0e27-462e-a571-ffa1fa34ea54	{"id": "5ba8e385-0e27-462e-a571-ffa1fa34ea54", "name": "Formatted Contents Note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.541Z", "updatedDate": "2025-05-16T18:12:35.541Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.541	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
72c611ab-f353-4c09-a0cc-33ff96cc3bef	{"id": "72c611ab-f353-4c09-a0cc-33ff96cc3bef", "name": "Scale note for graphic material", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.438Z", "updatedDate": "2025-05-16T18:12:35.438Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.438	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9f08c9b7-500a-43e0-b00f-ba02396b198f	{"id": "9f08c9b7-500a-43e0-b00f-ba02396b198f", "name": "Creation / Production Credits note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.441Z", "updatedDate": "2025-05-16T18:12:35.441Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.441	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
06489647-c7b7-4b6c-878a-cb7c1178e9ca	{"id": "06489647-c7b7-4b6c-878a-cb7c1178e9ca", "name": "Study Program Information note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.439Z", "updatedDate": "2025-05-16T18:12:35.439Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.439	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
09812302-92f7-497e-9120-ed25de458ea5	{"id": "09812302-92f7-497e-9120-ed25de458ea5", "name": "Preferred Citation of Described Materials note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.455Z", "updatedDate": "2025-05-16T18:12:35.455Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.455	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
ec9f8285-6bf9-4e6c-a3cb-38ef17f0317f	{"id": "ec9f8285-6bf9-4e6c-a3cb-38ef17f0317f", "name": "Copy and Version Identification note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.457Z", "updatedDate": "2025-05-16T18:12:35.457Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.457	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
66ea8f28-d5da-426a-a7c9-739a5d676347	{"id": "66ea8f28-d5da-426a-a7c9-739a5d676347", "name": "Source of Description note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.456Z", "updatedDate": "2025-05-16T18:12:35.456Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.456	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
265c4910-3997-4242-9269-6a4a2e91392b	{"id": "265c4910-3997-4242-9269-6a4a2e91392b", "name": "Local notes", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.457Z", "updatedDate": "2025-05-16T18:12:35.457Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.457	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
922fdcde-952d-45c2-b9ea-5fc8959ad116	{"id": "922fdcde-952d-45c2-b9ea-5fc8959ad116", "name": "Target Audience note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.464Z", "updatedDate": "2025-05-16T18:12:35.464Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.464	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c6340b85-d048-426a-89aa-163cfb801a56	{"id": "c6340b85-d048-426a-89aa-163cfb801a56", "name": "Location of Originals / Duplicates note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.467Z", "updatedDate": "2025-05-16T18:12:35.467Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.467	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
1c017b8d-c783-4f63-b620-079f7a5b9c07	{"id": "1c017b8d-c783-4f63-b620-079f7a5b9c07", "name": "Action note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.468Z", "updatedDate": "2025-05-16T18:12:35.468Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.468	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
28e12ad3-4a8d-48cc-b56c-a5ded22fc844	{"id": "28e12ad3-4a8d-48cc-b56c-a5ded22fc844", "name": "Geographic Coverage note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.475Z", "updatedDate": "2025-05-16T18:12:35.475Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.475	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
6a2533a7-4de2-4e64-8466-074c2fa9308c	{"id": "6a2533a7-4de2-4e64-8466-074c2fa9308c", "name": "General note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.477Z", "updatedDate": "2025-05-16T18:12:35.477Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.477	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
f677d908-69c6-4450-94a6-abbcf94a1ee5	{"id": "f677d908-69c6-4450-94a6-abbcf94a1ee5", "name": "Terms Governing Use and Reproduction note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.477Z", "updatedDate": "2025-05-16T18:12:35.477Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.477	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
779c22a2-311c-4ebb-b71e-b246c7ee574d	{"id": "779c22a2-311c-4ebb-b71e-b246c7ee574d", "name": "Linking Entry Complexity note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.483Z", "updatedDate": "2025-05-16T18:12:35.483Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.483	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b73cc9c2-c9fa-49aa-964f-5ae1aa754ecd	{"id": "b73cc9c2-c9fa-49aa-964f-5ae1aa754ecd", "name": "Dissertation note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.484Z", "updatedDate": "2025-05-16T18:12:35.484Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.484	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
794f19f1-d00b-4b4b-97e9-0de5a34495a0	{"id": "794f19f1-d00b-4b4b-97e9-0de5a34495a0", "name": "Cartographic Mathematical Data", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.487Z", "updatedDate": "2025-05-16T18:12:35.487Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.487	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
1cb8ac76-01fa-49be-8b9c-fcdaf17458a5	{"id": "1cb8ac76-01fa-49be-8b9c-fcdaf17458a5", "name": "Entity and Attribute Information note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.488Z", "updatedDate": "2025-05-16T18:12:35.488Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.488	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
7356cde5-ec6b-4961-9cb0-961c48a37af4	{"id": "7356cde5-ec6b-4961-9cb0-961c48a37af4", "name": "Language note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.491Z", "updatedDate": "2025-05-16T18:12:35.491Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.491	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
7929eee7-6822-4199-8df4-bb2ae773e4cd	{"id": "7929eee7-6822-4199-8df4-bb2ae773e4cd", "name": "Data quality note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.497Z", "updatedDate": "2025-05-16T18:12:35.497Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.497	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
6f76f4e7-9c0b-4138-9371-09b36136372d	{"id": "6f76f4e7-9c0b-4138-9371-09b36136372d", "name": "Case File Characteristics note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.504Z", "updatedDate": "2025-05-16T18:12:35.504Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.504	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
43295b78-3bfa-4c28-bc7f-8d924f63493f	{"id": "43295b78-3bfa-4c28-bc7f-8d924f63493f", "name": "Date / time and place of an event note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.513Z", "updatedDate": "2025-05-16T18:12:35.513Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.513	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
654be0fd-bba2-4791-afa3-ae60300d7043	{"id": "654be0fd-bba2-4791-afa3-ae60300d7043", "name": "Information related to Copyright Status", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.517Z", "updatedDate": "2025-05-16T18:12:35.517Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.517	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
06b44741-888e-4b15-a75e-cb29e27752d1	{"id": "06b44741-888e-4b15-a75e-cb29e27752d1", "name": "With note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.523Z", "updatedDate": "2025-05-16T18:12:35.523Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.523	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
e0ea861c-959f-4912-8579-5e9ea8a69454	{"id": "e0ea861c-959f-4912-8579-5e9ea8a69454", "name": "Publications About Described Materials note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.529Z", "updatedDate": "2025-05-16T18:12:35.529Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.529	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
d548fdff-b71c-4359-8055-f1c008c30f01	{"id": "d548fdff-b71c-4359-8055-f1c008c30f01", "name": "Reproduction note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.535Z", "updatedDate": "2025-05-16T18:12:35.535Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.535	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
86c4bd09-16de-45ee-89d3-b6d32fae6de9	{"id": "86c4bd09-16de-45ee-89d3-b6d32fae6de9", "name": "Immediate Source of Acquisition note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.538Z", "updatedDate": "2025-05-16T18:12:35.538Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.538	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
e8cdc2fe-c53c-478a-a7f3-47f2fc79c6d4	{"id": "e8cdc2fe-c53c-478a-a7f3-47f2fc79c6d4", "name": "Awards note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.543Z", "updatedDate": "2025-05-16T18:12:35.543Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.543	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
02b5b0c6-3375-4912-ac75-ad9f552362b2	{"id": "02b5b0c6-3375-4912-ac75-ad9f552362b2", "name": "Methodology note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.502Z", "updatedDate": "2025-05-16T18:12:35.502Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.502	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
10e2e11b-450f-45c8-b09b-0f819999966e	{"id": "10e2e11b-450f-45c8-b09b-0f819999966e", "name": "Summary", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.510Z", "updatedDate": "2025-05-16T18:12:35.510Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.51	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
0ed2da88-3f81-42f5-b688-91b70919d9bb	{"id": "0ed2da88-3f81-42f5-b688-91b70919d9bb", "name": "Exhibitions note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.516Z", "updatedDate": "2025-05-16T18:12:35.516Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.516	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9b56b954-7f3b-4e4b-8ed0-cf40aef13975	{"id": "9b56b954-7f3b-4e4b-8ed0-cf40aef13975", "name": "Participant or Performer note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.523Z", "updatedDate": "2025-05-16T18:12:35.523Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.523	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
0dc69a30-6d2b-40df-a50e-e4982bda86f4	{"id": "0dc69a30-6d2b-40df-a50e-e4982bda86f4", "name": "Binding Information note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.534Z", "updatedDate": "2025-05-16T18:12:35.534Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.534	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
56cf513e-a738-40c5-a3ab-b0c60ba07e15	{"id": "56cf513e-a738-40c5-a3ab-b0c60ba07e15", "name": "Ownership and Custodial History note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.542Z", "updatedDate": "2025-05-16T18:12:35.542Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.542	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
6ca9df3f-454d-4b5b-9d41-feb5d5030b99	{"id": "6ca9df3f-454d-4b5b-9d41-feb5d5030b99", "name": "Citation / References note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.546Z", "updatedDate": "2025-05-16T18:12:35.546Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.546	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
13047c94-7d2c-4c41-9658-abacfa97a5c8	{"id": "13047c94-7d2c-4c41-9658-abacfa97a5c8", "name": "Information About Documentation note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.503Z", "updatedDate": "2025-05-16T18:12:35.503Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.503	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9a4b39f4-a7d5-4c4d-abc6-5ccf1fc1d78c	{"id": "9a4b39f4-a7d5-4c4d-abc6-5ccf1fc1d78c", "name": "Location of Other Archival Materials note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.514Z", "updatedDate": "2025-05-16T18:12:35.514Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.514	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
fda2f2e3-965f-4220-8a2b-93d35ce6d582	{"id": "fda2f2e3-965f-4220-8a2b-93d35ce6d582", "name": "Cumulative Index / Finding Aides notes", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.524Z", "updatedDate": "2025-05-16T18:12:35.524Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.524	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
f289c02b-9515-4c3f-b242-ffd071e82135	{"id": "f289c02b-9515-4c3f-b242-ffd071e82135", "name": "Funding Information Note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.535Z", "updatedDate": "2025-05-16T18:12:35.535Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.535	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
f939b820-4a23-43d1-84ba-101add6e1456	{"id": "f939b820-4a23-43d1-84ba-101add6e1456", "name": "Type of report and period covered note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.542Z", "updatedDate": "2025-05-16T18:12:35.542Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.542	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: instance_relationship; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance_relationship (id, jsonb, creation_date, created_by, superinstanceid, subinstanceid, instancerelationshiptypeid) FROM stdin;
e95b3807-ef1a-4588-b685-50ec38b4973a	{"id": "e95b3807-ef1a-4588-b685-50ec38b4973a", "metadata": {"createdDate": "2025-05-16T18:12:36.829Z", "updatedDate": "2025-05-16T18:12:36.829Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subInstanceId": "81825729-e824-4d52-9d15-1695e9bf1831", "superInstanceId": "f7e82a1e-fc06-4b82-bb1d-da326cb378ce", "instanceRelationshipTypeId": "30773a27-b485-4dab-aeb6-b8c04fa3cb17"}	2025-05-16 18:12:36.829	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	f7e82a1e-fc06-4b82-bb1d-da326cb378ce	81825729-e824-4d52-9d15-1695e9bf1831	30773a27-b485-4dab-aeb6-b8c04fa3cb17
e5cea7b1-3c48-428c-bc5e-2efc9ead1924	{"id": "e5cea7b1-3c48-428c-bc5e-2efc9ead1924", "metadata": {"createdDate": "2025-05-16T18:12:36.826Z", "updatedDate": "2025-05-16T18:12:36.826Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subInstanceId": "04489a01-f3cd-4f9e-9be4-d9c198703f45", "superInstanceId": "f7e82a1e-fc06-4b82-bb1d-da326cb378ce", "instanceRelationshipTypeId": "30773a27-b485-4dab-aeb6-b8c04fa3cb17"}	2025-05-16 18:12:36.826	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	f7e82a1e-fc06-4b82-bb1d-da326cb378ce	04489a01-f3cd-4f9e-9be4-d9c198703f45	30773a27-b485-4dab-aeb6-b8c04fa3cb17
34ec984a-4384-4088-bc58-5d5721c7b9d6	{"id": "34ec984a-4384-4088-bc58-5d5721c7b9d6", "metadata": {"createdDate": "2025-05-16T18:12:36.829Z", "updatedDate": "2025-05-16T18:12:36.829Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subInstanceId": "e6bc03c6-c137-4221-b679-a7c5c31f986c", "superInstanceId": "a317b304-528c-424f-961c-39174933b454", "instanceRelationshipTypeId": "a17daf0a-f057-43b3-9997-13d0724cdf51"}	2025-05-16 18:12:36.829	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	a317b304-528c-424f-961c-39174933b454	e6bc03c6-c137-4221-b679-a7c5c31f986c	a17daf0a-f057-43b3-9997-13d0724cdf51
6789438f-754e-4fa6-8a4b-66949b68c2bb	{"id": "6789438f-754e-4fa6-8a4b-66949b68c2bb", "metadata": {"createdDate": "2025-05-16T18:12:36.828Z", "updatedDate": "2025-05-16T18:12:36.828Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subInstanceId": "7ab22f0a-c9cd-449a-9137-c76e5055ca37", "superInstanceId": "f7e82a1e-fc06-4b82-bb1d-da326cb378ce", "instanceRelationshipTypeId": "30773a27-b485-4dab-aeb6-b8c04fa3cb17"}	2025-05-16 18:12:36.828	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	f7e82a1e-fc06-4b82-bb1d-da326cb378ce	7ab22f0a-c9cd-449a-9137-c76e5055ca37	30773a27-b485-4dab-aeb6-b8c04fa3cb17
1b449f40-5ae8-47df-9113-3c0a958b5ce8	{"id": "1b449f40-5ae8-47df-9113-3c0a958b5ce8", "metadata": {"createdDate": "2025-05-16T18:12:36.830Z", "updatedDate": "2025-05-16T18:12:36.830Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "subInstanceId": "549fad9e-7f8e-4d8e-9a71-00d251817866", "superInstanceId": "a317b304-528c-424f-961c-39174933b454", "instanceRelationshipTypeId": "a17daf0a-f057-43b3-9997-13d0724cdf51"}	2025-05-16 18:12:36.83	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	a317b304-528c-424f-961c-39174933b454	549fad9e-7f8e-4d8e-9a71-00d251817866	a17daf0a-f057-43b3-9997-13d0724cdf51
\.


--
-- Data for Name: instance_relationship_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance_relationship_type (id, jsonb, creation_date, created_by) FROM stdin;
758f13db-ffb4-440e-bb10-8a364aa6cb4a	{"id": "758f13db-ffb4-440e-bb10-8a364aa6cb4a", "name": "bound-with", "metadata": {"createdDate": "2025-05-16T18:12:34.115Z", "updatedDate": "2025-05-16T18:12:34.115Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.115	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
30773a27-b485-4dab-aeb6-b8c04fa3cb17	{"id": "30773a27-b485-4dab-aeb6-b8c04fa3cb17", "name": "monographic series", "metadata": {"createdDate": "2025-05-16T18:12:34.110Z", "updatedDate": "2025-05-16T18:12:34.110Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.11	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
a17daf0a-f057-43b3-9997-13d0724cdf51	{"id": "a17daf0a-f057-43b3-9997-13d0724cdf51", "name": "multipart monograph", "metadata": {"createdDate": "2025-05-16T18:12:34.114Z", "updatedDate": "2025-05-16T18:12:34.114Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.114	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: instance_source_marc; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance_source_marc (id, jsonb, creation_date, created_by) FROM stdin;
\.


--
-- Data for Name: instance_status; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance_status (id, jsonb, creation_date, created_by) FROM stdin;
f5cc2ab6-bb92-4cab-b83f-5a3d09261a41	{"id": "f5cc2ab6-bb92-4cab-b83f-5a3d09261a41", "code": "none", "name": "Not yet assigned", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.874Z", "updatedDate": "2025-05-16T18:12:34.874Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.874	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2a340d34-6b70-443a-bb1b-1b8d1c65d862	{"id": "2a340d34-6b70-443a-bb1b-1b8d1c65d862", "code": "other", "name": "Other", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.868Z", "updatedDate": "2025-05-16T18:12:34.868Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.868	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9634a5ab-9228-4703-baf2-4d12ebc77d56	{"id": "9634a5ab-9228-4703-baf2-4d12ebc77d56", "code": "cat", "name": "Cataloged", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.873Z", "updatedDate": "2025-05-16T18:12:34.873Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.873	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
daf2681c-25af-4202-a3fa-e58fdf806183	{"id": "daf2681c-25af-4202-a3fa-e58fdf806183", "code": "temp", "name": "Temporary", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.874Z", "updatedDate": "2025-05-16T18:12:34.874Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.874	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
26f5208e-110a-4394-be29-1569a8c84a65	{"id": "26f5208e-110a-4394-be29-1569a8c84a65", "code": "uncat", "name": "Uncataloged", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.880Z", "updatedDate": "2025-05-16T18:12:34.880Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.88	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
52a2ff34-2a12-420d-8539-21aa8d3cf5d8	{"id": "52a2ff34-2a12-420d-8539-21aa8d3cf5d8", "code": "batch", "name": "Batch Loaded", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.887Z", "updatedDate": "2025-05-16T18:12:34.887Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.887	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: instance_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.instance_type (id, jsonb) FROM stdin;
a2c91e87-6bab-44d6-8adb-1fd02481fc4f	{"id": "a2c91e87-6bab-44d6-8adb-1fd02481fc4f", "code": "xxx", "name": "other", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.203+00:00", "updatedDate": "2025-05-16T18:12:34.203+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
df5dddff-9c30-4507-8b82-119ff972d4d7	{"id": "df5dddff-9c30-4507-8b82-119ff972d4d7", "code": "cod", "name": "computer dataset", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.217+00:00", "updatedDate": "2025-05-16T18:12:34.217+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c7f7446f-4642-4d97-88c9-55bae2ad6c7f	{"id": "c7f7446f-4642-4d97-88c9-55bae2ad6c7f", "code": "spw", "name": "spoken word", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.231+00:00", "updatedDate": "2025-05-16T18:12:34.231+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
fbe264b5-69aa-4b7c-a230-3b53337f6440	{"id": "fbe264b5-69aa-4b7c-a230-3b53337f6440", "code": "ntv", "name": "notated movement", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.237+00:00", "updatedDate": "2025-05-16T18:12:34.237+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e5136fa2-1f19-4581-b005-6e007a940ca8	{"id": "e5136fa2-1f19-4581-b005-6e007a940ca8", "code": "crn", "name": "cartographic tactile three-dimensional form", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.246+00:00", "updatedDate": "2025-05-16T18:12:34.246+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
497b5090-3da2-486c-b57f-de5bb3c2e26d	{"id": "497b5090-3da2-486c-b57f-de5bb3c2e26d", "code": "ntm", "name": "notated music", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.264+00:00", "updatedDate": "2025-05-16T18:12:34.264+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
30fffe0e-e985-4144-b2e2-1e8179bdb41f	{"id": "30fffe0e-e985-4144-b2e2-1e8179bdb41f", "code": "zzz", "name": "unspecified", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.205+00:00", "updatedDate": "2025-05-16T18:12:34.205+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
efe2e89b-0525-4535-aa9b-3ff1a131189e	{"id": "efe2e89b-0525-4535-aa9b-3ff1a131189e", "code": "tci", "name": "tactile image", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.205+00:00", "updatedDate": "2025-05-16T18:12:34.205+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
8105bd44-e7bd-487e-a8f2-b804a361d92f	{"id": "8105bd44-e7bd-487e-a8f2-b804a361d92f", "code": "tct", "name": "tactile text", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.208+00:00", "updatedDate": "2025-05-16T18:12:34.208+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
2022aa2e-bdde-4dc4-90bc-115e8894b8b3	{"id": "2022aa2e-bdde-4dc4-90bc-115e8894b8b3", "code": "crf", "name": "cartographic three-dimensional form", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.215+00:00", "updatedDate": "2025-05-16T18:12:34.215+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
9bce18bd-45bf-4949-8fa8-63163e4b7d7f	{"id": "9bce18bd-45bf-4949-8fa8-63163e4b7d7f", "code": "snd", "name": "sounds", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.218+00:00", "updatedDate": "2025-05-16T18:12:34.218+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
6312d172-f0cf-40f6-b27d-9fa8feaf332f	{"id": "6312d172-f0cf-40f6-b27d-9fa8feaf332f", "code": "txt", "name": "text", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.220+00:00", "updatedDate": "2025-05-16T18:12:34.220+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c1e95c2b-4efc-48cf-9e71-edb622cf0c22	{"id": "c1e95c2b-4efc-48cf-9e71-edb622cf0c22", "code": "tdf", "name": "three-dimensional form", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.219+00:00", "updatedDate": "2025-05-16T18:12:34.219+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3be24c14-3551-4180-9292-26a786649c8b	{"id": "3be24c14-3551-4180-9292-26a786649c8b", "code": "prm", "name": "performed music", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.223+00:00", "updatedDate": "2025-05-16T18:12:34.223+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
535e3160-763a-42f9-b0c0-d8ed7df6e2a2	{"id": "535e3160-763a-42f9-b0c0-d8ed7df6e2a2", "code": "sti", "name": "still image", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.230+00:00", "updatedDate": "2025-05-16T18:12:34.230+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
526aa04d-9289-4511-8866-349299592c18	{"id": "526aa04d-9289-4511-8866-349299592c18", "code": "cri", "name": "cartographic image", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.231+00:00", "updatedDate": "2025-05-16T18:12:34.231+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3363cdb1-e644-446c-82a4-dc3a1d4395b9	{"id": "3363cdb1-e644-446c-82a4-dc3a1d4395b9", "code": "crd", "name": "cartographic dataset", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.233+00:00", "updatedDate": "2025-05-16T18:12:34.233+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
e6a278fb-565a-4296-a7c5-8eb63d259522	{"id": "e6a278fb-565a-4296-a7c5-8eb63d259522", "code": "tcn", "name": "tactile notated movement", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.233+00:00", "updatedDate": "2025-05-16T18:12:34.233+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
82689e16-629d-47f7-94b5-d89736cf11f2	{"id": "82689e16-629d-47f7-94b5-d89736cf11f2", "code": "tcf", "name": "tactile three-dimensional form", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.245+00:00", "updatedDate": "2025-05-16T18:12:34.245+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
80c0c134-0240-4b63-99d0-6ca755d5f433	{"id": "80c0c134-0240-4b63-99d0-6ca755d5f433", "code": "crm", "name": "cartographic moving image", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.246+00:00", "updatedDate": "2025-05-16T18:12:34.246+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
408f82f0-e612-4977-96a1-02076229e312	{"id": "408f82f0-e612-4977-96a1-02076229e312", "code": "crt", "name": "cartographic tactile image", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.248+00:00", "updatedDate": "2025-05-16T18:12:34.248+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
a67e00fd-dcce-42a9-9e75-fd654ec31e89	{"id": "a67e00fd-dcce-42a9-9e75-fd654ec31e89", "code": "tcm", "name": "tactile notated music", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.256+00:00", "updatedDate": "2025-05-16T18:12:34.256+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
3e3039b7-fda0-4ac4-885a-022d457cb99c	{"id": "3e3039b7-fda0-4ac4-885a-022d457cb99c", "code": "tdm", "name": "three-dimensional moving image", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.268+00:00", "updatedDate": "2025-05-16T18:12:34.268+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
c208544b-9e28-44fa-a13c-f4093d72f798	{"id": "c208544b-9e28-44fa-a13c-f4093d72f798", "code": "cop", "name": "computer program", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.269+00:00", "updatedDate": "2025-05-16T18:12:34.269+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
225faa14-f9bf-4ecd-990d-69433c912434	{"id": "225faa14-f9bf-4ecd-990d-69433c912434", "code": "tdi", "name": "two-dimensional moving image", "source": "rdacontent", "metadata": {"createdDate": "2025-05-16T18:12:34.272+00:00", "updatedDate": "2025-05-16T18:12:34.272+00:00", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}
\.


--
-- Data for Name: item; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.item (id, jsonb, creation_date, created_by, holdingsrecordid, permanentloantypeid, temporaryloantypeid, materialtypeid, permanentlocationid, temporarylocationid, effectivelocationid) FROM stdin;
f8b6d973-60d4-41ce-a57b-a3884471a6d6	{"id": "f8b6d973-60d4-41ce-a57b-a3884471a6d6", "hrid": "item000000000003", "notes": [], "status": {"date": "2025-05-16T18:12:36.474+00:00", "name": "Available"}, "barcode": "A14811392645", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.474Z", "updatedDate": "2025-05-16T18:12:36.474Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "chronology": "1986:Jan.-June", "enumeration": "v.72:no.1-6", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "0c45bb50-7c9b-48b0-86eb-178a494e25fe", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "K1 .M44 v.72:no.1-6 1986:Jan.-June", "effectiveCallNumberComponents": {"callNumber": "K1 .M44"}}	2025-05-16 18:12:36.474	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0c45bb50-7c9b-48b0-86eb-178a494e25fe	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
7212ba6a-8dcf-45a1-be9a-ffaa847c4423	{"id": "7212ba6a-8dcf-45a1-be9a-ffaa847c4423", "hrid": "item000000000014", "notes": [], "status": {"date": "2025-05-16T18:12:36.469+00:00", "name": "Available"}, "barcode": "10101", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.468Z", "updatedDate": "2025-05-16T18:12:36.468Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "chronology": "", "copyNumber": "Copy 2", "enumeration": "", "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "circulationNotes": [], "electronicAccess": [{"uri": "http://www.loc.gov/catdir/toc/ecip0718/2007020429.html", "linkText": "Links available", "publicNote": "Table of contents only", "relationshipId": "3b430592-2e09-4b48-9a0c-0636d66b9fb3", "materialsSpecification": "Table of contents"}], "holdingsRecordId": "e3ff6133-b9a2-4d4c-a1c9-dc1867d4df19", "statisticalCodeIds": ["b5968c9e-cddc-4576-99e3-8e60aed8b0dd"], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "itemLevelCallNumber": "TK5105.88815 . A58 2004 FT MEADE", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "effectiveShelvingOrder": "TK5105.88815 . A58 2004 FT MEADE Copy 2", "effectiveCallNumberComponents": {"typeId": "512173a7-bd09-490e-b773-17d83f2b63fe", "callNumber": "TK5105.88815 . A58 2004 FT MEADE"}}	2025-05-16 18:12:36.468	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e3ff6133-b9a2-4d4c-a1c9-dc1867d4df19	2b94c631-fca9-4892-a730-03ee529ffe27	\N	1a54b431-2e4f-452d-9cae-9cee66c9a892	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
eedd13c4-7d40-4b1e-8f77-b0b9d19a896b	{"id": "eedd13c4-7d40-4b1e-8f77-b0b9d19a896b", "hrid": "item000000000002", "notes": [], "status": {"date": "2025-05-16T18:12:36.492+00:00", "name": "Available"}, "barcode": "A1429864347", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.491Z", "updatedDate": "2025-05-16T18:12:36.491Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "chronology": "1986:July-Aug.,Oct.-Dec.", "enumeration": "v.72:no.6-7,10-12", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "0c45bb50-7c9b-48b0-86eb-178a494e25fe", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "K1 .M44 v.72:no.6-7,10-12 1986:July-Aug.,Oct.-Dec.", "effectiveCallNumberComponents": {"callNumber": "K1 .M44"}}	2025-05-16 18:12:36.491	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0c45bb50-7c9b-48b0-86eb-178a494e25fe	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
bb5a6689-c008-4c96-8f8f-b666850ee12d	{"id": "bb5a6689-c008-4c96-8f8f-b666850ee12d", "hrid": "item000000000012", "notes": [], "status": {"date": "2025-05-16T18:12:36.488+00:00", "name": "Checked out"}, "barcode": "326547658598", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.488Z", "updatedDate": "2025-05-16T18:12:36.488Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "67cd0046-e4f1-4e4f-9024-adf0b0039d09", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "f34d27c6-a8eb-461b-acd6-5dea81771e70", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "D15.H63 A3 2002", "effectiveCallNumberComponents": {"callNumber": "D15.H63 A3 2002"}}	2025-05-16 18:12:36.488	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	67cd0046-e4f1-4e4f-9024-adf0b0039d09	2b94c631-fca9-4892-a730-03ee529ffe27	\N	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	f34d27c6-a8eb-461b-acd6-5dea81771e70
9ea1fd0b-0259-4edb-95a3-eb2f9a063e20	{"id": "9ea1fd0b-0259-4edb-95a3-eb2f9a063e20", "hrid": "item000000000006", "notes": [], "status": {"date": "2025-05-16T18:12:36.489+00:00", "name": "Available"}, "barcode": "A14837334306", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.489Z", "updatedDate": "2025-05-16T18:12:36.489Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": ["3806267"], "chronology": "1984:Jan.-June", "copyNumber": "1", "enumeration": "v.70:no.1-6", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "0c45bb50-7c9b-48b0-86eb-178a494e25fe", "statisticalCodeIds": ["775b6ad4-9c35-4d29-bf78-8775a9b42226"], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "K1 .M44 v.70:no.1-6 1984:Jan.-June 1", "effectiveCallNumberComponents": {"callNumber": "K1 .M44"}}	2025-05-16 18:12:36.489	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0c45bb50-7c9b-48b0-86eb-178a494e25fe	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
459afaba-5b39-468d-9072-eb1685e0ddf4	{"id": "459afaba-5b39-468d-9072-eb1685e0ddf4", "hrid": "item000000000011", "notes": [], "status": {"date": "2025-05-16T18:12:36.558+00:00", "name": "Available"}, "barcode": "765475420716", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.558Z", "updatedDate": "2025-05-16T18:12:36.558Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "yearCaption": [], "materialTypeId": "5ee11d91-f7e8-481d-b079-65d708582ccc", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "65032151-39a5-4cef-8810-5350eb316300", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "53cf956f-c1df-410b-8bea-27f712cca7c0", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "temporaryLocationId": "53cf956f-c1df-410b-8bea-27f712cca7c0", "effectiveShelvingOrder": "MCN FICTION", "effectiveCallNumberComponents": {"callNumber": "MCN FICTION"}}	2025-05-16 18:12:36.558	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	65032151-39a5-4cef-8810-5350eb316300	2b94c631-fca9-4892-a730-03ee529ffe27	\N	5ee11d91-f7e8-481d-b079-65d708582ccc	\N	53cf956f-c1df-410b-8bea-27f712cca7c0	53cf956f-c1df-410b-8bea-27f712cca7c0
4428a37c-8bae-4f0d-865d-970d83d5ad55	{"id": "4428a37c-8bae-4f0d-865d-970d83d5ad55", "hrid": "item000000000009", "notes": [{"note": "Missing pages; p 10-13", "staffOnly": false, "itemNoteTypeId": "8d0a5eca-25de-4391-81a9-236eeefdd20b"}, {"note": "My action note", "staffOnly": false, "itemNoteTypeId": "0e40884c-3523-4c6d-8187-d578e3d2794e"}, {"note": "My copy note", "staffOnly": false, "itemNoteTypeId": "1dde7141-ec8a-4dae-9825-49ce14c728e7"}, {"note": "My provenance", "staffOnly": false, "itemNoteTypeId": "c3a539b9-9576-4e3a-b6de-d910200b2919"}, {"note": "My reproduction", "staffOnly": false, "itemNoteTypeId": "acb3a58f-1d72-461d-97c3-0e7119e8d544"}], "status": {"date": "2025-05-16T18:12:36.509+00:00", "name": "Available"}, "barcode": "4539876054382", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.508Z", "updatedDate": "2025-05-16T18:12:36.508Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "Copy 2", "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "numberOfPieces": "1", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "65cb2bf0-d4c2-4886-8ad0-b76f1ba75d61", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "temporaryLoanTypeId": "e8b311a6-3b21-43f2-a269-dd9310cb2d0e", "effectiveShelvingOrder": "PR6056.I4588 B749 2016 Copy 2", "effectiveCallNumberComponents": {"callNumber": "PR6056.I4588 B749 2016"}}	2025-05-16 18:12:36.508	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	65cb2bf0-d4c2-4886-8ad0-b76f1ba75d61	2b94c631-fca9-4892-a730-03ee529ffe27	e8b311a6-3b21-43f2-a269-dd9310cb2d0e	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
100d10bf-2f06-4aa0-be15-0b95b2d9f9e3	{"id": "100d10bf-2f06-4aa0-be15-0b95b2d9f9e3", "hrid": "item000000000015", "notes": [], "status": {"date": "2025-05-16T18:12:36.567+00:00", "name": "Available"}, "barcode": "90000", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.566Z", "updatedDate": "2025-05-16T18:12:36.566Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "chronology": "", "enumeration": "", "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "circulationNotes": [], "electronicAccess": [{"uri": "http://www.loc.gov/catdir/toc/ecip0718/2007020429.html", "linkText": "Links available", "publicNote": "Table of contents only", "relationshipId": "3b430592-2e09-4b48-9a0c-0636d66b9fb3", "materialsSpecification": "Table of contents"}], "holdingsRecordId": "e3ff6133-b9a2-4d4c-a1c9-dc1867d4df19", "statisticalCodeIds": ["b5968c9e-cddc-4576-99e3-8e60aed8b0dd"], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "itemLevelCallNumber": "TK5105.88815 . A58 2004 FT MEADE", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "permanentLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "effectiveShelvingOrder": "TK5105.88815 . A58 2004 FT MEADE", "effectiveCallNumberComponents": {"typeId": "512173a7-bd09-490e-b773-17d83f2b63fe", "callNumber": "TK5105.88815 . A58 2004 FT MEADE"}}	2025-05-16 18:12:36.566	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e3ff6133-b9a2-4d4c-a1c9-dc1867d4df19	2b94c631-fca9-4892-a730-03ee529ffe27	\N	1a54b431-2e4f-452d-9cae-9cee66c9a892	fcd64ce1-6995-48f0-840e-89ffa2288371	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
bc90a3c9-26c9-4519-96bc-d9d44995afef	{"id": "bc90a3c9-26c9-4519-96bc-d9d44995afef", "hrid": "item000000000001", "notes": [], "status": {"date": "2025-05-16T18:12:36.617+00:00", "name": "Available"}, "barcode": "A14811392695", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.617Z", "updatedDate": "2025-05-16T18:12:36.617Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "chronology": "1987:Jan.-June", "enumeration": "v.73:no.1-6", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "0c45bb50-7c9b-48b0-86eb-178a494e25fe", "statisticalCodeIds": [], "administrativeNotes": ["an administrative note"], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "K1 .M44 v.73:no.1-6 1987:Jan.-June", "effectiveCallNumberComponents": {"callNumber": "K1 .M44"}}	2025-05-16 18:12:36.617	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0c45bb50-7c9b-48b0-86eb-178a494e25fe	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
645549b1-2a73-4251-b8bb-39598f773a93	{"id": "645549b1-2a73-4251-b8bb-39598f773a93", "hrid": "item000000000004", "notes": [], "status": {"date": "2025-05-16T18:12:36.641+00:00", "name": "Available"}, "barcode": "A14813848587", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.638Z", "updatedDate": "2025-05-16T18:12:36.638Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "chronology": "1985:July-Dec.", "enumeration": "v.71:no.6-2", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "0c45bb50-7c9b-48b0-86eb-178a494e25fe", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "K1 .M44 v.71:no.6-2 1985:July-Dec.", "effectiveCallNumberComponents": {"callNumber": "K1 .M44"}}	2025-05-16 18:12:36.638	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0c45bb50-7c9b-48b0-86eb-178a494e25fe	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
f4b8c3d1-f461-4551-aa7b-5f45e64f236c	{"id": "f4b8c3d1-f461-4551-aa7b-5f45e64f236c", "hrid": "BW-ITEM-1", "tags": {"tagList": ["important"]}, "notes": [], "status": {"date": "2025-05-16T18:12:36.752+00:00", "name": "Available"}, "barcode": "X575181", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.752Z", "updatedDate": "2025-05-16T18:12:36.752Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "9e8dc8ce-68f3-4e75-8479-d548ce521157", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "1958 A 8050", "effectiveCallNumberComponents": {"prefix": "A", "typeId": "6caca63e-5651-4db6-9247-3205156e9699", "callNumber": "1958 A 8050"}}	2025-05-16 18:12:36.752	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	9e8dc8ce-68f3-4e75-8479-d548ce521157	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
23f2c8e1-bd5d-4f27-9398-a688c998808a	{"id": "23f2c8e1-bd5d-4f27-9398-a688c998808a", "hrid": "item000000000013", "notes": [], "status": {"date": "2025-05-16T18:12:36.564+00:00", "name": "Checked out"}, "barcode": "697685458679", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.563Z", "updatedDate": "2025-05-16T18:12:36.563Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "68872d8a-bf16-420b-829f-206da38f6c10", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210a4", "effectiveShelvingOrder": "some-callnumber", "effectiveCallNumberComponents": {"callNumber": "some-callnumber"}}	2025-05-16 18:12:36.563	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	68872d8a-bf16-420b-829f-206da38f6c10	2e48e713-17f3-4c13-a9f8-23845bb210a4	\N	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
1714f71f-b845-444b-a79e-a577487a6f7d	{"id": "1714f71f-b845-444b-a79e-a577487a6f7d", "hrid": "item000000000007", "notes": [], "status": {"date": "2025-05-16T18:12:36.614+00:00", "name": "Available"}, "barcode": "000111222333444", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.614Z", "updatedDate": "2025-05-16T18:12:36.614Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "c.1", "enumeration": "v. 30 1961", "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "133a7916-f05e-4df4-8f7f-09eb2a7076d1", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2e48e713-17f3-4c13-a9f8-23845bb210a4", "temporaryLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "R11.A38 v. 30 1961 c.1", "effectiveCallNumberComponents": {"callNumber": "R11.A38"}}	2025-05-16 18:12:36.614	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	133a7916-f05e-4df4-8f7f-09eb2a7076d1	2e48e713-17f3-4c13-a9f8-23845bb210a4	2b94c631-fca9-4892-a730-03ee529ffe27	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
d6f7c1ba-a237-465e-94ed-f37e91bc64bd	{"id": "d6f7c1ba-a237-465e-94ed-f37e91bc64bd", "hrid": "item000000000010", "notes": [], "status": {"date": "2025-05-16T18:12:36.642+00:00", "name": "Available"}, "barcode": "4539876054383", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.642Z", "updatedDate": "2025-05-16T18:12:36.642Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "Copy 3", "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "numberOfPieces": "1", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "fb7b70f1-b898-4924-a991-0e4b6312bb5f", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "53cf956f-c1df-410b-8bea-27f712cca7c0", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "temporaryLoanTypeId": "e8b311a6-3b21-43f2-a269-dd9310cb2d0e", "effectiveShelvingOrder": "PR6056.I4588 B749 2016 Copy 3", "effectiveCallNumberComponents": {"callNumber": "PR6056.I4588 B749 2016"}}	2025-05-16 18:12:36.642	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	fb7b70f1-b898-4924-a991-0e4b6312bb5f	2b94c631-fca9-4892-a730-03ee529ffe27	e8b311a6-3b21-43f2-a269-dd9310cb2d0e	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	53cf956f-c1df-410b-8bea-27f712cca7c0
0e67c5b4-8585-49c7-bc8a-e5c7c5fc3f34	{"id": "0e67c5b4-8585-49c7-bc8a-e5c7c5fc3f34", "hrid": "bwit0003", "notes": [], "status": {"date": "2025-05-16T18:12:36.922+00:00", "name": "Available"}, "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.922Z", "updatedDate": "2025-05-16T18:12:36.922Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "First copy of Q3", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "7fd55f10-6aec-4e25-a3cd-9ac7412ca26a", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "Holdings magazine Q3 First copy of Q3", "effectiveCallNumberComponents": {"callNumber": "Holdings magazine Q3"}}	2025-05-16 18:12:36.922	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	7fd55f10-6aec-4e25-a3cd-9ac7412ca26a	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
56780446-1735-4514-a933-06abe668610b	{"id": "56780446-1735-4514-a933-06abe668610b", "hrid": "bwit0006", "notes": [], "status": {"date": "2025-05-16T18:12:36.948+00:00", "name": "Available"}, "barcode": "BW-item2", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.947Z", "updatedDate": "2025-05-16T18:12:36.947Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "The bind of third copies of Q1,2,and 3", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "7a2443bc-fe66-40d5-9400-9a800fdf013e", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "Holdings magazine Q1 The bind of third copies of Q1,2,and 3", "effectiveCallNumberComponents": {"callNumber": "Holdings magazine Q1"}}	2025-05-16 18:12:36.947	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	7a2443bc-fe66-40d5-9400-9a800fdf013e	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
9428231b-dd31-4f70-8406-fe22fbdeabc2	{"id": "9428231b-dd31-4f70-8406-fe22fbdeabc2", "hrid": "item000000000005", "notes": [], "status": {"date": "2025-05-16T18:12:36.575+00:00", "name": "Available"}, "barcode": "A14837334314", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.574Z", "updatedDate": "2025-05-16T18:12:36.574Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "chronology": "1984:July-Dec.", "enumeration": "v.70:no.7-12", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "0c45bb50-7c9b-48b0-86eb-178a494e25fe", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "K1 .M44 v.70:no.7-12 1984:July-Dec.", "effectiveCallNumberComponents": {"callNumber": "K1 .M44"}}	2025-05-16 18:12:36.574	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0c45bb50-7c9b-48b0-86eb-178a494e25fe	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
0b96a642-5e7f-452d-9cae-9cee66c9a892	{"id": "0b96a642-5e7f-452d-9cae-9cee66c9a892", "hrid": "item000000000017", "notes": [], "status": {"date": "2025-05-16T18:12:36.618+00:00", "name": "Available"}, "barcode": "645398607547", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.618Z", "updatedDate": "2025-05-16T18:12:36.618Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "e6d7e91a-4dbc-4a70-9b38-e000d2fbdc79", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "some-callnumber", "effectiveCallNumberComponents": {"callNumber": "some-callnumber"}}	2025-05-16 18:12:36.618	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e6d7e91a-4dbc-4a70-9b38-e000d2fbdc79	2b94c631-fca9-4892-a730-03ee529ffe27	\N	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
e996ce40-2cbc-4468-a9db-53afcd03a760	{"id": "e996ce40-2cbc-4468-a9db-53afcd03a760", "hrid": "bwit0004", "notes": [], "status": {"date": "2025-05-16T18:12:36.924+00:00", "name": "Available"}, "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.923Z", "updatedDate": "2025-05-16T18:12:36.923Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "First copy of Q4", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "1ab1f67e-6ab8-40f0-8cc1-a199db309070", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "Holdings magazine Q4 First copy of Q4", "effectiveCallNumberComponents": {"callNumber": "Holdings magazine Q4"}}	2025-05-16 18:12:36.923	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	1ab1f67e-6ab8-40f0-8cc1-a199db309070	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
1b6d3338-186e-4e35-9e75-1b886b0da53e	{"id": "1b6d3338-186e-4e35-9e75-1b886b0da53e", "hrid": "item000000000008", "notes": [{"note": "Signed by the author", "staffOnly": false, "itemNoteTypeId": "8d0a5eca-25de-4391-81a9-236eeefdd20b"}], "status": {"date": "2025-05-16T18:12:36.596+00:00", "name": "Checked out"}, "barcode": "453987605438", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.596Z", "updatedDate": "2025-05-16T18:12:36.596Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "Copy 1", "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "numberOfPieces": "1", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "65cb2bf0-d4c2-4886-8ad0-b76f1ba75d61", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "temporaryLoanTypeId": "e8b311a6-3b21-43f2-a269-dd9310cb2d0e", "effectiveShelvingOrder": "PR6056.I4588 B749 2016 Copy 1", "effectiveCallNumberComponents": {"callNumber": "PR6056.I4588 B749 2016"}}	2025-05-16 18:12:36.596	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	65cb2bf0-d4c2-4886-8ad0-b76f1ba75d61	2b94c631-fca9-4892-a730-03ee529ffe27	e8b311a6-3b21-43f2-a269-dd9310cb2d0e	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
23fdb0bc-ab58-442a-b326-577a96204487	{"id": "23fdb0bc-ab58-442a-b326-577a96204487", "hrid": "item000000000016", "notes": [], "status": {"date": "2025-05-16T18:12:36.621+00:00", "name": "Available"}, "barcode": "653285216743", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.621Z", "updatedDate": "2025-05-16T18:12:36.621Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "yearCaption": [], "materialTypeId": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "e6d7e91a-4dbc-4a70-9b38-e000d2fbdc79", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "some-callnumber", "effectiveCallNumberComponents": {"callNumber": "some-callnumber"}}	2025-05-16 18:12:36.621	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e6d7e91a-4dbc-4a70-9b38-e000d2fbdc79	2b94c631-fca9-4892-a730-03ee529ffe27	\N	1a54b431-2e4f-452d-9cae-9cee66c9a892	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
6c7196d2-0c2a-4707-a196-ff6b9e84a75e	{"id": "6c7196d2-0c2a-4707-a196-ff6b9e84a75e", "hrid": "bwit000000001", "tags": {"tagList": []}, "notes": [], "status": {"date": "2025-05-16T18:12:36.751+00:00", "name": "Available"}, "barcode": "12", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.751Z", "updatedDate": "2025-05-16T18:12:36.751Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "13767c78-f8d0-425e-801d-cc5bd475856a", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "DE3", "effectiveCallNumberComponents": {"callNumber": "DE3"}}	2025-05-16 18:12:36.751	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	13767c78-f8d0-425e-801d-cc5bd475856a	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
4bf3d78b-fa14-4473-a7ab-75e7bce07456	{"id": "4bf3d78b-fa14-4473-a7ab-75e7bce07456", "hrid": "bwit0002", "notes": [], "status": {"date": "2025-05-16T18:12:36.925+00:00", "name": "Available"}, "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.924Z", "updatedDate": "2025-05-16T18:12:36.924Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "First copy of Q2", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "7af9a14d-6e92-4827-acab-eba65e08be6c", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "Holdings magazine Q2 First copy of Q2", "effectiveCallNumberComponents": {"callNumber": "Holdings magazine Q2"}}	2025-05-16 18:12:36.924	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	7af9a14d-6e92-4827-acab-eba65e08be6c	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
917e044f-173c-4445-8293-45a78ef49ace	{"id": "917e044f-173c-4445-8293-45a78ef49ace", "hrid": "bwit0005", "notes": [], "status": {"date": "2025-05-16T18:12:36.922+00:00", "name": "Available"}, "barcode": "BW-item1", "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.921Z", "updatedDate": "2025-05-16T18:12:36.921Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "The bind of second copies of Q1,2,3, and 4", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "7a2443bc-fe66-40d5-9400-9a800fdf013e", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "Holdings magazine Q1 The bind of second copies of Q1,2,3, and 4", "effectiveCallNumberComponents": {"callNumber": "Holdings magazine Q1"}}	2025-05-16 18:12:36.921	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	7a2443bc-fe66-40d5-9400-9a800fdf013e	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
bd9eee25-c36b-4f64-a5d0-8d31c277c8d3	{"id": "bd9eee25-c36b-4f64-a5d0-8d31c277c8d3", "hrid": "bwit0001", "notes": [], "status": {"date": "2025-05-16T18:12:36.929+00:00", "name": "Available"}, "_version": 1, "metadata": {"createdDate": "2025-05-16T18:12:36.929Z", "updatedDate": "2025-05-16T18:12:36.929Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "formerIds": [], "copyNumber": "First copy of Q1", "yearCaption": [], "materialTypeId": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "circulationNotes": [], "electronicAccess": [], "holdingsRecordId": "7a2443bc-fe66-40d5-9400-9a800fdf013e", "statisticalCodeIds": [], "administrativeNotes": [], "effectiveLocationId": "fcd64ce1-6995-48f0-840e-89ffa2288371", "permanentLoanTypeId": "2b94c631-fca9-4892-a730-03ee529ffe27", "effectiveShelvingOrder": "Holdings magazine Q1 First copy of Q1", "effectiveCallNumberComponents": {"callNumber": "Holdings magazine Q1"}}	2025-05-16 18:12:36.929	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	7a2443bc-fe66-40d5-9400-9a800fdf013e	2b94c631-fca9-4892-a730-03ee529ffe27	\N	d9acad2f-2aac-4b48-9097-e6ab85906b25	\N	\N	fcd64ce1-6995-48f0-840e-89ffa2288371
\.


--
-- Data for Name: item_damaged_status; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.item_damaged_status (id, jsonb, creation_date, created_by) FROM stdin;
54d1dd76-ea33-4bcb-955b-6b29df4f7930	{"id": "54d1dd76-ea33-4bcb-955b-6b29df4f7930", "name": "Damaged", "source": "local", "metadata": {"createdDate": "2025-05-16T18:12:35.649Z", "updatedDate": "2025-05-16T18:12:35.649Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.649	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
516b82eb-1f19-4a63-8c48-8f1a3e9ff311	{"id": "516b82eb-1f19-4a63-8c48-8f1a3e9ff311", "name": "Not Damaged", "source": "local", "metadata": {"createdDate": "2025-05-16T18:12:35.652Z", "updatedDate": "2025-05-16T18:12:35.652Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.652	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: item_note_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.item_note_type (id, jsonb, creation_date, created_by) FROM stdin;
87c450be-2033-41fb-80ba-dd2409883681	{"id": "87c450be-2033-41fb-80ba-dd2409883681", "name": "Binding", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.611Z", "updatedDate": "2025-05-16T18:12:35.611Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.611	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
f3ae3823-d096-4c65-8734-0c1efd2ffea8	{"id": "f3ae3823-d096-4c65-8734-0c1efd2ffea8", "name": "Electronic bookplate", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.614Z", "updatedDate": "2025-05-16T18:12:35.614Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.614	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
1dde7141-ec8a-4dae-9825-49ce14c728e7	{"id": "1dde7141-ec8a-4dae-9825-49ce14c728e7", "name": "Copy note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.609Z", "updatedDate": "2025-05-16T18:12:35.609Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.609	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
0e40884c-3523-4c6d-8187-d578e3d2794e	{"id": "0e40884c-3523-4c6d-8187-d578e3d2794e", "name": "Action note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.618Z", "updatedDate": "2025-05-16T18:12:35.618Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.618	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
acb3a58f-1d72-461d-97c3-0e7119e8d544	{"id": "acb3a58f-1d72-461d-97c3-0e7119e8d544", "name": "Reproduction", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.626Z", "updatedDate": "2025-05-16T18:12:35.626Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.626	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
8d0a5eca-25de-4391-81a9-236eeefdd20b	{"id": "8d0a5eca-25de-4391-81a9-236eeefdd20b", "name": "Note", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.626Z", "updatedDate": "2025-05-16T18:12:35.626Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.626	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c3a539b9-9576-4e3a-b6de-d910200b2919	{"id": "c3a539b9-9576-4e3a-b6de-d910200b2919", "name": "Provenance", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.618Z", "updatedDate": "2025-05-16T18:12:35.618Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.618	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: iteration_job; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.iteration_job (id, jsonb) FROM stdin;
\.


--
-- Data for Name: loan_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.loan_type (id, jsonb, creation_date, created_by) FROM stdin;
2e48e713-17f3-4c13-a9f8-23845bb210a4	{"id": "2e48e713-17f3-4c13-a9f8-23845bb210a4", "name": "Reading room", "metadata": {"createdDate": "2025-05-16T18:12:32.243Z", "updatedDate": "2025-05-16T18:12:32.243Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.243	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
a1dc1ce3-d56f-4d8a-b498-d5d674ccc845	{"id": "a1dc1ce3-d56f-4d8a-b498-d5d674ccc845", "name": "Selected", "metadata": {"createdDate": "2025-05-16T18:12:32.244Z", "updatedDate": "2025-05-16T18:12:32.244Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.244	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2b94c631-fca9-4892-a730-03ee529ffe27	{"id": "2b94c631-fca9-4892-a730-03ee529ffe27", "name": "Can circulate", "metadata": {"createdDate": "2025-05-16T18:12:32.249Z", "updatedDate": "2025-05-16T18:12:32.249Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.249	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
e8b311a6-3b21-43f2-a269-dd9310cb2d0e	{"id": "e8b311a6-3b21-43f2-a269-dd9310cb2d0e", "name": "Course reserves", "metadata": {"createdDate": "2025-05-16T18:12:32.251Z", "updatedDate": "2025-05-16T18:12:32.251Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.251	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: location; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.location (id, jsonb, creation_date, created_by, institutionid, campusid, libraryid) FROM stdin;
b241764c-1466-4e1d-a028-1a3684a5da87	{"id": "b241764c-1466-4e1d-a028-1a3684a5da87", "code": "KU/CC/DI/P", "name": "Popular Reading Collection", "campusId": "62cf76b7-cca5-4d33-9217-edf42ce1a848", "isActive": true, "metadata": {"createdDate": "2025-05-16T18:12:35.844Z", "updatedDate": "2025-05-16T18:12:35.844Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "libraryId": "5d78803e-ca04-4b4a-aeae-2c63b924518b", "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57", "servicePoints": [], "servicePointIds": ["3a40852d-49fd-4df2-a1f9-6e2641a6e91f"], "primaryServicePoint": "3a40852d-49fd-4df2-a1f9-6e2641a6e91f"}	2025-05-16 18:12:35.844	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57	62cf76b7-cca5-4d33-9217-edf42ce1a848	5d78803e-ca04-4b4a-aeae-2c63b924518b
53cf956f-c1df-410b-8bea-27f712cca7c0	{"id": "53cf956f-c1df-410b-8bea-27f712cca7c0", "code": "KU/CC/DI/A", "name": "Annex", "campusId": "62cf76b7-cca5-4d33-9217-edf42ce1a848", "isActive": true, "metadata": {"createdDate": "2025-05-16T18:12:35.852Z", "updatedDate": "2025-05-16T18:12:35.852Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "libraryId": "5d78803e-ca04-4b4a-aeae-2c63b924518b", "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57", "servicePoints": [], "servicePointIds": ["3a40852d-49fd-4df2-a1f9-6e2641a6e91f"], "primaryServicePoint": "3a40852d-49fd-4df2-a1f9-6e2641a6e91f"}	2025-05-16 18:12:35.852	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57	62cf76b7-cca5-4d33-9217-edf42ce1a848	5d78803e-ca04-4b4a-aeae-2c63b924518b
fcd64ce1-6995-48f0-840e-89ffa2288371	{"id": "fcd64ce1-6995-48f0-840e-89ffa2288371", "code": "KU/CC/DI/M", "name": "Main Library", "campusId": "62cf76b7-cca5-4d33-9217-edf42ce1a848", "isActive": true, "metadata": {"createdDate": "2025-05-16T18:12:35.851Z", "updatedDate": "2025-05-16T18:12:35.851Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "libraryId": "5d78803e-ca04-4b4a-aeae-2c63b924518b", "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57", "servicePoints": [], "servicePointIds": ["3a40852d-49fd-4df2-a1f9-6e2641a6e91f"], "primaryServicePoint": "3a40852d-49fd-4df2-a1f9-6e2641a6e91f"}	2025-05-16 18:12:35.851	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57	62cf76b7-cca5-4d33-9217-edf42ce1a848	5d78803e-ca04-4b4a-aeae-2c63b924518b
758258bc-ecc1-41b8-abca-f7b610822ffd	{"id": "758258bc-ecc1-41b8-abca-f7b610822ffd", "code": "KU/CC/DI/O", "name": "ORWIG ETHNO CD", "campusId": "62cf76b7-cca5-4d33-9217-edf42ce1a848", "isActive": true, "metadata": {"createdDate": "2025-05-16T18:12:35.849Z", "updatedDate": "2025-05-16T18:12:35.849Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "libraryId": "5d78803e-ca04-4b4a-aeae-2c63b924518b", "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57", "servicePoints": [], "servicePointIds": ["3a40852d-49fd-4df2-a1f9-6e2641a6e91f"], "primaryServicePoint": "3a40852d-49fd-4df2-a1f9-6e2641a6e91f"}	2025-05-16 18:12:35.849	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57	62cf76b7-cca5-4d33-9217-edf42ce1a848	5d78803e-ca04-4b4a-aeae-2c63b924518b
184aae84-a5bf-4c6a-85ba-4a7c73026cd5	{"id": "184aae84-a5bf-4c6a-85ba-4a7c73026cd5", "code": "E", "name": "Online", "campusId": "470ff1dd-937a-4195-bf9e-06bcfcd135df", "isActive": true, "metadata": {"createdDate": "2025-05-16T18:12:35.859Z", "updatedDate": "2025-05-16T18:12:35.859Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "libraryId": "c2549bb4-19c7-4fcc-8b52-39e612fb7dbe", "description": "Use for online resources", "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57", "servicePoints": [], "servicePointIds": ["bba36e5d-d567-45fa-81cd-b25874472e30"], "primaryServicePoint": "bba36e5d-d567-45fa-81cd-b25874472e30", "discoveryDisplayName": "Online"}	2025-05-16 18:12:35.859	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57	470ff1dd-937a-4195-bf9e-06bcfcd135df	c2549bb4-19c7-4fcc-8b52-39e612fb7dbe
f34d27c6-a8eb-461b-acd6-5dea81771e70	{"id": "f34d27c6-a8eb-461b-acd6-5dea81771e70", "code": "KU/CC/DI/2", "name": "SECOND FLOOR", "campusId": "62cf76b7-cca5-4d33-9217-edf42ce1a848", "isActive": true, "metadata": {"createdDate": "2025-05-16T18:12:35.861Z", "updatedDate": "2025-05-16T18:12:35.861Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "libraryId": "5d78803e-ca04-4b4a-aeae-2c63b924518b", "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57", "servicePoints": [], "servicePointIds": ["3a40852d-49fd-4df2-a1f9-6e2641a6e91f"], "primaryServicePoint": "3a40852d-49fd-4df2-a1f9-6e2641a6e91f"}	2025-05-16 18:12:35.861	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57	62cf76b7-cca5-4d33-9217-edf42ce1a848	5d78803e-ca04-4b4a-aeae-2c63b924518b
\.


--
-- Data for Name: loccampus; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.loccampus (id, jsonb, creation_date, created_by, institutionid) FROM stdin;
470ff1dd-937a-4195-bf9e-06bcfcd135df	{"id": "470ff1dd-937a-4195-bf9e-06bcfcd135df", "code": "E", "name": "Online", "metadata": {"createdDate": "2025-05-16T18:12:35.771Z", "updatedDate": "2025-05-16T18:12:35.771Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57"}	2025-05-16 18:12:35.771	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57
62cf76b7-cca5-4d33-9217-edf42ce1a848	{"id": "62cf76b7-cca5-4d33-9217-edf42ce1a848", "code": "CC", "name": "City Campus", "metadata": {"createdDate": "2025-05-16T18:12:35.773Z", "updatedDate": "2025-05-16T18:12:35.773Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "institutionId": "40ee00ca-a518-4b49-be01-0638d0a4ac57"}	2025-05-16 18:12:35.773	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	40ee00ca-a518-4b49-be01-0638d0a4ac57
\.


--
-- Data for Name: locinstitution; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.locinstitution (id, jsonb, creation_date, created_by) FROM stdin;
40ee00ca-a518-4b49-be01-0638d0a4ac57	{"id": "40ee00ca-a518-4b49-be01-0638d0a4ac57", "code": "KU", "name": "Københavns Universitet", "metadata": {"createdDate": "2025-05-16T18:12:35.753Z", "updatedDate": "2025-05-16T18:12:35.753Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.753	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: loclibrary; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.loclibrary (id, jsonb, creation_date, created_by, campusid) FROM stdin;
5d78803e-ca04-4b4a-aeae-2c63b924518b	{"id": "5d78803e-ca04-4b4a-aeae-2c63b924518b", "code": "DI", "name": "Datalogisk Institut", "campusId": "62cf76b7-cca5-4d33-9217-edf42ce1a848", "metadata": {"createdDate": "2025-05-16T18:12:35.790Z", "updatedDate": "2025-05-16T18:12:35.790Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.79	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	62cf76b7-cca5-4d33-9217-edf42ce1a848
c2549bb4-19c7-4fcc-8b52-39e612fb7dbe	{"id": "c2549bb4-19c7-4fcc-8b52-39e612fb7dbe", "code": "E", "name": "Online", "campusId": "470ff1dd-937a-4195-bf9e-06bcfcd135df", "metadata": {"createdDate": "2025-05-16T18:12:35.794Z", "updatedDate": "2025-05-16T18:12:35.794Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.794	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	470ff1dd-937a-4195-bf9e-06bcfcd135df
\.


--
-- Data for Name: material_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.material_type (id, jsonb, creation_date, created_by) FROM stdin;
71fbd940-1027-40a6-8a48-49b44d795e46	{"id": "71fbd940-1027-40a6-8a48-49b44d795e46", "name": "unspecified", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.171Z", "updatedDate": "2025-05-16T18:12:32.171Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.171	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
dd0bf600-dbd9-44ab-9ff2-e2a61a6539f1	{"id": "dd0bf600-dbd9-44ab-9ff2-e2a61a6539f1", "name": "sound recording", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.175Z", "updatedDate": "2025-05-16T18:12:32.175Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.175	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
30b3e36a-d3b2-415e-98c2-47fbdf878862	{"id": "30b3e36a-d3b2-415e-98c2-47fbdf878862", "name": "video recording", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.187Z", "updatedDate": "2025-05-16T18:12:32.187Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.187	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
d9acad2f-2aac-4b48-9097-e6ab85906b25	{"id": "d9acad2f-2aac-4b48-9097-e6ab85906b25", "name": "text", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.191Z", "updatedDate": "2025-05-16T18:12:32.191Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.191	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
1a54b431-2e4f-452d-9cae-9cee66c9a892	{"id": "1a54b431-2e4f-452d-9cae-9cee66c9a892", "name": "book", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.195Z", "updatedDate": "2025-05-16T18:12:32.195Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.195	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
5ee11d91-f7e8-481d-b079-65d708582ccc	{"id": "5ee11d91-f7e8-481d-b079-65d708582ccc", "name": "dvd", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.210Z", "updatedDate": "2025-05-16T18:12:32.210Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.21	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
615b8413-82d5-4203-aa6e-e37984cb5ac3	{"id": "615b8413-82d5-4203-aa6e-e37984cb5ac3", "name": "electronic resource", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.208Z", "updatedDate": "2025-05-16T18:12:32.208Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.208	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
fd6c6515-d470-4561-9c32-3e3290d4ca98	{"id": "fd6c6515-d470-4561-9c32-3e3290d4ca98", "name": "microform", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:32.205Z", "updatedDate": "2025-05-16T18:12:32.205Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:32.205	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: mode_of_issuance; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.mode_of_issuance (id, jsonb, creation_date, created_by) FROM stdin;
9d18a02f-5897-4c31-9106-c9abb5c7ae8b	{"id": "9d18a02f-5897-4c31-9106-c9abb5c7ae8b", "name": "single unit", "source": "rdamodeissue", "metadata": {"createdDate": "2025-05-16T18:12:35.105Z", "updatedDate": "2025-05-16T18:12:35.105Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.105	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
4fc0f4fe-06fd-490a-a078-c4da1754e03a	{"id": "4fc0f4fe-06fd-490a-a078-c4da1754e03a", "name": "integrating resource", "source": "rdamodeissue", "metadata": {"createdDate": "2025-05-16T18:12:35.109Z", "updatedDate": "2025-05-16T18:12:35.109Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.109	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
612bbd3d-c16b-4bfb-8517-2afafc60204a	{"id": "612bbd3d-c16b-4bfb-8517-2afafc60204a", "name": "unspecified", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.108Z", "updatedDate": "2025-05-16T18:12:35.108Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.108	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
f5cc2ab6-bb92-4cab-b83f-5a3d09261a41	{"id": "f5cc2ab6-bb92-4cab-b83f-5a3d09261a41", "name": "multipart monograph", "source": "rdamodeissue", "metadata": {"createdDate": "2025-05-16T18:12:35.109Z", "updatedDate": "2025-05-16T18:12:35.109Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.109	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
068b5344-e2a6-40df-9186-1829e13cd344	{"id": "068b5344-e2a6-40df-9186-1829e13cd344", "name": "serial", "source": "rdamodeissue", "metadata": {"createdDate": "2025-05-16T18:12:35.109Z", "updatedDate": "2025-05-16T18:12:35.109Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:35.109	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: nature_of_content_term; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.nature_of_content_term (id, jsonb, creation_date, created_by) FROM stdin;
71b43e3a-8cdd-4d22-9751-020f34fb6ef8	{"id": "71b43e3a-8cdd-4d22-9751-020f34fb6ef8", "name": "report", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.655Z", "updatedDate": "2025-05-16T18:12:34.655Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.655	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
631893b6-5d8a-4e1a-9e6b-5344e2945c74	{"id": "631893b6-5d8a-4e1a-9e6b-5344e2945c74", "name": "illustrated book / picture book", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.658Z", "updatedDate": "2025-05-16T18:12:34.658Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.658	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
44cd89f3-2e76-469f-a955-cc57cb9e0395	{"id": "44cd89f3-2e76-469f-a955-cc57cb9e0395", "name": "textbook", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.659Z", "updatedDate": "2025-05-16T18:12:34.659Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.659	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
ebbbdef1-00e1-428b-bc11-314dc0705074	{"id": "ebbbdef1-00e1-428b-bc11-314dc0705074", "name": "newspaper", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.662Z", "updatedDate": "2025-05-16T18:12:34.662Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.662	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
94f6d06a-61e0-47c1-bbcb-6186989e6040	{"id": "94f6d06a-61e0-47c1-bbcb-6186989e6040", "name": "thesis", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.669Z", "updatedDate": "2025-05-16T18:12:34.669Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.669	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c0d52f31-aabb-4c55-bf81-fea7fdda94a4	{"id": "c0d52f31-aabb-4c55-bf81-fea7fdda94a4", "name": "experience report", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.672Z", "updatedDate": "2025-05-16T18:12:34.672Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.672	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
4570a93e-ddb6-4200-8e8b-283c8f5c9bfa	{"id": "4570a93e-ddb6-4200-8e8b-283c8f5c9bfa", "name": "research report", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.672Z", "updatedDate": "2025-05-16T18:12:34.672Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.672	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
536da7c1-9c35-45df-8ea1-c3545448df92	{"id": "536da7c1-9c35-45df-8ea1-c3545448df92", "name": "monographic series", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.674Z", "updatedDate": "2025-05-16T18:12:34.674Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.674	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
04a6a8d2-f902-4774-b15f-d8bd885dc804	{"id": "04a6a8d2-f902-4774-b15f-d8bd885dc804", "name": "autobiography", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.676Z", "updatedDate": "2025-05-16T18:12:34.676Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.676	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b29d4dc1-f78b-48fe-b3e5-df6c37cdc58d	{"id": "b29d4dc1-f78b-48fe-b3e5-df6c37cdc58d", "name": "festschrift", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.683Z", "updatedDate": "2025-05-16T18:12:34.683Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.683	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
0abeee3d-8ad2-4b04-92ff-221b4fce1075	{"id": "0abeee3d-8ad2-4b04-92ff-221b4fce1075", "name": "journal", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.686Z", "updatedDate": "2025-05-16T18:12:34.686Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.686	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b6e214bd-82f5-467f-af5b-4592456dc4ab	{"id": "b6e214bd-82f5-467f-af5b-4592456dc4ab", "name": "biography", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.686Z", "updatedDate": "2025-05-16T18:12:34.686Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.686	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
9419a20e-6c8f-4ae1-85a7-8c184a1f4762	{"id": "9419a20e-6c8f-4ae1-85a7-8c184a1f4762", "name": "travel report", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.688Z", "updatedDate": "2025-05-16T18:12:34.688Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.688	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
073f7f2f-9212-4395-b039-6f9825b11d54	{"id": "073f7f2f-9212-4395-b039-6f9825b11d54", "name": "proceedings", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.688Z", "updatedDate": "2025-05-16T18:12:34.688Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.688	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
b82b3a0d-00fa-4811-96da-04f531da8ea8	{"id": "b82b3a0d-00fa-4811-96da-04f531da8ea8", "name": "exhibition catalogue", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.692Z", "updatedDate": "2025-05-16T18:12:34.692Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.692	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
96879b60-098b-453b-bf9a-c47866f1ab2a	{"id": "96879b60-098b-453b-bf9a-c47866f1ab2a", "name": "audiobook", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.698Z", "updatedDate": "2025-05-16T18:12:34.698Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.698	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
2fbc8a7b-b432-45df-ba37-46031b1f6545	{"id": "2fbc8a7b-b432-45df-ba37-46031b1f6545", "name": "website", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.701Z", "updatedDate": "2025-05-16T18:12:34.701Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.701	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
acceb2d6-4f05-408f-9a88-a92de26441ce	{"id": "acceb2d6-4f05-408f-9a88-a92de26441ce", "name": "comic (book)", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.703Z", "updatedDate": "2025-05-16T18:12:34.703Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.703	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
31572023-f4c9-4cf3-80a2-0543c9eda884	{"id": "31572023-f4c9-4cf3-80a2-0543c9eda884", "name": "literature report", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.702Z", "updatedDate": "2025-05-16T18:12:34.702Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.702	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
85657646-6b6f-4e71-b54c-d47f3b95a5ed	{"id": "85657646-6b6f-4e71-b54c-d47f3b95a5ed", "name": "school program", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.704Z", "updatedDate": "2025-05-16T18:12:34.704Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.704	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
f5908d05-b16a-49cf-b192-96d55a94a0d1	{"id": "f5908d05-b16a-49cf-b192-96d55a94a0d1", "name": "bibliography", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.709Z", "updatedDate": "2025-05-16T18:12:34.709Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.709	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: notification_sending_error; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.notification_sending_error (id, jsonb) FROM stdin;
\.


--
-- Data for Name: preceding_succeeding_title; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.preceding_succeeding_title (id, jsonb, creation_date, created_by, precedinginstanceid, succeedinginstanceid) FROM stdin;
\.


--
-- Data for Name: reindex_job; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.reindex_job (id, jsonb) FROM stdin;
\.


--
-- Data for Name: related_instance_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.related_instance_type (id, jsonb) FROM stdin;
\.


--
-- Data for Name: rmb_internal; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.rmb_internal (id, jsonb) FROM stdin;
1	{"rmbVersion": "35.2.2", "schemaJson": "{\\n  \\"tables\\": [\\n    {\\n      \\"tableName\\": \\"authority\\",\\n      \\"mode\\": \\"delete\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"withOptimisticLocking\\": \\"failOnConflict\\"\\n    },\\n    {\\n      \\"tableName\\": \\"loan_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"material_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"locinstitution\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"loccampus\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"institutionId\\",\\n          \\"targetTable\\": \\"locinstitution\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"loclibrary\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"campusId\\",\\n          \\"targetTable\\": \\"loccampus\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"location\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"code\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"institutionId\\",\\n          \\"targetTable\\": \\"locinstitution\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"campusId\\",\\n          \\"targetTable\\": \\"loccampus\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"libraryId\\",\\n          \\"targetTable\\": \\"loclibrary\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"index\\": [\\n        {\\n          \\"fieldName\\": \\"primaryServicePoint\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"service_point\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"code\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"index\\": [\\n        {\\n          \\"fieldName\\": \\"pickupLocation\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"service_point_user\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"userId\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"defaultServicePointId\\",\\n          \\"targetTable\\": \\"service_point\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"identifier_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance_relationship_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"contributor_type\\",\\n      \\"withMetadata\\": false,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"code\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"contributor_name_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance_type\\",\\n      \\"withMetadata\\": false,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"code\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance_format\\",\\n      \\"withMetadata\\": false,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"code\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"nature_of_content_term\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"classification_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"electronic_access_relationship\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"statistical_code_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"code\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"statistical_code\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"code, statisticalCodeTypeId\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"statisticalCodeTypeId\\",\\n          \\"targetTable\\": \\"statistical_code_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance_status\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"code\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"mode_of_issuance\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"alternative_title_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance\\",\\n      \\"fromModuleVersion\\": \\"19.2.0\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": true,\\n      \\"withOptimisticLocking\\": \\"failOnConflictUnlessSuppressed\\",\\n      \\"auditingTableName\\": \\"audit_instance\\",\\n      \\"auditingFieldName\\": \\"record\\",\\n      \\"customSnippetPath\\": \\"audit-delete-trigger.sql\\",\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"instanceStatusId\\",\\n          \\"targetTable\\": \\"instance_status\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"modeOfIssuanceId\\",\\n          \\"targetTable\\": \\"mode_of_issuance\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"instanceTypeId\\",\\n          \\"targetTable\\": \\"instance_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"hrid\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"matchKey\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"ginIndex\\": [\\n        {\\n          \\"fieldName\\": \\"identifiers\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": true\\n        }\\n      ],\\n      \\"index\\": [\\n        {\\n          \\"fieldName\\": \\"source\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"indexTitle\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": true\\n        },\\n        {\\n          \\"fieldName\\": \\"title\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": true\\n        },\\n        {\\n          \\"fieldName\\": \\"statisticalCodeIds\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"contributors\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": true\\n        },\\n        {\\n          \\"fieldName\\": \\"publication\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": true\\n        },\\n        {\\n          \\"fieldName\\": \\"staffSuppress\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"discoverySuppress\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"metadata.updatedDate\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        }\\n      ],\\n      \\"fullTextIndex\\": [\\n        {\\n          \\"fieldName\\": \\"identifiers\\",\\n          \\"arraySubfield\\": \\"value\\",\\n          \\"arrayModifiers\\": [\\n            \\"identifierTypeId\\"\\n          ]\\n        },\\n        {\\n          \\"fieldName\\": \\"invalidIsbn\\",\\n          \\"sqlExpression\\": \\"normalize_invalid_isbns(jsonb->'identifiers')\\",\\n          \\"sqlExpressionQuery\\": \\"normalize_digits($)\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"isbn\\",\\n          \\"sqlExpression\\": \\"normalize_isbns(jsonb->'identifiers')\\",\\n          \\"sqlExpressionQuery\\": \\"normalize_digits($)\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance_relationship\\",\\n      \\"withMetadata\\": true,\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"superInstanceId\\",\\n          \\"targetTable\\": \\"instance\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"subInstanceId\\",\\n          \\"targetTable\\": \\"instance\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"instanceRelationshipTypeId\\",\\n          \\"targetTable\\": \\"instance_relationship_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance_source_marc\\",\\n      \\"withMetadata\\": true,\\n      \\"customSnippetPath\\": \\"instanceSourceMarc.sql\\"\\n    },\\n    {\\n      \\"tableName\\": \\"ill_policy\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"call_number_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"holdings_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"authority_note_type\\",\\n      \\"mode\\": \\"delete\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"instance_note_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"holdings_note_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"item_note_type\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"item_damaged_status\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"holdings_records_source\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"holdings_record\\",\\n      \\"fromModuleVersion\\": \\"19.2.0\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": true,\\n      \\"withOptimisticLocking\\": \\"failOnConflictUnlessSuppressed\\",\\n      \\"auditingTableName\\": \\"audit_holdings_record\\",\\n      \\"auditingFieldName\\": \\"record\\",\\n      \\"customSnippetPath\\": \\"audit-delete-trigger.sql\\",\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"instanceId\\",\\n          \\"targetTable\\": \\"instance\\",\\n          \\"targetTableAlias\\": \\"instance\\",\\n          \\"tableAlias\\": \\"holdingsRecords\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"permanentLocationId\\",\\n          \\"targetTable\\": \\"location\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"temporaryLocationId\\",\\n          \\"targetTable\\": \\"location\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"effectiveLocationId\\",\\n          \\"targetTable\\": \\"location\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"holdingsTypeId\\",\\n          \\"targetTable\\": \\"holdings_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"callNumberTypeId\\",\\n          \\"targetTable\\": \\"call_number_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"illPolicyId\\",\\n          \\"targetTable\\": \\"ill_policy\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"sourceId\\",\\n          \\"targetTable\\": \\"holdings_records_source\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"hrid\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"ginIndex\\": [\\n      ],\\n      \\"index\\": [\\n        {\\n          \\"fieldName\\": \\"callNumber\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"callNumberAndSuffix\\",\\n          \\"multiFieldNames\\": \\"callNumber, callNumberSuffix\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"fullCallNumber\\",\\n          \\"multiFieldNames\\": \\"callNumberPrefix, callNumber, callNumberSuffix\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"discoverySuppress\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        }\\n      ],\\n      \\"fullTextIndex\\": [\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"item\\",\\n      \\"withMetadata\\": true,\\n      \\"fromModuleVersion\\": \\"19.2.0\\",\\n      \\"withAuditing\\": true,\\n      \\"withOptimisticLocking\\": \\"failOnConflictUnlessSuppressed\\",\\n      \\"auditingTableName\\": \\"audit_item\\",\\n      \\"auditingFieldName\\": \\"record\\",\\n      \\"customSnippetPath\\": \\"audit-delete-trigger.sql\\",\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"holdingsRecordId\\",\\n          \\"targetTable\\": \\"holdings_record\\",\\n          \\"targetTableAlias\\": \\"holdingsRecords\\",\\n          \\"tableAlias\\": \\"item\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"targetPath\\": [\\n            \\"holdingsRecordId\\",\\n            \\"instanceId\\"\\n          ],\\n          \\"targetTable\\": \\"instance\\",\\n          \\"targetTableAlias\\": \\"instance\\",\\n          \\"tableAlias\\": \\"item\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"permanentLoanTypeId\\",\\n          \\"targetTable\\": \\"loan_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"temporaryLoanTypeId\\",\\n          \\"targetTable\\": \\"loan_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"materialTypeId\\",\\n          \\"targetTable\\": \\"material_type\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"permanentLocationId\\",\\n          \\"targetTable\\": \\"location\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"temporaryLocationId\\",\\n          \\"targetTable\\": \\"location\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"effectiveLocationId\\",\\n          \\"targetTable\\": \\"location\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"barcode\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"hrid\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"index\\": [\\n        {\\n          \\"fieldName\\": \\"accessionNumber\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"status.name\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": true\\n        },\\n        {\\n          \\"fieldName\\": \\"callNumberAndSuffix\\",\\n          \\"multiFieldNames\\": \\"effectiveCallNumberComponents.callNumber, effectiveCallNumberComponents.suffix\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"fullCallNumber\\",\\n          \\"multiFieldNames\\": \\"effectiveCallNumberComponents.prefix, effectiveCallNumberComponents.callNumber, effectiveCallNumberComponents.suffix\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"discoverySuppress\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"purchaseOrderLineIdentifier\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        },\\n        {\\n          \\"fieldName\\": \\"effectiveCallNumberComponents.callNumber\\",\\n          \\"tOps\\": \\"ADD\\",\\n          \\"caseSensitive\\": false,\\n          \\"removeAccents\\": false\\n        }\\n      ],\\n      \\"ginIndex\\": [\\n      ],\\n      \\"fullTextIndex\\": [\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"hrid_settings\\",\\n      \\"fromModuleVersion\\": \\"25.1.0\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"customSnippetPath\\": \\"hridSettings.sql\\"\\n    },\\n    {\\n      \\"tableName\\": \\"preceding_succeeding_title\\",\\n      \\"fromModuleVersion\\": \\"19.0.0\\",\\n      \\"withMetadata\\": true,\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"precedingInstanceId\\",\\n          \\"targetTable\\": \\"instance\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"succeedingInstanceId\\",\\n          \\"targetTable\\": \\"instance\\"\\n        }\\n      ],\\n      \\"customSnippetPath\\": \\"alterPrecedingSucceedingTitle.sql\\"\\n    },\\n    {\\n      \\"tableName\\": \\"reindex_job\\",\\n      \\"withMetadata\\": false,\\n      \\"withAuditing\\": false\\n    },\\n    {\\n      \\"tableName\\": \\"bound_with_part\\",\\n      \\"withMetadata\\": true,\\n      \\"foreignKeys\\": [\\n        {\\n          \\"fieldName\\": \\"itemId\\",\\n          \\"targetTable\\": \\"item\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"holdingsRecordId\\",\\n          \\"targetTable\\": \\"holdings_record\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ],\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"itemId, holdingsRecordId\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    },\\n    {\\n      \\"tableName\\": \\"notification_sending_error\\",\\n      \\"withMetadata\\": false,\\n      \\"withAuditing\\": false\\n    },\\n    {\\n      \\"tableName\\": \\"iteration_job\\",\\n      \\"withMetadata\\": false,\\n      \\"withAuditing\\": false\\n    },\\n    {\\n      \\"tableName\\": \\"related_instance_type\\",\\n      \\"mode\\": \\"DELETE\\"\\n    },\\n    {\\n      \\"tableName\\": \\"async_migration_job\\",\\n      \\"withMetadata\\": false,\\n      \\"withAuditing\\": false\\n    },\\n    {\\n      \\"tableName\\": \\"authority_source_file\\",\\n      \\"mode\\": \\"delete\\",\\n      \\"withMetadata\\": true,\\n      \\"withAuditing\\": false,\\n      \\"uniqueIndex\\": [\\n        {\\n          \\"fieldName\\": \\"name\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"codes\\",\\n          \\"tOps\\": \\"ADD\\"\\n        },\\n        {\\n          \\"fieldName\\": \\"baseUrl\\",\\n          \\"tOps\\": \\"ADD\\"\\n        }\\n      ]\\n    }\\n  ],\\n  \\"scripts\\": [\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"setPreviouslyHeldDefault.sql\\",\\n      \\"fromModuleVersion\\": \\"20.2.0\\"\\n    },\\n    {\\n      \\"run\\": \\"before\\",\\n      \\"snippetPath\\": \\"populateRmbInternalIndex.sql\\",\\n      \\"fromModuleVersion\\": \\"19.1.1\\"\\n    },\\n    {\\n      \\"run\\": \\"before\\",\\n      \\"snippetPath\\": \\"createIsbnFunctions.sql\\",\\n      \\"fromModuleVersion\\": \\"19.2.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"setEffectiveHoldingsLocation.sql\\",\\n      \\"fromModuleVersion\\": \\"25.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"dropLegacyItemEffectiveLocationTriggers.sql\\",\\n      \\"fromModuleVersion\\": \\"19.5.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"populateRetainLeadingZeroesSetting.sql\\",\\n      \\"fromModuleVersion\\": \\"19.5.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"populateEffectiveLocationForExistingItems.sql\\",\\n      \\"fromModuleVersion\\": \\"17.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"populateEffectiveLocationForeignKey.sql\\",\\n      \\"fromModuleVersion\\": \\"18.2.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"populateEffectiveCallNumberComponentsForExistingItems.sql\\",\\n      \\"fromModuleVersion\\": \\"18.3.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"removeOldHridOperations.sql\\",\\n      \\"fromModuleVersion\\": \\"17.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"instanceStatusUpdatedDateTrigger.sql\\",\\n      \\"fromModuleVersion\\": \\"17.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"updateItemStatusDate.sql\\",\\n      \\"fromModuleVersion\\": \\"19.2.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"alterHridSequences.sql\\",\\n      \\"fromModuleVersion\\": \\"18.2.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"migrateItemCopyNumberToSingleValue.sql\\",\\n      \\"fromModuleVersion\\": \\"19.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"renameModesOfIssuance.sql\\",\\n      \\"fromModuleVersion\\": \\"19.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"migratePrecedingSucceedingTitles.sql\\",\\n      \\"fromModuleVersion\\": \\"19.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"populateDiscoverySuppressIfNotSet.sql\\",\\n      \\"fromModuleVersion\\": \\"19.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"oaipmh/createOaiPmhViewFunction.sql\\",\\n      \\"fromModuleVersion\\": \\"19.3.1\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"removeOldPrecedingSucceedingTitles.sql\\",\\n      \\"fromModuleVersion\\": \\"19.2.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/createRecordsViewFunction.sql\\",\\n      \\"fromModuleVersion\\": \\"19.4.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"updateIllPolicyWillNotLend.sql\\",\\n      \\"fromModuleVersion\\": \\"19.4.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"addIdentifierTypeCancelledSystemControlNumber.sql\\",\\n      \\"fromModuleVersion\\": \\"19.4.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/addNullChecksToRecordsViewFunctions.sql\\",\\n      \\"fromModuleVersion\\": \\"19.5.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"publication-period/publication-period-functions.sql\\",\\n      \\"fromModuleVersion\\": \\"23.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"instance-hr-item/instance-hr-item-view.sql\\",\\n      \\"fromModuleVersion\\": \\"23.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/addEffectiveHoldingsToItemsAndHoldingsView.sql\\",\\n      \\"fromModuleVersion\\": \\"20.3.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"addInstanceFormatsAudioBelt.sql\\",\\n      \\"fromModuleVersion\\": \\"20.3.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"dropLegacyItemEffectiveLocationFunctions.sql\\",\\n      \\"fromModuleVersion\\": \\"21.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"addIdentifierTypesUpcIsmn.sql\\",\\n      \\"fromModuleVersion\\": \\"21.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/addHoldingsIfItemsSuppressedItemsAndHoldingsView.sql\\",\\n      \\"fromModuleVersion\\": \\"22.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"itemStatisticalCodeReferenceCheckTrigger.sql\\",\\n      \\"fromModuleVersion\\": \\"22.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"statisticalCodeTypesReferenceCheckTrigger.sql\\",\\n      \\"fromModuleVersion\\": \\"25.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"statisticalCodeIdReferenceCheckTrigger.sql\\",\\n      \\"fromModuleVersion\\": \\"23.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"changeUUIDCastInGetStatisticalCodesFunction.sql\\",\\n      \\"fromModuleVersion\\": \\"23.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/correctGetUpdatedInstanceIdsView.sql\\",\\n      \\"fromModuleVersion\\": \\"23.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"dropCallNumberNormalizationFunctions.sql\\",\\n      \\"fromModuleVersion\\": \\"24.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"createInstanceSetView.sql\\",\\n      \\"fromModuleVersion\\": \\"25.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"setDefaultMetadataForHrIdSettings.sql\\",\\n      \\"fromModuleVersion\\": \\"25.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"convertSeriesAndSubjects.sql\\",\\n      \\"fromModuleVersion\\": \\"26.0.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/updateRecordsViewFunctionToSupportSource.sql\\",\\n      \\"fromModuleVersion\\": \\"26.0.1\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/correctGetUpdatedInstanceIdsViewToSupportDeletion.sql\\",\\n      \\"fromModuleVersion\\": \\"26.0.1\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/updateRecordsViewFunctionToSupportSourceImprove.sql\\",\\n      \\"fromModuleVersion\\": \\"26.0.1\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/updateRecordsViewFunctionToSupportSourceFix.sql\\",\\n      \\"fromModuleVersion\\": \\"26.0.1\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"updateCallNumberSource.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"addReindexJobResourceName.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"hridSettingsView.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"populateCirculationNoteIds.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"oaipmh/addCompleteUpdatedDate.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"oaipmh/createTriggersAndFunctionsForCompleteUpdatedDate.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"dropDuplicatesOfinstance_source_marc_id_fkey.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/updateRecordsViewFunctionToSupportBoundWithItems.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"oaipmh/updateCompleteUpdatedDateForItemInsertUpdateToHandleBoundWith.sql\\",\\n      \\"fromModuleVersion\\": \\"26.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"addIdentifierTypeCancelledLCCN.sql\\",\\n      \\"fromModuleVersion\\": \\"27.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"inventory-hierarchy/updateRecordsViewFunctionToSupportAdditionalFields.sql\\",\\n      \\"fromModuleVersion\\": \\"27.1.0\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"oaipmh/createIndexCompleteUpdatedDate.sql\\",\\n      \\"fromModuleVersion\\": \\"27.1.3\\"\\n    },\\n    {\\n      \\"run\\": \\"after\\",\\n      \\"snippetPath\\": \\"migrateHoldingsOutdatedFields.sql\\",\\n      \\"fromModuleVersion\\": \\"27.1.4\\"\\n    }\\n  ]\\n}\\n", "moduleVersion": "mod-inventory-storage-999.0.0"}
\.


--
-- Data for Name: rmb_internal_analyze; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.rmb_internal_analyze (tablename) FROM stdin;
\.


--
-- Data for Name: rmb_internal_index; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.rmb_internal_index (name, def, remove) FROM stdin;
loan_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS loan_type_name_idx_unique ON quesnelia_mod_inventory_storage.loan_type (lower(f_unaccent(jsonb->>'name')))	f
material_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS material_type_name_idx_unique ON quesnelia_mod_inventory_storage.material_type (lower(f_unaccent(jsonb->>'name')))	f
locinstitution_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS locinstitution_name_idx_unique ON quesnelia_mod_inventory_storage.locinstitution (lower(f_unaccent(jsonb->>'name')))	f
loccampus_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS loccampus_name_idx_unique ON quesnelia_mod_inventory_storage.loccampus (lower(f_unaccent(jsonb->>'name')))	f
loclibrary_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS loclibrary_name_idx_unique ON quesnelia_mod_inventory_storage.loclibrary (lower(f_unaccent(jsonb->>'name')))	f
location_primaryServicePoint_idx	CREATE INDEX IF NOT EXISTS location_primaryServicePoint_idx ON quesnelia_mod_inventory_storage.location (left(lower(jsonb->>'primaryServicePoint'),600))	f
location_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS location_name_idx_unique ON quesnelia_mod_inventory_storage.location (lower(f_unaccent(jsonb->>'name')))	f
location_code_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS location_code_idx_unique ON quesnelia_mod_inventory_storage.location (lower(f_unaccent(jsonb->>'code')))	f
service_point_pickupLocation_idx	CREATE INDEX IF NOT EXISTS service_point_pickupLocation_idx ON quesnelia_mod_inventory_storage.service_point (left(lower(jsonb->>'pickupLocation'),600))	f
service_point_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS service_point_name_idx_unique ON quesnelia_mod_inventory_storage.service_point (lower(f_unaccent(jsonb->>'name')))	f
service_point_code_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS service_point_code_idx_unique ON quesnelia_mod_inventory_storage.service_point (lower(f_unaccent(jsonb->>'code')))	f
service_point_user_userId_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS service_point_user_userId_idx_unique ON quesnelia_mod_inventory_storage.service_point_user (lower(f_unaccent(jsonb->>'userId')))	f
identifier_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS identifier_type_name_idx_unique ON quesnelia_mod_inventory_storage.identifier_type (lower(f_unaccent(jsonb->>'name')))	f
instance_relationship_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_relationship_type_name_idx_unique ON quesnelia_mod_inventory_storage.instance_relationship_type (lower(f_unaccent(jsonb->>'name')))	f
contributor_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS contributor_type_name_idx_unique ON quesnelia_mod_inventory_storage.contributor_type (lower(f_unaccent(jsonb->>'name')))	f
contributor_type_code_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS contributor_type_code_idx_unique ON quesnelia_mod_inventory_storage.contributor_type (lower(f_unaccent(jsonb->>'code')))	f
contributor_name_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS contributor_name_type_name_idx_unique ON quesnelia_mod_inventory_storage.contributor_name_type (lower(f_unaccent(jsonb->>'name')))	f
instance_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_type_name_idx_unique ON quesnelia_mod_inventory_storage.instance_type (lower(f_unaccent(jsonb->>'name')))	f
instance_type_code_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_type_code_idx_unique ON quesnelia_mod_inventory_storage.instance_type (lower(f_unaccent(jsonb->>'code')))	f
instance_format_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_format_name_idx_unique ON quesnelia_mod_inventory_storage.instance_format (lower(f_unaccent(jsonb->>'name')))	f
instance_format_code_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_format_code_idx_unique ON quesnelia_mod_inventory_storage.instance_format (lower(f_unaccent(jsonb->>'code')))	f
nature_of_content_term_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS nature_of_content_term_name_idx_unique ON quesnelia_mod_inventory_storage.nature_of_content_term (lower(f_unaccent(jsonb->>'name')))	f
classification_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS classification_type_name_idx_unique ON quesnelia_mod_inventory_storage.classification_type (lower(f_unaccent(jsonb->>'name')))	f
electronic_access_relationship_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS electronic_access_relationship_name_idx_unique ON quesnelia_mod_inventory_storage.electronic_access_relationship (lower(f_unaccent(jsonb->>'name')))	f
statistical_code_type_code_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS statistical_code_type_code_idx_unique ON quesnelia_mod_inventory_storage.statistical_code_type (lower(f_unaccent(jsonb->>'code')))	f
statistical_code_code_statisticalCodeTypeId_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS statistical_code_code_statisticalCodeTypeId_idx_unique ON quesnelia_mod_inventory_storage.statistical_code (lower(f_unaccent(jsonb->>'code')) , lower(f_unaccent(jsonb->>'statisticalCodeTypeId')))	f
statistical_code_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS statistical_code_name_idx_unique ON quesnelia_mod_inventory_storage.statistical_code (lower(f_unaccent(jsonb->>'name')))	f
instance_status_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_status_name_idx_unique ON quesnelia_mod_inventory_storage.instance_status (lower(f_unaccent(jsonb->>'name')))	f
instance_status_code_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_status_code_idx_unique ON quesnelia_mod_inventory_storage.instance_status (lower(f_unaccent(jsonb->>'code')))	f
mode_of_issuance_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS mode_of_issuance_name_idx_unique ON quesnelia_mod_inventory_storage.mode_of_issuance (lower(f_unaccent(jsonb->>'name')))	f
alternative_title_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS alternative_title_type_name_idx_unique ON quesnelia_mod_inventory_storage.alternative_title_type (lower(f_unaccent(jsonb->>'name')))	f
instance_source_idx	CREATE INDEX IF NOT EXISTS instance_source_idx ON quesnelia_mod_inventory_storage.instance (left(lower(jsonb->>'source'),600))	f
instance_indexTitle_idx	CREATE INDEX IF NOT EXISTS instance_indexTitle_idx ON quesnelia_mod_inventory_storage.instance (left(lower(f_unaccent(jsonb->>'indexTitle')),600))	f
instance_title_idx	CREATE INDEX IF NOT EXISTS instance_title_idx ON quesnelia_mod_inventory_storage.instance (left(lower(f_unaccent(jsonb->>'title')),600))	f
instance_statisticalCodeIds_idx	CREATE INDEX IF NOT EXISTS instance_statisticalCodeIds_idx ON quesnelia_mod_inventory_storage.instance (left(lower(jsonb->>'statisticalCodeIds'),600))	f
instance_contributors_idx	CREATE INDEX IF NOT EXISTS instance_contributors_idx ON quesnelia_mod_inventory_storage.instance (left(lower(f_unaccent(jsonb->>'contributors')),600))	f
instance_publication_idx	CREATE INDEX IF NOT EXISTS instance_publication_idx ON quesnelia_mod_inventory_storage.instance (left(lower(f_unaccent(jsonb->>'publication')),600))	f
instance_staffSuppress_idx	CREATE INDEX IF NOT EXISTS instance_staffSuppress_idx ON quesnelia_mod_inventory_storage.instance (left(lower(jsonb->>'staffSuppress'),600))	f
instance_discoverySuppress_idx	CREATE INDEX IF NOT EXISTS instance_discoverySuppress_idx ON quesnelia_mod_inventory_storage.instance (left(lower(jsonb->>'discoverySuppress'),600))	f
instance_metadata_updatedDate_idx	CREATE INDEX IF NOT EXISTS instance_metadata_updatedDate_idx ON quesnelia_mod_inventory_storage.instance (left(lower(jsonb->'metadata'->>'updatedDate'),600))	f
instance_hrid_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_hrid_idx_unique ON quesnelia_mod_inventory_storage.instance (lower(f_unaccent(jsonb->>'hrid')))	f
instance_matchKey_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_matchKey_idx_unique ON quesnelia_mod_inventory_storage.instance (lower(f_unaccent(jsonb->>'matchKey')))	f
instance_identifiers_idx_gin	CREATE INDEX IF NOT EXISTS instance_identifiers_idx_gin ON quesnelia_mod_inventory_storage.instance USING GIN ((lower(f_unaccent(jsonb->>'identifiers'))) public.gin_trgm_ops)	f
instance_identifiers_idx_ft	CREATE INDEX IF NOT EXISTS instance_identifiers_idx_ft ON quesnelia_mod_inventory_storage.instance USING GIN ( get_tsvector(f_unaccent(jsonb->>'identifiers')) )	f
instance_invalidIsbn_idx_ft	CREATE INDEX IF NOT EXISTS instance_invalidIsbn_idx_ft ON quesnelia_mod_inventory_storage.instance USING GIN ( get_tsvector(normalize_invalid_isbns(jsonb->'identifiers')) )	f
instance_isbn_idx_ft	CREATE INDEX IF NOT EXISTS instance_isbn_idx_ft ON quesnelia_mod_inventory_storage.instance USING GIN ( get_tsvector(normalize_isbns(jsonb->'identifiers')) )	f
ill_policy_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS ill_policy_name_idx_unique ON quesnelia_mod_inventory_storage.ill_policy (lower(f_unaccent(jsonb->>'name')))	f
call_number_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS call_number_type_name_idx_unique ON quesnelia_mod_inventory_storage.call_number_type (lower(f_unaccent(jsonb->>'name')))	f
holdings_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS holdings_type_name_idx_unique ON quesnelia_mod_inventory_storage.holdings_type (lower(f_unaccent(jsonb->>'name')))	f
instance_note_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS instance_note_type_name_idx_unique ON quesnelia_mod_inventory_storage.instance_note_type (lower(f_unaccent(jsonb->>'name')))	f
holdings_note_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS holdings_note_type_name_idx_unique ON quesnelia_mod_inventory_storage.holdings_note_type (lower(f_unaccent(jsonb->>'name')))	f
item_note_type_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS item_note_type_name_idx_unique ON quesnelia_mod_inventory_storage.item_note_type (lower(f_unaccent(jsonb->>'name')))	f
item_damaged_status_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS item_damaged_status_name_idx_unique ON quesnelia_mod_inventory_storage.item_damaged_status (lower(f_unaccent(jsonb->>'name')))	f
holdings_records_source_name_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS holdings_records_source_name_idx_unique ON quesnelia_mod_inventory_storage.holdings_records_source (lower(f_unaccent(jsonb->>'name')))	f
holdings_record_callNumber_idx	CREATE INDEX IF NOT EXISTS holdings_record_callNumber_idx ON quesnelia_mod_inventory_storage.holdings_record (left(lower(jsonb->>'callNumber'),600))	f
holdings_record_callNumberAndSuffix_idx	CREATE INDEX IF NOT EXISTS holdings_record_callNumberAndSuffix_idx ON quesnelia_mod_inventory_storage.holdings_record (left(lower(concat_space_sql(holdings_record.jsonb->>'callNumber' , holdings_record.jsonb->>'callNumberSuffix')),600))	f
holdings_record_fullCallNumber_idx	CREATE INDEX IF NOT EXISTS holdings_record_fullCallNumber_idx ON quesnelia_mod_inventory_storage.holdings_record (left(lower(concat_space_sql(holdings_record.jsonb->>'callNumberPrefix' , holdings_record.jsonb->>'callNumber' , holdings_record.jsonb->>'callNumberSuffix')),600))	f
holdings_record_discoverySuppress_idx	CREATE INDEX IF NOT EXISTS holdings_record_discoverySuppress_idx ON quesnelia_mod_inventory_storage.holdings_record (left(lower(jsonb->>'discoverySuppress'),600))	f
holdings_record_hrid_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS holdings_record_hrid_idx_unique ON quesnelia_mod_inventory_storage.holdings_record (lower(f_unaccent(jsonb->>'hrid')))	f
item_accessionNumber_idx	CREATE INDEX IF NOT EXISTS item_accessionNumber_idx ON quesnelia_mod_inventory_storage.item (left(lower(jsonb->>'accessionNumber'),600))	f
item_status_name_idx	CREATE INDEX IF NOT EXISTS item_status_name_idx ON quesnelia_mod_inventory_storage.item (left(lower(f_unaccent(jsonb->'status'->>'name')),600))	f
item_callNumberAndSuffix_idx	CREATE INDEX IF NOT EXISTS item_callNumberAndSuffix_idx ON quesnelia_mod_inventory_storage.item (left(lower(concat_space_sql(item.jsonb->'effectiveCallNumberComponents'->>'callNumber' , item.jsonb->'effectiveCallNumberComponents'->>'suffix')),600))	f
item_fullCallNumber_idx	CREATE INDEX IF NOT EXISTS item_fullCallNumber_idx ON quesnelia_mod_inventory_storage.item (left(lower(concat_space_sql(item.jsonb->'effectiveCallNumberComponents'->>'prefix' , item.jsonb->'effectiveCallNumberComponents'->>'callNumber' , item.jsonb->'effectiveCallNumberComponents'->>'suffix')),600))	f
item_discoverySuppress_idx	CREATE INDEX IF NOT EXISTS item_discoverySuppress_idx ON quesnelia_mod_inventory_storage.item (left(lower(jsonb->>'discoverySuppress'),600))	f
item_purchaseOrderLineIdentifier_idx	CREATE INDEX IF NOT EXISTS item_purchaseOrderLineIdentifier_idx ON quesnelia_mod_inventory_storage.item (left(lower(jsonb->>'purchaseOrderLineIdentifier'),600))	f
item_effectiveCallNumberComponents_callNumber_idx	CREATE INDEX IF NOT EXISTS item_effectiveCallNumberComponents_callNumber_idx ON quesnelia_mod_inventory_storage.item (left(lower(jsonb->'effectiveCallNumberComponents'->>'callNumber'),600))	f
item_barcode_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS item_barcode_idx_unique ON quesnelia_mod_inventory_storage.item (lower(jsonb->>'barcode'))	f
item_hrid_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS item_hrid_idx_unique ON quesnelia_mod_inventory_storage.item (lower(f_unaccent(jsonb->>'hrid')))	f
bound_with_part_itemId_holdingsRecordId_idx_unique	CREATE UNIQUE INDEX IF NOT EXISTS bound_with_part_itemId_holdingsRecordId_idx_unique ON quesnelia_mod_inventory_storage.bound_with_part (lower(f_unaccent(jsonb->>'itemId')) , lower(f_unaccent(jsonb->>'holdingsRecordId')))	f
\.


--
-- Data for Name: rmb_job; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.rmb_job (id, jsonb) FROM stdin;
993b3115-eb00-4680-aa28-5e8942824642	{"id": "993b3115-eb00-4680-aa28-5e8942824642", "tenant": "quesnelia", "complete": true, "messages": [], "tenantAttributes": {"module_to": "mod-inventory-storage-999.0.0", "parameters": [{"key": "loadReference", "value": "true"}, {"key": "loadSample", "value": "true"}]}}
\.


--
-- Data for Name: service_point; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.service_point (id, jsonb, creation_date, created_by) FROM stdin;
7c5abc9f-f3d7-4856-b8d7-6712462ca007	{"id": "7c5abc9f-f3d7-4856-b8d7-6712462ca007", "code": "Online", "name": "Online", "metadata": {"createdDate": "2025-05-16T18:12:34.089Z", "updatedDate": "2025-05-16T18:12:34.089Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "staffSlips": [], "pickupLocation": false, "shelvingLagTime": 0, "discoveryDisplayName": "Online", "holdShelfClosedLibraryDateManagement": "Keep_the_current_due_date"}	2025-05-16 18:12:34.089	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
c4c90014-c8c9-4ade-8f24-b5e313319f4b	{"id": "c4c90014-c8c9-4ade-8f24-b5e313319f4b", "code": "cd2", "name": "Circ Desk 2", "metadata": {"createdDate": "2025-05-16T18:12:34.083Z", "updatedDate": "2025-05-16T18:12:34.083Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "staffSlips": [], "pickupLocation": true, "discoveryDisplayName": "Circulation Desk -- Back Entrance", "holdShelfExpiryPeriod": {"duration": 5, "intervalId": "Days"}, "holdShelfClosedLibraryDateManagement": "Keep_the_current_due_date"}	2025-05-16 18:12:34.083	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
3a40852d-49fd-4df2-a1f9-6e2641a6e91f	{"id": "3a40852d-49fd-4df2-a1f9-6e2641a6e91f", "code": "cd1", "name": "Circ Desk 1", "metadata": {"createdDate": "2025-05-16T18:12:34.088Z", "updatedDate": "2025-05-16T18:12:34.088Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "staffSlips": [], "pickupLocation": true, "discoveryDisplayName": "Circulation Desk -- Hallway", "holdShelfExpiryPeriod": {"duration": 3, "intervalId": "Weeks"}, "holdShelfClosedLibraryDateManagement": "Keep_the_current_due_date"}	2025-05-16 18:12:34.088	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Data for Name: service_point_user; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.service_point_user (id, jsonb, creation_date, created_by, defaultservicepointid) FROM stdin;
\.


--
-- Data for Name: statistical_code; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.statistical_code (id, jsonb, creation_date, created_by, statisticalcodetypeid) FROM stdin;
bb76b1c1-c9df-445c-8deb-68bb3580edc2	{"id": "bb76b1c1-c9df-445c-8deb-68bb3580edc2", "code": "compfiles", "name": "Computer files, CDs, etc (compfiles)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.000Z", "updatedDate": "2025-05-16T18:12:35.000Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
e10796e0-a594-47b7-b748-3a81b69b3d9b	{"id": "e10796e0-a594-47b7-b748-3a81b69b3d9b", "code": "audstream", "name": "Streaming audio (audstream)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.002Z", "updatedDate": "2025-05-16T18:12:35.002Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "d816175b-578f-4056-af61-689f449c3c45"}	2025-05-16 18:12:35.002	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	d816175b-578f-4056-af61-689f449c3c45
16f2d65e-eb68-4ab1-93e3-03af50cb7370	{"id": "16f2d65e-eb68-4ab1-93e3-03af50cb7370", "code": "mfiche", "name": "Microfiche (mfiche)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.002Z", "updatedDate": "2025-05-16T18:12:35.002Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.002	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
91b8f0b4-0e13-4270-9fd6-e39203d0f449	{"id": "91b8f0b4-0e13-4270-9fd6-e39203d0f449", "code": "rnonmusic", "name": "Non-music sound recordings (rnonmusic)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.001Z", "updatedDate": "2025-05-16T18:12:35.001Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.001	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
9d8abbe2-1a94-4866-8731-4d12ac09f7a8	{"id": "9d8abbe2-1a94-4866-8731-4d12ac09f7a8", "code": "ebooks", "name": "Books, electronic (ebooks)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.017Z", "updatedDate": "2025-05-16T18:12:35.017Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.017	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
1c622d0f-2e91-4c30-ba43-2750f9735f51	{"id": "1c622d0f-2e91-4c30-ba43-2750f9735f51", "code": "mfilm", "name": "Microfilm (mfilm)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.019Z", "updatedDate": "2025-05-16T18:12:35.019Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.019	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
d82c025e-436d-4006-a677-bd2b4cdb7692	{"id": "d82c025e-436d-4006-a677-bd2b4cdb7692", "code": "mss", "name": "Manuscripts (mss)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.021Z", "updatedDate": "2025-05-16T18:12:35.021Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544"}	2025-05-16 18:12:35.021	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0d3ec58e-dc3c-4aa1-9eba-180fca95c544
2850630b-cd12-4379-af57-5c51491a6873	{"id": "2850630b-cd12-4379-af57-5c51491a6873", "code": "mmedia", "name": "Mixed media (mmedia)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.020Z", "updatedDate": "2025-05-16T18:12:35.020Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.02	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
0868921a-4407-47c9-9b3e-db94644dbae7	{"id": "0868921a-4407-47c9-9b3e-db94644dbae7", "code": "ENF", "name": "Entry not found", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.021Z", "updatedDate": "2025-05-16T18:12:35.021Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "e2ab27f9-a726-4e5e-9963-fff9e6128680"}	2025-05-16 18:12:35.021	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e2ab27f9-a726-4e5e-9963-fff9e6128680
775b6ad4-9c35-4d29-bf78-8775a9b42226	{"id": "775b6ad4-9c35-4d29-bf78-8775a9b42226", "code": "serials", "name": "Serials, print (serials)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.031Z", "updatedDate": "2025-05-16T18:12:35.031Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.031	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
ecab577d-a050-4ea2-8a86-ea5a234283ea	{"id": "ecab577d-a050-4ea2-8a86-ea5a234283ea", "code": "emusic", "name": "Music scores, electronic", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.033Z", "updatedDate": "2025-05-16T18:12:35.033Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.033	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
97e91f57-fad7-41ea-a660-4031bf8d4ea8	{"id": "97e91f57-fad7-41ea-a660-4031bf8d4ea8", "code": "maps", "name": "Maps, print (maps)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.035Z", "updatedDate": "2025-05-16T18:12:35.035Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.035	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
972f81d5-9f8f-4b56-a10e-5c05419718e6	{"id": "972f81d5-9f8f-4b56-a10e-5c05419718e6", "code": "visual", "name": "Visual materials, DVDs, etc. (visual)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.037Z", "updatedDate": "2025-05-16T18:12:35.037Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.037	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
b5968c9e-cddc-4576-99e3-8e60aed8b0dd	{"id": "b5968c9e-cddc-4576-99e3-8e60aed8b0dd", "code": "books", "name": "Book, print (books)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.036Z", "updatedDate": "2025-05-16T18:12:35.036Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.036	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
264c4f94-1538-43a3-8b40-bed68384b31b	{"id": "264c4f94-1538-43a3-8b40-bed68384b31b", "code": "XOCLC", "name": "Do not share with OCLC", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.042Z", "updatedDate": "2025-05-16T18:12:35.042Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544"}	2025-05-16 18:12:35.042	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0d3ec58e-dc3c-4aa1-9eba-180fca95c544
0e516e54-bf36-4fc2-a0f7-3fe89a61c9c0	{"id": "0e516e54-bf36-4fc2-a0f7-3fe89a61c9c0", "code": "ISER", "name": "Inactive serial", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.047Z", "updatedDate": "2025-05-16T18:12:35.047Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "e2ab27f9-a726-4e5e-9963-fff9e6128680"}	2025-05-16 18:12:35.047	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e2ab27f9-a726-4e5e-9963-fff9e6128680
f47b773a-bd5f-4246-ac1e-fa4adcd0dcdf	{"id": "f47b773a-bd5f-4246-ac1e-fa4adcd0dcdf", "code": "UCPress", "name": "University of Chicago Press Imprint", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.057Z", "updatedDate": "2025-05-16T18:12:35.057Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544"}	2025-05-16 18:12:35.057	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0d3ec58e-dc3c-4aa1-9eba-180fca95c544
30b5400d-0b9e-4757-a3d0-db0d30a49e72	{"id": "30b5400d-0b9e-4757-a3d0-db0d30a49e72", "code": "music", "name": "Music scores, print (music)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.063Z", "updatedDate": "2025-05-16T18:12:35.063Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.063	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
c7a32c50-ea7c-43b7-87ab-d134c8371330	{"id": "c7a32c50-ea7c-43b7-87ab-d134c8371330", "code": "ASER", "name": "Active serial", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.066Z", "updatedDate": "2025-05-16T18:12:35.066Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "e2ab27f9-a726-4e5e-9963-fff9e6128680"}	2025-05-16 18:12:35.066	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	e2ab27f9-a726-4e5e-9963-fff9e6128680
c4073462-6144-4b69-a543-dd131e241799	{"id": "c4073462-6144-4b69-a543-dd131e241799", "code": "withdrawn", "name": "Withdrawn (withdrawn)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.075Z", "updatedDate": "2025-05-16T18:12:35.075Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544"}	2025-05-16 18:12:35.075	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0d3ec58e-dc3c-4aa1-9eba-180fca95c544
b2c0e100-0485-43f2-b161-3c60aac9f68a	{"id": "b2c0e100-0485-43f2-b161-3c60aac9f68a", "code": "evisual", "name": "Visual, static, electronic", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.049Z", "updatedDate": "2025-05-16T18:12:35.049Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "d816175b-578f-4056-af61-689f449c3c45"}	2025-05-16 18:12:35.049	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	d816175b-578f-4056-af61-689f449c3c45
950d3370-9a3c-421e-b116-76e7511af9e9	{"id": "950d3370-9a3c-421e-b116-76e7511af9e9", "code": "polsky", "name": "Polsky TECHB@R (polsky)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.065Z", "updatedDate": "2025-05-16T18:12:35.065Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544"}	2025-05-16 18:12:35.065	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0d3ec58e-dc3c-4aa1-9eba-180fca95c544
6899291a-1fb9-4130-98ce-b40368556818	{"id": "6899291a-1fb9-4130-98ce-b40368556818", "code": "rmusic", "name": "Music sound recordings", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.053Z", "updatedDate": "2025-05-16T18:12:35.053Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3"}	2025-05-16 18:12:35.053	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	3abd6fc2-b3e4-4879-b1e1-78be41769fe3
38249f9e-13f8-48bc-a010-8023cd194af5	{"id": "38249f9e-13f8-48bc-a010-8023cd194af5", "code": "its", "name": "Information Technology Services (its)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.063Z", "updatedDate": "2025-05-16T18:12:35.063Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544"}	2025-05-16 18:12:35.063	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0d3ec58e-dc3c-4aa1-9eba-180fca95c544
b76a3088-8de6-46c8-a130-c8e74b8d2c5b	{"id": "b76a3088-8de6-46c8-a130-c8e74b8d2c5b", "code": "emaps", "name": "Maps, electronic (emaps)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.070Z", "updatedDate": "2025-05-16T18:12:35.070Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "d816175b-578f-4056-af61-689f449c3c45"}	2025-05-16 18:12:35.07	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	d816175b-578f-4056-af61-689f449c3c45
a5ccf92e-7b1f-4990-ac03-780a6a767f37	{"id": "a5ccf92e-7b1f-4990-ac03-780a6a767f37", "code": "eserials", "name": "Serials, electronic (eserials)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.077Z", "updatedDate": "2025-05-16T18:12:35.077Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "d816175b-578f-4056-af61-689f449c3c45"}	2025-05-16 18:12:35.077	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	d816175b-578f-4056-af61-689f449c3c45
b6b46869-f3c1-4370-b603-29774a1e42b1	{"id": "b6b46869-f3c1-4370-b603-29774a1e42b1", "code": "arch", "name": "Archives (arch)", "source": "UC", "metadata": {"createdDate": "2025-05-16T18:12:35.055Z", "updatedDate": "2025-05-16T18:12:35.055Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544"}	2025-05-16 18:12:35.055	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	0d3ec58e-dc3c-4aa1-9eba-180fca95c544
6d584d0e-3dbc-46c4-a1bd-e9238dd9a6be	{"id": "6d584d0e-3dbc-46c4-a1bd-e9238dd9a6be", "code": "vidstream", "name": "Streaming video (vidstream)", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:35.066Z", "updatedDate": "2025-05-16T18:12:35.066Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}, "statisticalCodeTypeId": "d816175b-578f-4056-af61-689f449c3c45"}	2025-05-16 18:12:35.066	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce	d816175b-578f-4056-af61-689f449c3c45
\.


--
-- Data for Name: statistical_code_type; Type: TABLE DATA; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

COPY quesnelia_mod_inventory_storage.statistical_code_type (id, jsonb, creation_date, created_by) FROM stdin;
0d3ec58e-dc3c-4aa1-9eba-180fca95c544	{"id": "0d3ec58e-dc3c-4aa1-9eba-180fca95c544", "name": "RECM (Record management)", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.909Z", "updatedDate": "2025-05-16T18:12:34.909Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.909	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
3abd6fc2-b3e4-4879-b1e1-78be41769fe3	{"id": "3abd6fc2-b3e4-4879-b1e1-78be41769fe3", "name": "ARL (Collection stats)", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.914Z", "updatedDate": "2025-05-16T18:12:34.914Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.914	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
e2ab27f9-a726-4e5e-9963-fff9e6128680	{"id": "e2ab27f9-a726-4e5e-9963-fff9e6128680", "name": "SERM (Serial management)", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.910Z", "updatedDate": "2025-05-16T18:12:34.910Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.91	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
d816175b-578f-4056-af61-689f449c3c45	{"id": "d816175b-578f-4056-af61-689f449c3c45", "name": "DISC (Discovery)", "source": "folio", "metadata": {"createdDate": "2025-05-16T18:12:34.911Z", "updatedDate": "2025-05-16T18:12:34.911Z", "createdByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce", "updatedByUserId": "e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce"}}	2025-05-16 18:12:34.911	e9414e8d-f0ca-4af5-8bc6-ffd9d4604cce
\.


--
-- Name: hrid_holdings_seq; Type: SEQUENCE SET; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

SELECT pg_catalog.setval('quesnelia_mod_inventory_storage.hrid_holdings_seq', 1, false);


--
-- Name: hrid_instances_seq; Type: SEQUENCE SET; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

SELECT pg_catalog.setval('quesnelia_mod_inventory_storage.hrid_instances_seq', 1, false);


--
-- Name: hrid_items_seq; Type: SEQUENCE SET; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

SELECT pg_catalog.setval('quesnelia_mod_inventory_storage.hrid_items_seq', 1, false);


--
-- Name: rmb_internal_id_seq; Type: SEQUENCE SET; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

SELECT pg_catalog.setval('quesnelia_mod_inventory_storage.rmb_internal_id_seq', 1, true);


--
-- Name: alternative_title_type alternative_title_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.alternative_title_type
    ADD CONSTRAINT alternative_title_type_pkey PRIMARY KEY (id);


--
-- Name: async_migration_job async_migration_job_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.async_migration_job
    ADD CONSTRAINT async_migration_job_pkey PRIMARY KEY (id);


--
-- Name: audit_holdings_record audit_holdings_record_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.audit_holdings_record
    ADD CONSTRAINT audit_holdings_record_pkey PRIMARY KEY (id);


--
-- Name: audit_instance audit_instance_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.audit_instance
    ADD CONSTRAINT audit_instance_pkey PRIMARY KEY (id);


--
-- Name: audit_item audit_item_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.audit_item
    ADD CONSTRAINT audit_item_pkey PRIMARY KEY (id);


--
-- Name: bound_with_part bound_with_part_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.bound_with_part
    ADD CONSTRAINT bound_with_part_pkey PRIMARY KEY (id);


--
-- Name: call_number_type call_number_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.call_number_type
    ADD CONSTRAINT call_number_type_pkey PRIMARY KEY (id);


--
-- Name: classification_type classification_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.classification_type
    ADD CONSTRAINT classification_type_pkey PRIMARY KEY (id);


--
-- Name: contributor_name_type contributor_name_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.contributor_name_type
    ADD CONSTRAINT contributor_name_type_pkey PRIMARY KEY (id);


--
-- Name: contributor_type contributor_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.contributor_type
    ADD CONSTRAINT contributor_type_pkey PRIMARY KEY (id);


--
-- Name: electronic_access_relationship electronic_access_relationship_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.electronic_access_relationship
    ADD CONSTRAINT electronic_access_relationship_pkey PRIMARY KEY (id);


--
-- Name: holdings_note_type holdings_note_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_note_type
    ADD CONSTRAINT holdings_note_type_pkey PRIMARY KEY (id);


--
-- Name: holdings_record holdings_record_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT holdings_record_pkey PRIMARY KEY (id);


--
-- Name: holdings_records_source holdings_records_source_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_records_source
    ADD CONSTRAINT holdings_records_source_pkey PRIMARY KEY (id);


--
-- Name: holdings_type holdings_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_type
    ADD CONSTRAINT holdings_type_pkey PRIMARY KEY (id);


--
-- Name: hrid_settings hrid_settings_lock_key; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.hrid_settings
    ADD CONSTRAINT hrid_settings_lock_key UNIQUE (lock);


--
-- Name: hrid_settings hrid_settings_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.hrid_settings
    ADD CONSTRAINT hrid_settings_pkey PRIMARY KEY (id);


--
-- Name: identifier_type identifier_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.identifier_type
    ADD CONSTRAINT identifier_type_pkey PRIMARY KEY (id);


--
-- Name: ill_policy ill_policy_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.ill_policy
    ADD CONSTRAINT ill_policy_pkey PRIMARY KEY (id);


--
-- Name: instance_format instance_format_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_format
    ADD CONSTRAINT instance_format_pkey PRIMARY KEY (id);


--
-- Name: instance_note_type instance_note_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_note_type
    ADD CONSTRAINT instance_note_type_pkey PRIMARY KEY (id);


--
-- Name: instance instance_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance
    ADD CONSTRAINT instance_pkey PRIMARY KEY (id);


--
-- Name: instance_relationship instance_relationship_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_relationship
    ADD CONSTRAINT instance_relationship_pkey PRIMARY KEY (id);


--
-- Name: instance_relationship_type instance_relationship_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_relationship_type
    ADD CONSTRAINT instance_relationship_type_pkey PRIMARY KEY (id);


--
-- Name: instance_source_marc instance_source_marc_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_source_marc
    ADD CONSTRAINT instance_source_marc_pkey PRIMARY KEY (id);


--
-- Name: instance_status instance_status_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_status
    ADD CONSTRAINT instance_status_pkey PRIMARY KEY (id);


--
-- Name: instance_type instance_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_type
    ADD CONSTRAINT instance_type_pkey PRIMARY KEY (id);


--
-- Name: item_damaged_status item_damaged_status_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item_damaged_status
    ADD CONSTRAINT item_damaged_status_pkey PRIMARY KEY (id);


--
-- Name: item_note_type item_note_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item_note_type
    ADD CONSTRAINT item_note_type_pkey PRIMARY KEY (id);


--
-- Name: item item_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- Name: iteration_job iteration_job_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.iteration_job
    ADD CONSTRAINT iteration_job_pkey PRIMARY KEY (id);


--
-- Name: loan_type loan_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.loan_type
    ADD CONSTRAINT loan_type_pkey PRIMARY KEY (id);


--
-- Name: location location_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (id);


--
-- Name: loccampus loccampus_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.loccampus
    ADD CONSTRAINT loccampus_pkey PRIMARY KEY (id);


--
-- Name: locinstitution locinstitution_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.locinstitution
    ADD CONSTRAINT locinstitution_pkey PRIMARY KEY (id);


--
-- Name: loclibrary loclibrary_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.loclibrary
    ADD CONSTRAINT loclibrary_pkey PRIMARY KEY (id);


--
-- Name: material_type material_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.material_type
    ADD CONSTRAINT material_type_pkey PRIMARY KEY (id);


--
-- Name: mode_of_issuance mode_of_issuance_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.mode_of_issuance
    ADD CONSTRAINT mode_of_issuance_pkey PRIMARY KEY (id);


--
-- Name: nature_of_content_term nature_of_content_term_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.nature_of_content_term
    ADD CONSTRAINT nature_of_content_term_pkey PRIMARY KEY (id);


--
-- Name: notification_sending_error notification_sending_error_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.notification_sending_error
    ADD CONSTRAINT notification_sending_error_pkey PRIMARY KEY (id);


--
-- Name: preceding_succeeding_title preceding_succeeding_title_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.preceding_succeeding_title
    ADD CONSTRAINT preceding_succeeding_title_pkey PRIMARY KEY (id);


--
-- Name: reindex_job reindex_job_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.reindex_job
    ADD CONSTRAINT reindex_job_pkey PRIMARY KEY (id);


--
-- Name: related_instance_type related_instance_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.related_instance_type
    ADD CONSTRAINT related_instance_type_pkey PRIMARY KEY (id);


--
-- Name: rmb_internal_index rmb_internal_index_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.rmb_internal_index
    ADD CONSTRAINT rmb_internal_index_pkey PRIMARY KEY (name);


--
-- Name: rmb_internal rmb_internal_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.rmb_internal
    ADD CONSTRAINT rmb_internal_pkey PRIMARY KEY (id);


--
-- Name: rmb_job rmb_job_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.rmb_job
    ADD CONSTRAINT rmb_job_pkey PRIMARY KEY (id);


--
-- Name: service_point service_point_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.service_point
    ADD CONSTRAINT service_point_pkey PRIMARY KEY (id);


--
-- Name: service_point_user service_point_user_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.service_point_user
    ADD CONSTRAINT service_point_user_pkey PRIMARY KEY (id);


--
-- Name: statistical_code statistical_code_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.statistical_code
    ADD CONSTRAINT statistical_code_pkey PRIMARY KEY (id);


--
-- Name: statistical_code_type statistical_code_type_pkey; Type: CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.statistical_code_type
    ADD CONSTRAINT statistical_code_type_pkey PRIMARY KEY (id);


--
-- Name: alternative_title_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX alternative_title_type_name_idx_unique ON quesnelia_mod_inventory_storage.alternative_title_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: audit_holdings_record_pmh_createddate_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX audit_holdings_record_pmh_createddate_idx ON quesnelia_mod_inventory_storage.audit_holdings_record USING btree (quesnelia_mod_inventory_storage.strtotimestamp(((jsonb -> 'record'::text) ->> 'updatedDate'::text)));


--
-- Name: audit_instance_pmh_createddate_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX audit_instance_pmh_createddate_idx ON quesnelia_mod_inventory_storage.audit_instance USING btree (quesnelia_mod_inventory_storage.strtotimestamp((jsonb ->> 'createdDate'::text)));


--
-- Name: audit_item_pmh_createddate_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX audit_item_pmh_createddate_idx ON quesnelia_mod_inventory_storage.audit_item USING btree (quesnelia_mod_inventory_storage.strtotimestamp(((jsonb -> 'record'::text) ->> 'updatedDate'::text)));


--
-- Name: bound_with_part_holdingsrecordid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX bound_with_part_holdingsrecordid_idx ON quesnelia_mod_inventory_storage.bound_with_part USING btree (holdingsrecordid);


--
-- Name: bound_with_part_itemid_holdingsrecordid_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX bound_with_part_itemid_holdingsrecordid_idx_unique ON quesnelia_mod_inventory_storage.bound_with_part USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'itemId'::text))), lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'holdingsRecordId'::text))));


--
-- Name: bound_with_part_itemid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX bound_with_part_itemid_idx ON quesnelia_mod_inventory_storage.bound_with_part USING btree (itemid);


--
-- Name: call_number_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX call_number_type_name_idx_unique ON quesnelia_mod_inventory_storage.call_number_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: classification_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX classification_type_name_idx_unique ON quesnelia_mod_inventory_storage.classification_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: contributor_name_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX contributor_name_type_name_idx_unique ON quesnelia_mod_inventory_storage.contributor_name_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: contributor_type_code_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX contributor_type_code_idx_unique ON quesnelia_mod_inventory_storage.contributor_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))));


--
-- Name: contributor_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX contributor_type_name_idx_unique ON quesnelia_mod_inventory_storage.contributor_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: electronic_access_relationship_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX electronic_access_relationship_name_idx_unique ON quesnelia_mod_inventory_storage.electronic_access_relationship USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: holdings_note_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX holdings_note_type_name_idx_unique ON quesnelia_mod_inventory_storage.holdings_note_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: holdings_record_callnumber_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_callnumber_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree ("left"(lower((jsonb ->> 'callNumber'::text)), 600));


--
-- Name: holdings_record_callnumberandsuffix_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_callnumberandsuffix_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree ("left"(lower(quesnelia_mod_inventory_storage.concat_space_sql(VARIADIC ARRAY[(jsonb ->> 'callNumber'::text), (jsonb ->> 'callNumberSuffix'::text)])), 600));


--
-- Name: holdings_record_callnumbertypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_callnumbertypeid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (callnumbertypeid);


--
-- Name: holdings_record_discoverysuppress_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_discoverysuppress_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree ("left"(lower((jsonb ->> 'discoverySuppress'::text)), 600));


--
-- Name: holdings_record_effectivelocationid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_effectivelocationid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (effectivelocationid);


--
-- Name: holdings_record_fullcallnumber_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_fullcallnumber_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree ("left"(lower(quesnelia_mod_inventory_storage.concat_space_sql(VARIADIC ARRAY[(jsonb ->> 'callNumberPrefix'::text), (jsonb ->> 'callNumber'::text), (jsonb ->> 'callNumberSuffix'::text)])), 600));


--
-- Name: holdings_record_holdingstypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_holdingstypeid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (holdingstypeid);


--
-- Name: holdings_record_hrid_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX holdings_record_hrid_idx_unique ON quesnelia_mod_inventory_storage.holdings_record USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'hrid'::text))));


--
-- Name: holdings_record_illpolicyid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_illpolicyid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (illpolicyid);


--
-- Name: holdings_record_instanceid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_instanceid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (instanceid);


--
-- Name: holdings_record_permanentlocationid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_permanentlocationid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (permanentlocationid);


--
-- Name: holdings_record_pmh_metadata_updateddate_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_pmh_metadata_updateddate_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (quesnelia_mod_inventory_storage.strtotimestamp(((jsonb -> 'metadata'::text) ->> 'updatedDate'::text)));


--
-- Name: holdings_record_sourceid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_sourceid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (sourceid);


--
-- Name: holdings_record_temporarylocationid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX holdings_record_temporarylocationid_idx ON quesnelia_mod_inventory_storage.holdings_record USING btree (temporarylocationid);


--
-- Name: holdings_records_source_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX holdings_records_source_name_idx_unique ON quesnelia_mod_inventory_storage.holdings_records_source USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: holdings_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX holdings_type_name_idx_unique ON quesnelia_mod_inventory_storage.holdings_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: identifier_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX identifier_type_name_idx_unique ON quesnelia_mod_inventory_storage.identifier_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: idx_instance_complete_updated_date; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX idx_instance_complete_updated_date ON quesnelia_mod_inventory_storage.instance USING btree (complete_updated_date);


--
-- Name: ill_policy_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX ill_policy_name_idx_unique ON quesnelia_mod_inventory_storage.ill_policy USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: instance_contributors_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_contributors_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'contributors'::text))), 600));


--
-- Name: instance_discoverysuppress_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_discoverysuppress_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower((jsonb ->> 'discoverySuppress'::text)), 600));


--
-- Name: instance_format_code_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_format_code_idx_unique ON quesnelia_mod_inventory_storage.instance_format USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))));


--
-- Name: instance_format_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_format_name_idx_unique ON quesnelia_mod_inventory_storage.instance_format USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: instance_hrid_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_hrid_idx_unique ON quesnelia_mod_inventory_storage.instance USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'hrid'::text))));


--
-- Name: instance_identifiers_idx_ft; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_identifiers_idx_ft ON quesnelia_mod_inventory_storage.instance USING gin (quesnelia_mod_inventory_storage.get_tsvector(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'identifiers'::text))));


--
-- Name: instance_identifiers_idx_gin; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_identifiers_idx_gin ON quesnelia_mod_inventory_storage.instance USING gin (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'identifiers'::text))) public.gin_trgm_ops);


--
-- Name: instance_indextitle_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_indextitle_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'indexTitle'::text))), 600));


--
-- Name: instance_instancestatusid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_instancestatusid_idx ON quesnelia_mod_inventory_storage.instance USING btree (instancestatusid);


--
-- Name: instance_instancetypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_instancetypeid_idx ON quesnelia_mod_inventory_storage.instance USING btree (instancetypeid);


--
-- Name: instance_invalidisbn_idx_ft; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_invalidisbn_idx_ft ON quesnelia_mod_inventory_storage.instance USING gin (quesnelia_mod_inventory_storage.get_tsvector(quesnelia_mod_inventory_storage.normalize_invalid_isbns((jsonb -> 'identifiers'::text))));


--
-- Name: instance_isbn_idx_ft; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_isbn_idx_ft ON quesnelia_mod_inventory_storage.instance USING gin (quesnelia_mod_inventory_storage.get_tsvector(quesnelia_mod_inventory_storage.normalize_isbns((jsonb -> 'identifiers'::text))));


--
-- Name: instance_matchkey_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_matchkey_idx_unique ON quesnelia_mod_inventory_storage.instance USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'matchKey'::text))));


--
-- Name: instance_metadata_updateddate_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_metadata_updateddate_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower(((jsonb -> 'metadata'::text) ->> 'updatedDate'::text)), 600));


--
-- Name: instance_modeofissuanceid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_modeofissuanceid_idx ON quesnelia_mod_inventory_storage.instance USING btree (modeofissuanceid);


--
-- Name: instance_note_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_note_type_name_idx_unique ON quesnelia_mod_inventory_storage.instance_note_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: instance_pmh_metadata_updateddate_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_pmh_metadata_updateddate_idx ON quesnelia_mod_inventory_storage.instance USING btree (quesnelia_mod_inventory_storage.strtotimestamp(((jsonb -> 'metadata'::text) ->> 'updatedDate'::text)));


--
-- Name: instance_publication_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_publication_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'publication'::text))), 600));


--
-- Name: instance_relationship_instancerelationshiptypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_relationship_instancerelationshiptypeid_idx ON quesnelia_mod_inventory_storage.instance_relationship USING btree (instancerelationshiptypeid);


--
-- Name: instance_relationship_subinstanceid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_relationship_subinstanceid_idx ON quesnelia_mod_inventory_storage.instance_relationship USING btree (subinstanceid);


--
-- Name: instance_relationship_superinstanceid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_relationship_superinstanceid_idx ON quesnelia_mod_inventory_storage.instance_relationship USING btree (superinstanceid);


--
-- Name: instance_relationship_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_relationship_type_name_idx_unique ON quesnelia_mod_inventory_storage.instance_relationship_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: instance_source_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_source_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower((jsonb ->> 'source'::text)), 600));


--
-- Name: instance_staffsuppress_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_staffsuppress_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower((jsonb ->> 'staffSuppress'::text)), 600));


--
-- Name: instance_statisticalcodeids_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_statisticalcodeids_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower((jsonb ->> 'statisticalCodeIds'::text)), 600));


--
-- Name: instance_status_code_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_status_code_idx_unique ON quesnelia_mod_inventory_storage.instance_status USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))));


--
-- Name: instance_status_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_status_name_idx_unique ON quesnelia_mod_inventory_storage.instance_status USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: instance_title_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX instance_title_idx ON quesnelia_mod_inventory_storage.instance USING btree ("left"(lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'title'::text))), 600));


--
-- Name: instance_type_code_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_type_code_idx_unique ON quesnelia_mod_inventory_storage.instance_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))));


--
-- Name: instance_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX instance_type_name_idx_unique ON quesnelia_mod_inventory_storage.instance_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: item_accessionnumber_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_accessionnumber_idx ON quesnelia_mod_inventory_storage.item USING btree ("left"(lower((jsonb ->> 'accessionNumber'::text)), 600));


--
-- Name: item_barcode_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX item_barcode_idx_unique ON quesnelia_mod_inventory_storage.item USING btree (lower((jsonb ->> 'barcode'::text)));


--
-- Name: item_callnumberandsuffix_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_callnumberandsuffix_idx ON quesnelia_mod_inventory_storage.item USING btree ("left"(lower(quesnelia_mod_inventory_storage.concat_space_sql(VARIADIC ARRAY[((jsonb -> 'effectiveCallNumberComponents'::text) ->> 'callNumber'::text), ((jsonb -> 'effectiveCallNumberComponents'::text) ->> 'suffix'::text)])), 600));


--
-- Name: item_damaged_status_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX item_damaged_status_name_idx_unique ON quesnelia_mod_inventory_storage.item_damaged_status USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: item_discoverysuppress_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_discoverysuppress_idx ON quesnelia_mod_inventory_storage.item USING btree ("left"(lower((jsonb ->> 'discoverySuppress'::text)), 600));


--
-- Name: item_effectivecallnumbercomponents_callnumber_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_effectivecallnumbercomponents_callnumber_idx ON quesnelia_mod_inventory_storage.item USING btree ("left"(lower(((jsonb -> 'effectiveCallNumberComponents'::text) ->> 'callNumber'::text)), 600));


--
-- Name: item_effectivelocationid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_effectivelocationid_idx ON quesnelia_mod_inventory_storage.item USING btree (effectivelocationid);


--
-- Name: item_fullcallnumber_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_fullcallnumber_idx ON quesnelia_mod_inventory_storage.item USING btree ("left"(lower(quesnelia_mod_inventory_storage.concat_space_sql(VARIADIC ARRAY[((jsonb -> 'effectiveCallNumberComponents'::text) ->> 'prefix'::text), ((jsonb -> 'effectiveCallNumberComponents'::text) ->> 'callNumber'::text), ((jsonb -> 'effectiveCallNumberComponents'::text) ->> 'suffix'::text)])), 600));


--
-- Name: item_holdingsrecordid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_holdingsrecordid_idx ON quesnelia_mod_inventory_storage.item USING btree (holdingsrecordid);


--
-- Name: item_hrid_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX item_hrid_idx_unique ON quesnelia_mod_inventory_storage.item USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'hrid'::text))));


--
-- Name: item_materialtypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_materialtypeid_idx ON quesnelia_mod_inventory_storage.item USING btree (materialtypeid);


--
-- Name: item_note_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX item_note_type_name_idx_unique ON quesnelia_mod_inventory_storage.item_note_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: item_permanentloantypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_permanentloantypeid_idx ON quesnelia_mod_inventory_storage.item USING btree (permanentloantypeid);


--
-- Name: item_permanentlocationid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_permanentlocationid_idx ON quesnelia_mod_inventory_storage.item USING btree (permanentlocationid);


--
-- Name: item_pmh_metadata_updateddate_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_pmh_metadata_updateddate_idx ON quesnelia_mod_inventory_storage.item USING btree (quesnelia_mod_inventory_storage.strtotimestamp(((jsonb -> 'metadata'::text) ->> 'updatedDate'::text)));


--
-- Name: item_purchaseorderlineidentifier_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_purchaseorderlineidentifier_idx ON quesnelia_mod_inventory_storage.item USING btree ("left"(lower((jsonb ->> 'purchaseOrderLineIdentifier'::text)), 600));


--
-- Name: item_status_name_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_status_name_idx ON quesnelia_mod_inventory_storage.item USING btree ("left"(lower(quesnelia_mod_inventory_storage.f_unaccent(((jsonb -> 'status'::text) ->> 'name'::text))), 600));


--
-- Name: item_temporaryloantypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_temporaryloantypeid_idx ON quesnelia_mod_inventory_storage.item USING btree (temporaryloantypeid);


--
-- Name: item_temporarylocationid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX item_temporarylocationid_idx ON quesnelia_mod_inventory_storage.item USING btree (temporarylocationid);


--
-- Name: loan_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX loan_type_name_idx_unique ON quesnelia_mod_inventory_storage.loan_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: location_campusid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX location_campusid_idx ON quesnelia_mod_inventory_storage.location USING btree (campusid);


--
-- Name: location_code_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX location_code_idx_unique ON quesnelia_mod_inventory_storage.location USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))));


--
-- Name: location_institutionid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX location_institutionid_idx ON quesnelia_mod_inventory_storage.location USING btree (institutionid);


--
-- Name: location_libraryid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX location_libraryid_idx ON quesnelia_mod_inventory_storage.location USING btree (libraryid);


--
-- Name: location_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX location_name_idx_unique ON quesnelia_mod_inventory_storage.location USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: location_primaryservicepoint_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX location_primaryservicepoint_idx ON quesnelia_mod_inventory_storage.location USING btree ("left"(lower((jsonb ->> 'primaryServicePoint'::text)), 600));


--
-- Name: loccampus_institutionid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX loccampus_institutionid_idx ON quesnelia_mod_inventory_storage.loccampus USING btree (institutionid);


--
-- Name: loccampus_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX loccampus_name_idx_unique ON quesnelia_mod_inventory_storage.loccampus USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: locinstitution_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX locinstitution_name_idx_unique ON quesnelia_mod_inventory_storage.locinstitution USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: loclibrary_campusid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX loclibrary_campusid_idx ON quesnelia_mod_inventory_storage.loclibrary USING btree (campusid);


--
-- Name: loclibrary_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX loclibrary_name_idx_unique ON quesnelia_mod_inventory_storage.loclibrary USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: material_type_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX material_type_name_idx_unique ON quesnelia_mod_inventory_storage.material_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: mode_of_issuance_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX mode_of_issuance_name_idx_unique ON quesnelia_mod_inventory_storage.mode_of_issuance USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: nature_of_content_term_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX nature_of_content_term_name_idx_unique ON quesnelia_mod_inventory_storage.nature_of_content_term USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: preceding_succeeding_title_precedinginstanceid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX preceding_succeeding_title_precedinginstanceid_idx ON quesnelia_mod_inventory_storage.preceding_succeeding_title USING btree (precedinginstanceid);


--
-- Name: preceding_succeeding_title_succeedinginstanceid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX preceding_succeeding_title_succeedinginstanceid_idx ON quesnelia_mod_inventory_storage.preceding_succeeding_title USING btree (succeedinginstanceid);


--
-- Name: service_point_code_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX service_point_code_idx_unique ON quesnelia_mod_inventory_storage.service_point USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))));


--
-- Name: service_point_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX service_point_name_idx_unique ON quesnelia_mod_inventory_storage.service_point USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: service_point_pickuplocation_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX service_point_pickuplocation_idx ON quesnelia_mod_inventory_storage.service_point USING btree ("left"(lower((jsonb ->> 'pickupLocation'::text)), 600));


--
-- Name: service_point_user_defaultservicepointid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX service_point_user_defaultservicepointid_idx ON quesnelia_mod_inventory_storage.service_point_user USING btree (defaultservicepointid);


--
-- Name: service_point_user_userid_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX service_point_user_userid_idx_unique ON quesnelia_mod_inventory_storage.service_point_user USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'userId'::text))));


--
-- Name: statistical_code_code_statisticalcodetypeid_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX statistical_code_code_statisticalcodetypeid_idx_unique ON quesnelia_mod_inventory_storage.statistical_code USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))), lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'statisticalCodeTypeId'::text))));


--
-- Name: statistical_code_name_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX statistical_code_name_idx_unique ON quesnelia_mod_inventory_storage.statistical_code USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'name'::text))));


--
-- Name: statistical_code_statisticalcodetypeid_idx; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE INDEX statistical_code_statisticalcodetypeid_idx ON quesnelia_mod_inventory_storage.statistical_code USING btree (statisticalcodetypeid);


--
-- Name: statistical_code_type_code_idx_unique; Type: INDEX; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE UNIQUE INDEX statistical_code_type_code_idx_unique ON quesnelia_mod_inventory_storage.statistical_code_type USING btree (lower(quesnelia_mod_inventory_storage.f_unaccent((jsonb ->> 'code'::text))));


--
-- Name: holdings_record audit_holdings_record; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER audit_holdings_record AFTER DELETE ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.audit_holdings_record_changes();


--
-- Name: instance audit_instance; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER audit_instance AFTER DELETE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.audit_instance_changes();


--
-- Name: item audit_item; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER audit_item AFTER DELETE ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.audit_item_changes();


--
-- Name: statistical_code check_item_statistical_code_reference_on_delete; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER check_item_statistical_code_reference_on_delete BEFORE DELETE ON quesnelia_mod_inventory_storage.statistical_code FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.process_statistical_code_delete();


--
-- Name: item check_statistical_code_references_on_insert; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER check_statistical_code_references_on_insert BEFORE INSERT ON quesnelia_mod_inventory_storage.item FOR EACH ROW WHEN ((((new.jsonb -> 'statisticalCodeIds'::text) IS NOT NULL) AND ((new.jsonb -> 'statisticalCodeIds'::text) <> '[]'::jsonb))) EXECUTE FUNCTION quesnelia_mod_inventory_storage.check_statistical_code_references();


--
-- Name: item check_statistical_code_references_on_update; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER check_statistical_code_references_on_update BEFORE UPDATE ON quesnelia_mod_inventory_storage.item FOR EACH ROW WHEN ((((new.jsonb -> 'statisticalCodeIds'::text) IS NOT NULL) AND ((new.jsonb -> 'statisticalCodeIds'::text) <> '[]'::jsonb) AND ((old.jsonb -> 'statisticalCodeIds'::text) IS DISTINCT FROM (new.jsonb -> 'statisticalCodeIds'::text)))) EXECUTE FUNCTION quesnelia_mod_inventory_storage.check_statistical_code_references();


--
-- Name: instance instance_check_statistical_code_references_on_insert; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER instance_check_statistical_code_references_on_insert BEFORE INSERT ON quesnelia_mod_inventory_storage.instance FOR EACH ROW WHEN ((((new.jsonb -> 'statisticalCodeIds'::text) IS NOT NULL) AND ((new.jsonb -> 'statisticalCodeIds'::text) <> '[]'::jsonb))) EXECUTE FUNCTION quesnelia_mod_inventory_storage.check_statistical_code_references();


--
-- Name: instance instance_check_statistical_code_references_on_update; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER instance_check_statistical_code_references_on_update BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW WHEN ((((new.jsonb -> 'statisticalCodeIds'::text) IS NOT NULL) AND ((new.jsonb -> 'statisticalCodeIds'::text) <> '[]'::jsonb) AND ((old.jsonb -> 'statisticalCodeIds'::text) IS DISTINCT FROM (new.jsonb -> 'statisticalCodeIds'::text)))) EXECUTE FUNCTION quesnelia_mod_inventory_storage.check_statistical_code_references();


--
-- Name: alternative_title_type set_alternative_title_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_alternative_title_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.alternative_title_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_alternative_title_type_md_json();


--
-- Name: alternative_title_type set_alternative_title_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_alternative_title_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.alternative_title_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.alternative_title_type_set_md();


--
-- Name: bound_with_part set_bound_with_part_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_bound_with_part_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.bound_with_part FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_bound_with_part_md_json();


--
-- Name: bound_with_part set_bound_with_part_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_bound_with_part_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.bound_with_part FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.bound_with_part_set_md();


--
-- Name: call_number_type set_call_number_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_call_number_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.call_number_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_call_number_type_md_json();


--
-- Name: call_number_type set_call_number_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_call_number_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.call_number_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.call_number_type_set_md();


--
-- Name: classification_type set_classification_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_classification_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.classification_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_classification_type_md_json();


--
-- Name: classification_type set_classification_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_classification_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.classification_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.classification_type_set_md();


--
-- Name: contributor_name_type set_contributor_name_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_contributor_name_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.contributor_name_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_contributor_name_type_md_json();


--
-- Name: contributor_name_type set_contributor_name_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_contributor_name_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.contributor_name_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.contributor_name_type_set_md();


--
-- Name: electronic_access_relationship set_electronic_access_relationship_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_electronic_access_relationship_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.electronic_access_relationship FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_electronic_access_relationship_md_json();


--
-- Name: electronic_access_relationship set_electronic_access_relationship_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_electronic_access_relationship_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.electronic_access_relationship FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.electronic_access_relationship_set_md();


--
-- Name: holdings_note_type set_holdings_note_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_note_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.holdings_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_holdings_note_type_md_json();


--
-- Name: holdings_note_type set_holdings_note_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_note_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.holdings_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.holdings_note_type_set_md();


--
-- Name: holdings_record set_holdings_record_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_record_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_holdings_record_md_json();


--
-- Name: holdings_record set_holdings_record_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_record_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.holdings_record_set_md();


--
-- Name: holdings_record set_holdings_record_ol_version_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_record_ol_version_trigger BEFORE INSERT OR UPDATE OF jsonb ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.holdings_record_set_ol_version();


--
-- Name: holdings_records_source set_holdings_records_source_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_records_source_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.holdings_records_source FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_holdings_records_source_md_json();


--
-- Name: holdings_records_source set_holdings_records_source_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_records_source_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.holdings_records_source FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.holdings_records_source_set_md();


--
-- Name: holdings_type set_holdings_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.holdings_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_holdings_type_md_json();


--
-- Name: holdings_type set_holdings_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_holdings_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.holdings_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.holdings_type_set_md();


--
-- Name: hrid_settings set_hrid_settings_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

CREATE TRIGGER set_hrid_settings_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.hrid_settings FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_hrid_settings_md_json();


--
-- Name: hrid_settings set_hrid_settings_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

CREATE TRIGGER set_hrid_settings_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.hrid_settings FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.hrid_settings_set_md();


--
-- Name: alternative_title_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.alternative_title_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: async_migration_job set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.async_migration_job FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: bound_with_part set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.bound_with_part FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: call_number_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.call_number_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: classification_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.classification_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: contributor_name_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.contributor_name_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: contributor_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.contributor_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: electronic_access_relationship set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.electronic_access_relationship FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: holdings_note_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.holdings_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: holdings_record set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: holdings_records_source set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.holdings_records_source FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: holdings_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.holdings_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: hrid_settings set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: quesnelia_mod_inventory_storage
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.hrid_settings FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: identifier_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.identifier_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: ill_policy set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.ill_policy FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance_format set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_format FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance_note_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance_relationship set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_relationship FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance_relationship_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_relationship_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance_source_marc set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_source_marc FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance_status set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_status FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: instance_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: item set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: item_damaged_status set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.item_damaged_status FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: item_note_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.item_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: iteration_job set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.iteration_job FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: loan_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.loan_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: location set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.location FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: loccampus set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.loccampus FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: locinstitution set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.locinstitution FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: loclibrary set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.loclibrary FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: material_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.material_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: mode_of_issuance set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.mode_of_issuance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: nature_of_content_term set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.nature_of_content_term FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: notification_sending_error set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.notification_sending_error FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: preceding_succeeding_title set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.preceding_succeeding_title FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: reindex_job set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.reindex_job FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: related_instance_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.related_instance_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: service_point set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.service_point FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: service_point_user set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.service_point_user FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: statistical_code set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.statistical_code FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: statistical_code_type set_id_in_jsonb; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_id_in_jsonb BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.statistical_code_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_id_in_jsonb();


--
-- Name: identifier_type set_identifier_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_identifier_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.identifier_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_identifier_type_md_json();


--
-- Name: identifier_type set_identifier_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_identifier_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.identifier_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.identifier_type_set_md();


--
-- Name: ill_policy set_ill_policy_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_ill_policy_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.ill_policy FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_ill_policy_md_json();


--
-- Name: ill_policy set_ill_policy_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_ill_policy_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.ill_policy FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.ill_policy_set_md();


--
-- Name: instance set_instance_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_md_json();


--
-- Name: instance set_instance_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.instance_set_md();


--
-- Name: instance_note_type set_instance_note_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_note_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_note_type_md_json();


--
-- Name: instance_note_type set_instance_note_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_note_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.instance_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.instance_note_type_set_md();


--
-- Name: instance set_instance_ol_version_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_ol_version_trigger BEFORE INSERT OR UPDATE OF jsonb ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.instance_set_ol_version();


--
-- Name: instance_relationship set_instance_relationship_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_relationship_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance_relationship FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_relationship_md_json();


--
-- Name: instance_relationship set_instance_relationship_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_relationship_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.instance_relationship FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.instance_relationship_set_md();


--
-- Name: instance_relationship_type set_instance_relationship_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_relationship_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance_relationship_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_relationship_type_md_json();


--
-- Name: instance_relationship_type set_instance_relationship_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_relationship_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.instance_relationship_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.instance_relationship_type_set_md();


--
-- Name: instance_source_marc set_instance_source_marc_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_source_marc_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance_source_marc FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_source_marc_md_json();


--
-- Name: instance_source_marc set_instance_source_marc_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_source_marc_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.instance_source_marc FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.instance_source_marc_set_md();


--
-- Name: instance set_instance_sourcerecordformat; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_sourcerecordformat BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_sourcerecordformat();


--
-- Name: instance_status set_instance_status_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_status_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance_status FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_status_md_json();


--
-- Name: instance_status set_instance_status_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_status_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.instance_status FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.instance_status_set_md();


--
-- Name: instance set_instance_status_updated_date; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_instance_status_updated_date BEFORE UPDATE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_instance_status_updated_date();


--
-- Name: item_damaged_status set_item_damaged_status_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_item_damaged_status_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.item_damaged_status FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_item_damaged_status_md_json();


--
-- Name: item_damaged_status set_item_damaged_status_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_item_damaged_status_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.item_damaged_status FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.item_damaged_status_set_md();


--
-- Name: item set_item_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_item_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_item_md_json();


--
-- Name: item set_item_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_item_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.item_set_md();


--
-- Name: item_note_type set_item_note_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_item_note_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.item_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_item_note_type_md_json();


--
-- Name: item_note_type set_item_note_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_item_note_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.item_note_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.item_note_type_set_md();


--
-- Name: item set_item_ol_version_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_item_ol_version_trigger BEFORE INSERT OR UPDATE OF jsonb ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.item_set_ol_version();


--
-- Name: loan_type set_loan_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_loan_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.loan_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_loan_type_md_json();


--
-- Name: loan_type set_loan_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_loan_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.loan_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.loan_type_set_md();


--
-- Name: location set_location_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_location_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.location FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_location_md_json();


--
-- Name: location set_location_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_location_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.location FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.location_set_md();


--
-- Name: loccampus set_loccampus_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_loccampus_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.loccampus FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_loccampus_md_json();


--
-- Name: loccampus set_loccampus_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_loccampus_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.loccampus FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.loccampus_set_md();


--
-- Name: locinstitution set_locinstitution_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_locinstitution_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.locinstitution FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_locinstitution_md_json();


--
-- Name: locinstitution set_locinstitution_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_locinstitution_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.locinstitution FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.locinstitution_set_md();


--
-- Name: loclibrary set_loclibrary_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_loclibrary_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.loclibrary FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_loclibrary_md_json();


--
-- Name: loclibrary set_loclibrary_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_loclibrary_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.loclibrary FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.loclibrary_set_md();


--
-- Name: material_type set_material_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_material_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.material_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_material_type_md_json();


--
-- Name: material_type set_material_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_material_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.material_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.material_type_set_md();


--
-- Name: mode_of_issuance set_mode_of_issuance_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_mode_of_issuance_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.mode_of_issuance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_mode_of_issuance_md_json();


--
-- Name: mode_of_issuance set_mode_of_issuance_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_mode_of_issuance_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.mode_of_issuance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.mode_of_issuance_set_md();


--
-- Name: nature_of_content_term set_nature_of_content_term_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_nature_of_content_term_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.nature_of_content_term FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_nature_of_content_term_md_json();


--
-- Name: nature_of_content_term set_nature_of_content_term_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_nature_of_content_term_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.nature_of_content_term FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.nature_of_content_term_set_md();


--
-- Name: preceding_succeeding_title set_preceding_succeeding_title_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_preceding_succeeding_title_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.preceding_succeeding_title FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_preceding_succeeding_title_md_json();


--
-- Name: preceding_succeeding_title set_preceding_succeeding_title_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_preceding_succeeding_title_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.preceding_succeeding_title FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.preceding_succeeding_title_set_md();


--
-- Name: service_point set_service_point_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_service_point_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.service_point FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_service_point_md_json();


--
-- Name: service_point set_service_point_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_service_point_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.service_point FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.service_point_set_md();


--
-- Name: service_point_user set_service_point_user_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_service_point_user_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.service_point_user FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_service_point_user_md_json();


--
-- Name: service_point_user set_service_point_user_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_service_point_user_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.service_point_user FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.service_point_user_set_md();


--
-- Name: statistical_code set_statistical_code_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_statistical_code_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.statistical_code FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_statistical_code_md_json();


--
-- Name: statistical_code set_statistical_code_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_statistical_code_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.statistical_code FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.statistical_code_set_md();


--
-- Name: statistical_code_type set_statistical_code_type_md_json_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_statistical_code_type_md_json_trigger BEFORE UPDATE ON quesnelia_mod_inventory_storage.statistical_code_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.set_statistical_code_type_md_json();


--
-- Name: statistical_code_type set_statistical_code_type_md_trigger; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER set_statistical_code_type_md_trigger BEFORE INSERT ON quesnelia_mod_inventory_storage.statistical_code_type FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.statistical_code_type_set_md();


--
-- Name: bound_with_part update_bound_with_part_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_bound_with_part_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.bound_with_part FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_bound_with_part_references();


--
-- Name: holdings_record update_holdings_record_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_holdings_record_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_holdings_record_references();


--
-- Name: instance update_instance_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_instance_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_instance_references();


--
-- Name: instance_relationship update_instance_relationship_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_instance_relationship_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance_relationship FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_instance_relationship_references();


--
-- Name: instance_source_marc update_instance_source_marc; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_instance_source_marc AFTER INSERT OR DELETE OR UPDATE ON quesnelia_mod_inventory_storage.instance_source_marc FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_instance_source_marc();


--
-- Name: item update_item_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_item_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_item_references();


--
-- Name: item update_item_status_date; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_item_status_date BEFORE UPDATE ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_item_status_date();


--
-- Name: location update_location_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_location_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.location FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_location_references();


--
-- Name: loccampus update_loccampus_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_loccampus_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.loccampus FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_loccampus_references();


--
-- Name: loclibrary update_loclibrary_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_loclibrary_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.loclibrary FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_loclibrary_references();


--
-- Name: preceding_succeeding_title update_preceding_succeeding_title_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_preceding_succeeding_title_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.preceding_succeeding_title FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_preceding_succeeding_title_references();


--
-- Name: service_point_user update_service_point_user_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_service_point_user_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.service_point_user FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_service_point_user_references();


--
-- Name: statistical_code update_statistical_code_references; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER update_statistical_code_references BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.statistical_code FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.update_statistical_code_references();


--
-- Name: holdings_record updatecompleteupdateddate_holdings_record_delete; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER updatecompleteupdateddate_holdings_record_delete AFTER DELETE ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_holdings_delete();


--
-- Name: holdings_record updatecompleteupdateddate_holdings_record_insert_update; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER updatecompleteupdateddate_holdings_record_insert_update BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.holdings_record FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_holdings_insert_update();


--
-- Name: instance updatecompleteupdateddate_instance; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER updatecompleteupdateddate_instance BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.instance FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_instance();


--
-- Name: item updatecompleteupdateddate_item_delete; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER updatecompleteupdateddate_item_delete AFTER DELETE ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_item_delete();


--
-- Name: item updatecompleteupdateddate_item_insert_update; Type: TRIGGER; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

CREATE TRIGGER updatecompleteupdateddate_item_insert_update BEFORE INSERT OR UPDATE ON quesnelia_mod_inventory_storage.item FOR EACH ROW EXECUTE FUNCTION quesnelia_mod_inventory_storage.completeupdateddate_for_item_insert_update();


--
-- Name: holdings_record callnumbertypeid_call_number_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT callnumbertypeid_call_number_type_fkey FOREIGN KEY (callnumbertypeid) REFERENCES quesnelia_mod_inventory_storage.call_number_type(id);


--
-- Name: loclibrary campusid_loccampus_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.loclibrary
    ADD CONSTRAINT campusid_loccampus_fkey FOREIGN KEY (campusid) REFERENCES quesnelia_mod_inventory_storage.loccampus(id);


--
-- Name: location campusid_loccampus_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.location
    ADD CONSTRAINT campusid_loccampus_fkey FOREIGN KEY (campusid) REFERENCES quesnelia_mod_inventory_storage.loccampus(id);


--
-- Name: service_point_user defaultservicepointid_service_point_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.service_point_user
    ADD CONSTRAINT defaultservicepointid_service_point_fkey FOREIGN KEY (defaultservicepointid) REFERENCES quesnelia_mod_inventory_storage.service_point(id);


--
-- Name: holdings_record effectivelocationid_location_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT effectivelocationid_location_fkey FOREIGN KEY (effectivelocationid) REFERENCES quesnelia_mod_inventory_storage.location(id);


--
-- Name: item effectivelocationid_location_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT effectivelocationid_location_fkey FOREIGN KEY (effectivelocationid) REFERENCES quesnelia_mod_inventory_storage.location(id);


--
-- Name: item holdingsrecordid_holdings_record_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT holdingsrecordid_holdings_record_fkey FOREIGN KEY (holdingsrecordid) REFERENCES quesnelia_mod_inventory_storage.holdings_record(id);


--
-- Name: bound_with_part holdingsrecordid_holdings_record_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.bound_with_part
    ADD CONSTRAINT holdingsrecordid_holdings_record_fkey FOREIGN KEY (holdingsrecordid) REFERENCES quesnelia_mod_inventory_storage.holdings_record(id);


--
-- Name: holdings_record holdingstypeid_holdings_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT holdingstypeid_holdings_type_fkey FOREIGN KEY (holdingstypeid) REFERENCES quesnelia_mod_inventory_storage.holdings_type(id);


--
-- Name: holdings_record illpolicyid_ill_policy_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT illpolicyid_ill_policy_fkey FOREIGN KEY (illpolicyid) REFERENCES quesnelia_mod_inventory_storage.ill_policy(id);


--
-- Name: instance_source_marc instance_source_marc_id_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_source_marc
    ADD CONSTRAINT instance_source_marc_id_fkey FOREIGN KEY (id) REFERENCES quesnelia_mod_inventory_storage.instance(id) ON DELETE CASCADE;


--
-- Name: holdings_record instanceid_instance_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT instanceid_instance_fkey FOREIGN KEY (instanceid) REFERENCES quesnelia_mod_inventory_storage.instance(id);


--
-- Name: instance_relationship instancerelationshiptypeid_instance_relationship_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_relationship
    ADD CONSTRAINT instancerelationshiptypeid_instance_relationship_type_fkey FOREIGN KEY (instancerelationshiptypeid) REFERENCES quesnelia_mod_inventory_storage.instance_relationship_type(id);


--
-- Name: instance instancestatusid_instance_status_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance
    ADD CONSTRAINT instancestatusid_instance_status_fkey FOREIGN KEY (instancestatusid) REFERENCES quesnelia_mod_inventory_storage.instance_status(id);


--
-- Name: instance instancetypeid_instance_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance
    ADD CONSTRAINT instancetypeid_instance_type_fkey FOREIGN KEY (instancetypeid) REFERENCES quesnelia_mod_inventory_storage.instance_type(id);


--
-- Name: loccampus institutionid_locinstitution_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.loccampus
    ADD CONSTRAINT institutionid_locinstitution_fkey FOREIGN KEY (institutionid) REFERENCES quesnelia_mod_inventory_storage.locinstitution(id);


--
-- Name: location institutionid_locinstitution_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.location
    ADD CONSTRAINT institutionid_locinstitution_fkey FOREIGN KEY (institutionid) REFERENCES quesnelia_mod_inventory_storage.locinstitution(id);


--
-- Name: bound_with_part itemid_item_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.bound_with_part
    ADD CONSTRAINT itemid_item_fkey FOREIGN KEY (itemid) REFERENCES quesnelia_mod_inventory_storage.item(id);


--
-- Name: location libraryid_loclibrary_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.location
    ADD CONSTRAINT libraryid_loclibrary_fkey FOREIGN KEY (libraryid) REFERENCES quesnelia_mod_inventory_storage.loclibrary(id);


--
-- Name: item materialtypeid_material_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT materialtypeid_material_type_fkey FOREIGN KEY (materialtypeid) REFERENCES quesnelia_mod_inventory_storage.material_type(id);


--
-- Name: instance modeofissuanceid_mode_of_issuance_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance
    ADD CONSTRAINT modeofissuanceid_mode_of_issuance_fkey FOREIGN KEY (modeofissuanceid) REFERENCES quesnelia_mod_inventory_storage.mode_of_issuance(id);


--
-- Name: item permanentloantypeid_loan_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT permanentloantypeid_loan_type_fkey FOREIGN KEY (permanentloantypeid) REFERENCES quesnelia_mod_inventory_storage.loan_type(id);


--
-- Name: holdings_record permanentlocationid_location_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT permanentlocationid_location_fkey FOREIGN KEY (permanentlocationid) REFERENCES quesnelia_mod_inventory_storage.location(id);


--
-- Name: item permanentlocationid_location_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT permanentlocationid_location_fkey FOREIGN KEY (permanentlocationid) REFERENCES quesnelia_mod_inventory_storage.location(id);


--
-- Name: preceding_succeeding_title precedinginstanceid_instance_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.preceding_succeeding_title
    ADD CONSTRAINT precedinginstanceid_instance_fkey FOREIGN KEY (precedinginstanceid) REFERENCES quesnelia_mod_inventory_storage.instance(id);


--
-- Name: holdings_record sourceid_holdings_records_source_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT sourceid_holdings_records_source_fkey FOREIGN KEY (sourceid) REFERENCES quesnelia_mod_inventory_storage.holdings_records_source(id);


--
-- Name: statistical_code statisticalcodetypeid_statistical_code_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.statistical_code
    ADD CONSTRAINT statisticalcodetypeid_statistical_code_type_fkey FOREIGN KEY (statisticalcodetypeid) REFERENCES quesnelia_mod_inventory_storage.statistical_code_type(id);


--
-- Name: instance_relationship subinstanceid_instance_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_relationship
    ADD CONSTRAINT subinstanceid_instance_fkey FOREIGN KEY (subinstanceid) REFERENCES quesnelia_mod_inventory_storage.instance(id);


--
-- Name: preceding_succeeding_title succeedinginstanceid_instance_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.preceding_succeeding_title
    ADD CONSTRAINT succeedinginstanceid_instance_fkey FOREIGN KEY (succeedinginstanceid) REFERENCES quesnelia_mod_inventory_storage.instance(id);


--
-- Name: instance_relationship superinstanceid_instance_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.instance_relationship
    ADD CONSTRAINT superinstanceid_instance_fkey FOREIGN KEY (superinstanceid) REFERENCES quesnelia_mod_inventory_storage.instance(id);


--
-- Name: item temporaryloantypeid_loan_type_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT temporaryloantypeid_loan_type_fkey FOREIGN KEY (temporaryloantypeid) REFERENCES quesnelia_mod_inventory_storage.loan_type(id);


--
-- Name: holdings_record temporarylocationid_location_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.holdings_record
    ADD CONSTRAINT temporarylocationid_location_fkey FOREIGN KEY (temporarylocationid) REFERENCES quesnelia_mod_inventory_storage.location(id);


--
-- Name: item temporarylocationid_location_fkey; Type: FK CONSTRAINT; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

ALTER TABLE ONLY quesnelia_mod_inventory_storage.item
    ADD CONSTRAINT temporarylocationid_location_fkey FOREIGN KEY (temporarylocationid) REFERENCES quesnelia_mod_inventory_storage.location(id);


--
-- Name: TABLE alternative_title_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.alternative_title_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE async_migration_job; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.async_migration_job TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE audit_holdings_record; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.audit_holdings_record TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE audit_instance; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.audit_instance TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE audit_item; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.audit_item TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE bound_with_part; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.bound_with_part TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE call_number_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.call_number_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE classification_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.classification_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE contributor_name_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.contributor_name_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE contributor_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.contributor_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE electronic_access_relationship; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.electronic_access_relationship TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE holdings_note_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.holdings_note_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE holdings_record; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.holdings_record TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE holdings_records_source; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.holdings_records_source TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE holdings_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.holdings_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE hrid_settings_view; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.hrid_settings_view TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE identifier_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.identifier_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE ill_policy; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.ill_policy TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_format; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_format TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE item; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.item TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_holdings_item_view; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_holdings_item_view TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_note_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_note_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_relationship; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_relationship TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_relationship_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_relationship_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE preceding_succeeding_title; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.preceding_succeeding_title TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_set; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_set TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_source_marc; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_source_marc TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_status; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_status TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE instance_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.instance_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE item_damaged_status; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.item_damaged_status TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE item_note_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.item_note_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE iteration_job; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.iteration_job TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE loan_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.loan_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE location; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.location TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE loccampus; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.loccampus TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE locinstitution; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.locinstitution TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE loclibrary; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.loclibrary TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE material_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.material_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE mode_of_issuance; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.mode_of_issuance TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE nature_of_content_term; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.nature_of_content_term TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE notification_sending_error; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.notification_sending_error TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE reindex_job; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.reindex_job TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE related_instance_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.related_instance_type TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE rmb_internal; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.rmb_internal TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE rmb_internal_analyze; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.rmb_internal_analyze TO quesnelia_mod_inventory_storage;


--
-- Name: SEQUENCE rmb_internal_id_seq; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON SEQUENCE quesnelia_mod_inventory_storage.rmb_internal_id_seq TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE rmb_internal_index; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.rmb_internal_index TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE rmb_job; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.rmb_job TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE service_point; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.service_point TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE service_point_user; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.service_point_user TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE statistical_code; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.statistical_code TO quesnelia_mod_inventory_storage;


--
-- Name: TABLE statistical_code_type; Type: ACL; Schema: quesnelia_mod_inventory_storage; Owner: postgres
--

GRANT ALL ON TABLE quesnelia_mod_inventory_storage.statistical_code_type TO quesnelia_mod_inventory_storage;


--
-- PostgreSQL database dump complete
--

