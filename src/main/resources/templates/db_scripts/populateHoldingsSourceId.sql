-- cannot be started from schema.json because it needs read permission for …_mod_source_record_storage.records_lb
DO $$
  DECLARE
    n BIGINT;
    trigger VARCHAR;
    triggers VARCHAR[] DEFAULT ARRAY[
      -- do NOT disable update_holdings_record_references, it copies jsonb->'sourceId' into sourceId column
      'audit_holdings_record',
      'set_holdings_record_md_json_trigger',
      'set_holdings_record_md_trigger',
      'set_holdings_record_ol_version_trigger',
      'set_id_in_jsonb',
      'updatecompleteupdateddate_holdings_record_delete',
      'updatecompleteupdateddate_holdings_record_insert_update'
    ];
    arr UUID[] DEFAULT ARRAY[
      '10000000-0000-0000-0000-000000000000',
      '20000000-0000-0000-0000-000000000000',
      '30000000-0000-0000-0000-000000000000',
      '40000000-0000-0000-0000-000000000000',
      '50000000-0000-0000-0000-000000000000',
      '60000000-0000-0000-0000-000000000000',
      '70000000-0000-0000-0000-000000000000',
      '80000000-0000-0000-0000-000000000000',
      '90000000-0000-0000-0000-000000000000',
      'a0000000-0000-0000-0000-000000000000',
      'b0000000-0000-0000-0000-000000000000',
      'c0000000-0000-0000-0000-000000000000',
      'd0000000-0000-0000-0000-000000000000',
      'e0000000-0000-0000-0000-000000000000',
      'f0000000-0000-0000-0000-000000000000',
      'ffffffff-ffff-ffff-ffff-ffffffffffff'
    ];
    lower UUID;
    cur UUID;
    srs_schema TEXT;
    rowcount BIGINT;
  BEGIN
    -- Count holdings records that lack the sourceid and therefore require migration.
    -- There's the holdings_record_sourceid_idx btree index making this extremely fast.
    SELECT count(*) INTO n FROM holdings_record WHERE sourceid IS NULL;
    IF n = 0 THEN
      RETURN;
    END IF;

    RAISE INFO 'Starting to migrate % holdings records by setting sourceId', n;

    srs_schema := regexp_replace(current_schema, '(.*)_mod_inventory_storage$', '\1_mod_source_record_storage');

    -- Disable triggers
    FOREACH trigger IN ARRAY triggers LOOP
      EXECUTE format('ALTER TABLE holdings_record DISABLE TRIGGER %I', trigger);
    END LOOP;

    -- Set sourceId
    lower := '00000000-0000-0000-0000-000000000000';
    FOREACH cur IN ARRAY arr
    LOOP
      RAISE INFO 'range: % - %', lower, cur;

      -- Update holding records
      EXECUTE format($q$
          UPDATE holdings_record h
            SET jsonb = jsonb_set(h.jsonb, '{sourceId}',
                          CASE
                            -- MARC HOLDING
                            WHEN EXISTS(SELECT *
                                        FROM %I.records_lb r
                                        WHERE h.id=r.external_id) THEN
                                '"036ee84a-6afd-4c3c-9ad3-4a12ab875f59"'::jsonb
                            -- FOLIO HOLDING
                            ELSE
                                '"f32d531e-df79-46b3-8932-cdd35f7a2264"'::jsonb
                          END
                        )
            WHERE $1 < h.id AND h.id <= $2
              AND sourceId IS NULL;
        $q$, srs_schema) USING lower, cur;

      GET DIAGNOSTICS rowcount = ROW_COUNT;
      RAISE INFO 'updated a chunk of % holding records', rowcount;

      lower := cur;
    END LOOP;

    -- Enable triggers
    FOREACH trigger IN ARRAY triggers LOOP
      EXECUTE format('ALTER TABLE holdings_record ENABLE TRIGGER %I', trigger);
    END LOOP;

    RAISE INFO 'Finished migrating % holdings records by setting sourceId', n;
  END;
$$ LANGUAGE 'plpgsql';
