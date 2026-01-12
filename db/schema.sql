--
-- PostgreSQL database dump
--

\restrict AyUIGP0UcExq1AFbYZAaXEryIslb1QfSqE9O5AU5peCbDNHqc51YcloVULc7j3h

-- Dumped from database version 17.7 (e429a59)
-- Dumped by pg_dump version 18.0

-- Started on 2026-01-12 13:50:15 MST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: lioneye
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO lioneye;

--
-- TOC entry 939 (class 1247 OID 40961)
-- Name: competition_input_mode; Type: TYPE; Schema: public; Owner: lioneye
--

CREATE TYPE public.competition_input_mode AS ENUM (
    'AUTO',
    'MANUAL',
    'CUSTOM'
);


ALTER TYPE public.competition_input_mode OWNER TO lioneye;

--
-- TOC entry 978 (class 1247 OID 188417)
-- Name: competition_type_scope; Type: TYPE; Schema: public; Owner: lioneye
--

CREATE TYPE public.competition_type_scope AS ENUM (
    'EVENT',
    'FLIGHT',
    'GROUP',
    'HOLE'
);


ALTER TYPE public.competition_type_scope OWNER TO lioneye;

--
-- TOC entry 276 (class 1255 OID 57344)
-- Name: assign_flights(bigint, integer); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.assign_flights(p_event_id bigint, p_group_size integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

    WITH ranked AS (
        SELECT
            ep.event_player_id,
            ep.hcap_index,
            ROW_NUMBER() OVER (ORDER BY ep.hcap_index ASC) AS rn,
            COUNT(*) OVER () AS total
        FROM event_player ep
        WHERE ep.event_id = p_event_id
    ),
    flight_info AS (
        SELECT
            *,
            CEIL(total::numeric / p_group_size::numeric) AS num_flights
        FROM ranked
    ),
    flight_calc AS (
        SELECT
            event_player_id,
            rn,
            total,
            num_flights,
            CEIL(rn::numeric / (total::numeric / num_flights)) AS flight_number
        FROM flight_info
    )
    UPDATE event_player ep
    SET flight_name = CHR(64 + fc.flight_number::int)
    FROM flight_calc fc
    WHERE ep.event_player_id = fc.event_player_id;

END;
$$;


ALTER FUNCTION public.assign_flights(p_event_id bigint, p_group_size integer) OWNER TO lioneye;

--
-- TOC entry 302 (class 1255 OID 352257)
-- Name: assign_flights(bigint, integer, text); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.assign_flights(p_event_id bigint, p_group_size integer, p_basis text DEFAULT 'HCAP_INDEX'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH ranked AS (
        SELECT
            ep.event_player_id,

            CASE
              WHEN p_basis = 'course_handicap' THEN ep.course_handicap
              ELSE ep.hcap_index
            END AS sort_value,

            ROW_NUMBER() OVER (
              ORDER BY
                CASE
                  WHEN p_basis = 'course_handicap' THEN ep.course_handicap
                  ELSE ep.hcap_index
                END ASC,
                ep.event_player_id
            ) AS rn,

            COUNT(*) OVER () AS total
        FROM event_player ep
        WHERE ep.event_id = p_event_id
    ),
    flight_info AS (
        SELECT
            *,
            CEIL(total::numeric / p_group_size::numeric) AS num_flights
        FROM ranked
    ),
    flight_calc AS (
        SELECT
            event_player_id,
            CEIL(
              rn::numeric / (total::numeric / num_flights)
            ) AS flight_number
        FROM flight_info
    )
    UPDATE event_player ep
    SET flight_name = CHR(64 + fc.flight_number::int)
    FROM flight_calc fc
    WHERE ep.event_player_id = fc.event_player_id;

END;
$$;


ALTER FUNCTION public.assign_flights(p_event_id bigint, p_group_size integer, p_basis text) OWNER TO lioneye;

--
-- TOC entry 288 (class 1255 OID 65647)
-- Name: assign_groups(bigint, integer, time without time zone, integer); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.assign_groups(p_event_id bigint, p_group_size integer, p_start_time time without time zone, p_interval_minutes integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_player_ids BIGINT[];
    v_player_count INT;
    full_groups INT;
    remainder INT;

    group_sizes INT[] := ARRAY[]::INT[];
    i INT;
    idx INT := 1;
BEGIN
    ----------------------------------------------------------------------
    -- 1. Clear existing assignments
    ----------------------------------------------------------------------
    UPDATE event_player
    SET group_id = NULL
    WHERE event_id = p_event_id;

    DELETE FROM event_group
    WHERE event_id = p_event_id;

    ----------------------------------------------------------------------
    -- 2. Load and shuffle players
    ----------------------------------------------------------------------
    SELECT ARRAY_AGG(event_player_id ORDER BY RANDOM())
    INTO v_player_ids
    FROM event_player
    WHERE event_id = p_event_id;

    v_player_count := COALESCE(array_length(v_player_ids, 1), 0);

    IF v_player_count = 0 THEN
        RETURN jsonb_build_object('event_id', p_event_id, 'groups', 0);
    END IF;

    ----------------------------------------------------------------------
    -- 3. Compute base math for group sizes
    ----------------------------------------------------------------------
    full_groups := v_player_count / p_group_size;       -- integer division
    remainder   := v_player_count % p_group_size;

    -- Add full-sized groups
    FOR i IN 1..full_groups LOOP
        group_sizes := array_append(group_sizes, p_group_size);
    END LOOP;

    ----------------------------------------------------------------------
    -- PURE MATH ADJUSTMENT (no loops, no borrowing logic)
    ----------------------------------------------------------------------
    IF remainder = 0 THEN
        -- nothing to add
    ELSIF remainder = 3 THEN
        group_sizes := array_append(group_sizes, 3);

    ELSIF remainder = 1 THEN
        -- convert two groups from 4 → 3 and make a final 3
        IF full_groups >= 2 THEN
            group_sizes[full_groups]     := group_sizes[full_groups] - 1;
            group_sizes[full_groups - 1] := group_sizes[full_groups - 1] - 1;
            group_sizes := array_append(group_sizes, 3);
        ELSE
            -- Tiny event with only 1–2 players total
            group_sizes := ARRAY[remainder];
        END IF;

    ELSIF remainder = 2 THEN
        -- convert one group from 4 → 3 and make a final 3
        IF full_groups >= 1 THEN
            group_sizes[full_groups] := group_sizes[full_groups] - 1;
            group_sizes := array_append(group_sizes, 3);
        ELSE
            -- Only 2 players total
            group_sizes := ARRAY[2];
        END IF;
    END IF;

    ----------------------------------------------------------------------
    -- 4. Create event_group rows
    ----------------------------------------------------------------------
    FOR i IN 1..array_length(group_sizes, 1) LOOP
        INSERT INTO event_group (
            event_id, group_id, group_label, tee_time, starting_hole
        )
        VALUES (
            p_event_id,
            i,
            'Group ' || i,
            p_start_time + make_interval(mins => (i - 1) * p_interval_minutes),
            1
        );
    END LOOP;

    ----------------------------------------------------------------------
    -- 5. Assign players sequentially into buckets defined by group_sizes
    ----------------------------------------------------------------------
    idx := 1;

    FOR i IN 1..array_length(group_sizes, 1) LOOP
        UPDATE event_player
        SET group_id = i
        WHERE event_player_id IN (
            SELECT v_player_ids[j]
            FROM generate_series(idx, idx + group_sizes[i] - 1) AS j
        );
        idx := idx + group_sizes[i];
    END LOOP;

    ----------------------------------------------------------------------
    -- 6. Return summary
    ----------------------------------------------------------------------
    RETURN jsonb_build_object(
        'event_id', p_event_id,
        'group_sizes', group_sizes,
        'players', v_player_count,
        'groups', array_length(group_sizes, 1)
    );

END;
$$;


ALTER FUNCTION public.assign_groups(p_event_id bigint, p_group_size integer, p_start_time time without time zone, p_interval_minutes integer) OWNER TO lioneye;

--
-- TOC entry 279 (class 1255 OID 163884)
-- Name: check_competition_result_consistency(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.check_competition_result_consistency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.competition_id <>
     (SELECT competition_id
      FROM competition_run
      WHERE competition_run_id = NEW.competition_run_id) THEN
    RAISE EXCEPTION 'competition_id does not match competition_run';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_competition_result_consistency() OWNER TO lioneye;

--
-- TOC entry 304 (class 1255 OID 327694)
-- Name: compute_closest_to_pin(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_closest_to_pin(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
  v_event_competition_id bigint;
BEGIN
  -- resolve event_competition_id
  SELECT event_competition_id
  INTO v_event_competition_id
  FROM event_competition
  WHERE event_id = p_event_id
    AND type_code = 'CTP';

  INSERT INTO event_competition_result (
      event_competition_id,
      event_id,
      type_code,
      scope_type,
      scope_key,
      hole_number,
      player_id,
      metric_value,
      winner_flag,
      payout_amount,
      result_detail
  )
  SELECT
    v_event_competition_id,
    r.event_id,
    'CTP',
    'HOLE',
    r.flight_name,
    r.hole_number,
    r.player_id,
    r.distance_feet,
    TRUE,
    0,
    jsonb_build_object(
      'flight', r.flight_name,
      'hole', r.hole_number,
      'distance_feet', r.distance_feet,
      'notes', r.notes
    )
  FROM event_ctp_result r
  WHERE r.event_id = p_event_id;
END;
$$;


ALTER FUNCTION public.compute_closest_to_pin(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 284 (class 1255 OID 401408)
-- Name: compute_event_ledger(bigint, text); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_event_ledger(p_event_id bigint, p_posted_by text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  ec RECORD;
BEGIN
  -- delete derived rows only
  DELETE FROM player_ledger
  WHERE event_id = p_event_id;

  -- competition payouts
  FOR ec IN
    SELECT event_competition_id
    FROM event_competition
    WHERE event_id = p_event_id
  LOOP
    PERFORM ledger_from_event_competition(ec.event_competition_id);
  END LOOP;

  -- buy-ins
  PERFORM ledger_from_event_buyins(p_event_id);

  -- mark ledger as posted
  UPDATE event
  SET
    ledger_posted_at = now(),
    ledger_posted_by = p_posted_by,
	is_locked =  true
  WHERE event_id = p_event_id;
END;
$$;


ALTER FUNCTION public.compute_event_ledger(p_event_id bigint, p_posted_by text) OWNER TO lioneye;

--
-- TOC entry 306 (class 1255 OID 49208)
-- Name: compute_event_player_course_hcap(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_event_player_course_hcap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
    v_gender     text;

    slope        numeric;
    rating       numeric;
    total_par    numeric;

    slope_w      numeric;
    rating_w     numeric;
    total_par_w  numeric;
BEGIN
    IF TG_OP = 'INSERT'
       OR NEW.hcap_index IS DISTINCT FROM OLD.hcap_index
       OR NEW.tee_set_id IS DISTINCT FROM OLD.tee_set_id
    THEN
        -- Fetch player gender
        SELECT p.gender
        INTO v_gender
        FROM player p
        WHERE p.player_id = NEW.player_id;

        -- Fetch tee set data
        SELECT
            ts.slope,
            ts.rating,
            ts.total_par,
            ts.slope_women,
            ts.rating_women,
            ts.total_par_women
        INTO
            slope,
            rating,
            total_par,
            slope_w,
            rating_w,
            total_par_w
        FROM tee_set ts
        WHERE ts.tee_set_id = NEW.tee_set_id;

        -- Switch to women values if applicable
        IF v_gender = 'F' THEN
            slope     := slope_w;
            rating    := rating_w;
            total_par := total_par_w;
        END IF;

        -- Compute course handicap
        NEW.course_handicap :=
            ROUND(
                (NEW.hcap_index * slope) / 113
                + (rating - total_par),
                0
            );

        NEW.updated_at := now();
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.compute_event_player_course_hcap() OWNER TO lioneye;

--
-- TOC entry 295 (class 1255 OID 335873)
-- Name: compute_event_purse(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_event_purse(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_buy_in NUMERIC;
    v_player_count INTEGER;
BEGIN
    SELECT default_buy_in
      INTO v_buy_in
    FROM event
    WHERE event_id = p_event_id;

    IF v_buy_in IS NULL THEN
        RETURN;
    END IF;

    SELECT COUNT(*)
      INTO v_player_count
    FROM event_player
    WHERE event_id = p_event_id;

    UPDATE event
    SET total_purse = v_buy_in * v_player_count
    WHERE event_id = p_event_id;
END;
$$;


ALTER FUNCTION public.compute_event_purse(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 297 (class 1255 OID 335872)
-- Name: compute_event_results(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_event_results(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
BEGIN
    /*
     * Safety checks
     */
    IF NOT EXISTS (
        SELECT 1 FROM event WHERE event_id = p_event_id
    ) THEN
        RAISE EXCEPTION 'Event % does not exist', p_event_id;
    END IF;


	-- Sanity check: no missing competitions
	IF NOT EXISTS (
	  SELECT 1
	  FROM event_competition ec
	  LEFT JOIN event_competition_result r
	    ON r.event_id = ec.event_id
	   AND r.type_code = ec.type_code
	  WHERE ec.event_id = p_event_id
	) THEN
	  RAISE EXCEPTION
	    'Cannot finalize payouts: missing competition definitions for event %',
	    p_event_id;
	END IF;
	
    /*
     * Clear existing results (idempotent)
     */
    DELETE FROM event_competition_result
    WHERE event_id = p_event_id;

    /*
     * Run all competition engines for this event
     */
    FOR rec IN
        SELECT
            ct.type_code,
            ct.engine_function
        FROM event_competition ec
        JOIN competition_type ct
          ON ct.type_code = ec.type_code
        WHERE ec.event_id = p_event_id
          AND ct.engine_function IS NOT NULL
    LOOP
        EXECUTE format(
            'SELECT %I(%L)',
            rec.engine_function,
            p_event_id
        );
    END LOOP;

    /*
     * Manual competitions (CTP, etc.)
     *     These already write results via UI,
     *     so we just trust what's there
     */

    /*
     * Finalize payouts
     */
    PERFORM finalize_event_payouts(p_event_id);

END;
$$;


ALTER FUNCTION public.compute_event_results(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 319 (class 1255 OID 311296)
-- Name: compute_final_4_net(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_final_4_net(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
  v_event_competition_id bigint;
   v_rowcount integer;
BEGIN
  /* ---------------------------------------------
     Resolve competition id
  --------------------------------------------- */
  SELECT event_competition_id
  INTO v_event_competition_id
  FROM event_competition
  WHERE event_id = p_event_id
    AND type_code = 'FINAL_4_NET';

  /* ---------------------------------------------
     Insert FINAL_4_NET results
  --------------------------------------------- */
  INSERT INTO event_competition_result (
      event_competition_id,
      event_id,
      type_code,
      scope_type,
      scope_key,
      player_id,
      metric_value,
      winner_flag,
      win_share,
      payout_amount,
      result_detail
  )

  WITH base AS (
    SELECT
      event_id,
      flight_name,
      event_player_id,
      player_id,
      full_name,

      SUM(net_score) FILTER (WHERE hole_number BETWEEN 15 AND 18) AS net_15_18,
      SUM(net_score) FILTER (WHERE hole_number BETWEEN 16 AND 18) AS net_16_18,
      SUM(net_score) FILTER (WHERE hole_number BETWEEN 17 AND 18) AS net_17_18,
      MAX(net_score) FILTER (WHERE hole_number = 18)              AS net_18
    FROM v_player_hole_enriched_with_par_diff
    WHERE event_id = p_event_id
      AND hole_number BETWEEN 15 AND 18
      AND net_score IS NOT NULL
    GROUP BY
      event_id,
      flight_name,
      event_player_id,
      player_id,
      full_name
  ),

  ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY flight_name
      ORDER BY
        net_15_18,
        net_16_18,
        net_17_18,
        net_18
    ) AS rn,
    COUNT(*) OVER (
      PARTITION BY flight_name,
        net_15_18,
        net_16_18,
        net_17_18,
        net_18
    ) AS metric_tie_count
  FROM base
),
finalists AS (
  SELECT *
  FROM ranked
  WHERE rn = 1
),


  resolved AS (
    SELECT  * FROM finalists
  )

  SELECT
    v_event_competition_id,
    p_event_id,
    'FINAL_4_NET',
    'GROUP',
    flight_name,
    player_id,
    net_15_18                 AS metric_value,
    TRUE                      AS winner_flag,
    1.0 / metric_tie_count           AS win_share,       -- ✅ fractional win
    0                         AS payout_amount,   -- 🔑 allocated later
    jsonb_build_object(
      'net_15_18', net_15_18,
      'net_16_18', net_16_18,
      'net_17_18', net_17_18,
      'net_18',    net_18,
      'tie_level', CASE
                     WHEN metric_tie_count = 1 THEN 'outright'
                     ELSE 'split'
                   END,
      'tie_count', metric_tie_count
    )
  FROM resolved;

  GET DIAGNOSTICS v_rowcount = ROW_COUNT;
RAISE NOTICE 'FINAL_4_NET inserted % rows', v_rowcount;

END;
$$;


ALTER FUNCTION public.compute_final_4_net(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 305 (class 1255 OID 319488)
-- Name: compute_gross_skins(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_gross_skins(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
  v_event_competition_id bigint;
BEGIN
  -- resolve event_competition_id once
  SELECT event_competition_id
  INTO v_event_competition_id
  FROM event_competition
  WHERE event_id = p_event_id
    AND type_code = 'GROSS_SKINS';

  INSERT INTO event_competition_result (
      event_competition_id,
      event_id,
      type_code,
      scope_type,
      scope_key,
      hole_number,
      player_id,
      metric_value,
      winner_flag,
      payout_amount,
      result_detail
  )
  WITH hole_results AS (
    SELECT
      event_id,
      event_player_id,
      player_id,
      full_name,
      flight_name,
      hole_number,
      gross_score,
      gross_par_decode,

      MIN(gross_score) OVER (
        PARTITION BY event_id, flight_name, hole_number
      ) AS hole_low_score,

      COUNT(*) OVER (
        PARTITION BY event_id, flight_name, hole_number, gross_score
      ) AS score_count
    FROM v_player_hole_enriched_with_par_diff
    WHERE event_id = p_event_id
      AND gross_score IS NOT NULL
  )
  SELECT
    v_event_competition_id,
    p_event_id,
    'GROSS_SKINS',
    'HOLE',
    flight_name,
    hole_number,
    player_id,
    gross_score,
    TRUE,
    0,
    jsonb_build_object(
      'flight', flight_name,
      'hole', hole_number,
      'gross_score', gross_score,
      'par_result', gross_par_decode
    )
  FROM hole_results
  WHERE gross_score = hole_low_score
    AND score_count = 1;
END;
$$;


ALTER FUNCTION public.compute_gross_skins(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 314 (class 1255 OID 294912)
-- Name: compute_low_net(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_low_net(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
  v_event_competition_id bigint;
BEGIN
  -- resolve event_competition_id
  SELECT event_competition_id
  INTO v_event_competition_id
  FROM event_competition
  WHERE event_id = p_event_id
    AND type_code = 'LOW_NET';

  -- Clear prior LOW_NET results
  DELETE FROM event_competition_result
  WHERE event_id = p_event_id
    AND type_code = 'LOW_NET';

  WITH base AS (
    SELECT
      event_id,
      flight_name,
      event_player_id,

      SUM(net_score) FILTER (WHERE hole_number BETWEEN 1 AND 18)  AS net_18_total,
      SUM(net_score) FILTER (WHERE hole_number BETWEEN 10 AND 18) AS net_back_9,
      SUM(net_score) FILTER (WHERE hole_number BETWEEN 13 AND 18) AS net_13_18,
      SUM(net_score) FILTER (WHERE hole_number BETWEEN 16 AND 18) AS net_16_18,
      MAX(net_score) FILTER (WHERE hole_number = 18)              AS net_18

    FROM v_player_hole_enriched_with_par_diff
    WHERE event_id = p_event_id
      AND net_score IS NOT NULL
    GROUP BY
      event_id,
      flight_name,
      event_player_id
  ),

  s1 AS (
    SELECT *
    FROM base b
    WHERE net_18_total = (
      SELECT MIN(net_18_total)
      FROM base b2
      WHERE b2.flight_name = b.flight_name
    )
  ),

  s2 AS (
    SELECT *
    FROM s1 b
    WHERE net_back_9 = (
      SELECT MIN(net_back_9)
      FROM s1 b2
      WHERE b2.flight_name = b.flight_name
    )
  ),

  s3 AS (
    SELECT *
    FROM s2 b
    WHERE net_13_18 = (
      SELECT MIN(net_13_18)
      FROM s2 b2
      WHERE b2.flight_name = b.flight_name
    )
  ),

  s4 AS (
    SELECT *
    FROM s3 b
    WHERE net_16_18 = (
      SELECT MIN(net_16_18)
      FROM s3 b2
      WHERE b2.flight_name = b.flight_name
    )
  ),

  s5 AS (
    SELECT *
    FROM s4 b
    WHERE net_18 = (
      SELECT MIN(net_18)
      FROM s4 b2
      WHERE b2.flight_name = b.flight_name
    )
  ),

  final AS (
    SELECT
      *,
      COUNT(*) OVER (PARTITION BY flight_name) AS tie_count,
      CASE
        WHEN COUNT(*) OVER (PARTITION BY flight_name) = 1 THEN
          CASE
            WHEN (SELECT COUNT(*) FROM s1 WHERE s1.flight_name = s5.flight_name) = 1 THEN 'outright'
            WHEN (SELECT COUNT(*) FROM s2 WHERE s2.flight_name = s5.flight_name) = 1 THEN 'back_9'
            WHEN (SELECT COUNT(*) FROM s3 WHERE s3.flight_name = s5.flight_name) = 1 THEN '13–18'
            WHEN (SELECT COUNT(*) FROM s4 WHERE s4.flight_name = s5.flight_name) = 1 THEN '16–18'
            ELSE '18'
          END
        ELSE 'split'
      END AS tie_level
    FROM s5
  )

  INSERT INTO event_competition_result (
    event_competition_id,
    event_id,
    type_code,
    scope_type,
    scope_key,
    player_id,
    metric_value,
    winner_flag,
    win_share,
    payout_amount,
    result_detail
  )
  SELECT
    v_event_competition_id,
    p_event_id,
    'LOW_NET',
    'GROUP',
    f.flight_name,
    ep.player_id,
    f.net_18_total,
    TRUE,
    1.0 / f.tie_count,     -- 🔑 fractional ownership
    0,
    jsonb_build_object(
      'tie_level', f.tie_level,
      'tie_count', f.tie_count,
      'net_18_total', f.net_18_total,
      'net_back_9', f.net_back_9,
      'net_13_18', f.net_13_18,
      'net_16_18', f.net_16_18,
      'net_18', f.net_18
    )
  FROM final f
  JOIN event_player ep
    ON ep.event_player_id = f.event_player_id;

END;
$$;


ALTER FUNCTION public.compute_low_net(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 303 (class 1255 OID 327693)
-- Name: compute_net_skins(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_net_skins(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
  v_event_competition_id bigint;
BEGIN
  -- resolve event_competition_id
  SELECT event_competition_id
  INTO v_event_competition_id
  FROM event_competition
  WHERE event_id = p_event_id
    AND type_code = 'NET_SKINS';

  INSERT INTO event_competition_result (
      event_competition_id,
      event_id,
      type_code,
      scope_type,
      scope_key,
      hole_number,
      player_id,
      metric_value,
      winner_flag,
      payout_amount,
      result_detail
  )
  WITH hole_results AS (
    SELECT
      event_id,
      event_player_id,
      player_id,
      full_name,
      flight_name,
      hole_number,
      net_score,
      net_par_decode,

      MIN(net_score) OVER (
        PARTITION BY event_id, flight_name, hole_number
      ) AS hole_low_score,

      COUNT(*) OVER (
        PARTITION BY event_id, flight_name, hole_number, net_score
      ) AS score_count
    FROM v_player_hole_enriched_with_par_diff
    WHERE event_id = p_event_id
      AND net_score IS NOT NULL
  )
  SELECT
    v_event_competition_id,
    p_event_id,
    'NET_SKINS',
    'HOLE',
    flight_name,
    hole_number,
    player_id,
    net_score,
    TRUE,
    0,
    jsonb_build_object(
      'flight', flight_name,
      'hole', hole_number,
      'net_score', net_score,
      'par_result', net_par_decode
    )
  FROM hole_results
  WHERE net_score = hole_low_score
    AND score_count = 1;
END;
$$;


ALTER FUNCTION public.compute_net_skins(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 283 (class 1255 OID 401409)
-- Name: compute_results_and_ledger(bigint, text); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_results_and_ledger(p_event_id bigint, p_posted_by text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- 1. compute results (existing logic)
  PERFORM compute_event_results(p_event_id);

  -- 2. project money to ledger
  PERFORM compute_event_ledger(
    p_event_id,
    p_posted_by
  );
END;
$$;


ALTER FUNCTION public.compute_results_and_ledger(p_event_id bigint, p_posted_by text) OWNER TO lioneye;

--
-- TOC entry 287 (class 1255 OID 393216)
-- Name: compute_totals_for_tee_set(integer); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.compute_totals_for_tee_set(p_tee_set_id integer) RETURNS TABLE(total_yardage numeric, total_par numeric, total_par_women numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(hole_yardage)::numeric(4,0), 0),
        COALESCE(SUM(hole_par)::numeric(4,0), 0),
        COALESCE(SUM(hole_par_women)::numeric(4,0), 0)
    FROM hole
    WHERE tee_set_id = p_tee_set_id;
END;
$$;


ALTER FUNCTION public.compute_totals_for_tee_set(p_tee_set_id integer) OWNER TO lioneye;

--
-- TOC entry 300 (class 1255 OID 294913)
-- Name: finalize_event_payouts(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.finalize_event_payouts(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    v_buy_in           NUMERIC;
    v_flight           TEXT;
    v_flight_purse     NUMERIC;
    v_remaining_purse  NUMERIC;
    v_total_share      NUMERIC;
    rec                RECORD;
BEGIN
    -- Get event buy-in
    SELECT default_buy_in
      INTO v_buy_in
    FROM event
    WHERE event_id = p_event_id;

    IF v_buy_in IS NULL THEN
        RAISE EXCEPTION 'Event % has no default_buy_in', p_event_id;
    END IF;

    ------------------------------------------------------------------
    -- LOOP PER FLIGHT
    ------------------------------------------------------------------
    FOR v_flight IN
        SELECT DISTINCT flight_name
        FROM event_player
        WHERE event_id = p_event_id
    LOOP
        SELECT COUNT(*) * v_buy_in
          INTO v_flight_purse
        FROM event_player
        WHERE event_id = p_event_id
          AND flight_name = v_flight;

        v_remaining_purse := v_flight_purse;

        ------------------------------------------------------------------
        -- APPLY PURSE OVERRIDES (WIN_SHARE AWARE)
        ------------------------------------------------------------------
        FOR rec IN
            SELECT ec.type_code, ec.purse_override
            FROM event_competition ec
            WHERE ec.event_id = p_event_id
              AND ec.purse_override IS NOT NULL
        LOOP
            SELECT SUM(r.win_share)
              INTO v_total_share
            FROM event_competition_result r
            WHERE r.event_id = p_event_id
              AND r.scope_key = v_flight
              AND r.type_code = rec.type_code
              AND r.winner_flag = true;

            IF v_total_share > 0 THEN
                UPDATE event_competition_result r
                SET payout_amount =
                    rec.purse_override * r.win_share / v_total_share
                WHERE r.event_id = p_event_id
                  AND r.scope_key = v_flight
                  AND r.type_code = rec.type_code
                  AND r.winner_flag = true;

                v_remaining_purse := v_remaining_purse - rec.purse_override;
            END IF;
        END LOOP;

        ------------------------------------------------------------------
        -- DISTRIBUTE REMAINING PURSE (WIN_SHARE AWARE)
        ------------------------------------------------------------------
        SELECT SUM(r.win_share)
          INTO v_total_share
        FROM event_competition_result r
        JOIN event_competition ec
          ON ec.event_id = r.event_id
         AND ec.type_code = r.type_code
        WHERE r.event_id = p_event_id
          AND r.scope_key = v_flight
          AND r.winner_flag = true
          AND ec.purse_override IS NULL;

        IF v_total_share > 0 AND v_remaining_purse > 0 THEN
            UPDATE event_competition_result r
            SET payout_amount =
                v_remaining_purse * r.win_share / v_total_share
            FROM event_competition ec
            WHERE r.event_id = p_event_id
              AND r.scope_key = v_flight
              AND r.winner_flag = true
              AND ec.event_id = r.event_id
              AND ec.type_code = r.type_code
              AND ec.purse_override IS NULL;
        END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION public.finalize_event_payouts(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 316 (class 1255 OID 581632)
-- Name: get_course_manifest_json_by_event(integer, integer); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_course_manifest_json_by_event(p_event_id integer, p_schema_version integer DEFAULT 1) RETURNS jsonb
    LANGUAGE sql
    AS $$
WITH event_meta AS (
  SELECT
    e.event_id,
    e.event_name,
    lower(regexp_replace(e.event_name, '[^a-zA-Z0-9]+', '', 'g')) AS family
  FROM public.event e
  WHERE e.event_id = p_event_id
),

used_tees AS (
  SELECT DISTINCT
    ep.tee_set_id,
    ts.course_id,
    ts.tee_name
  FROM public.event_player ep
  JOIN public.tee_set ts
    ON ts.tee_set_id = ep.tee_set_id
  WHERE ep.event_id = p_event_id
    AND ep.tee_set_id IS NOT NULL
),

used_tee_set_ids AS (
  SELECT jsonb_agg(tee_set_id ORDER BY tee_set_id) AS ids
  FROM (SELECT DISTINCT tee_set_id FROM used_tees) x
),

course_base AS (
  SELECT
    c.course_id,
    c.course_name,
    c.abbreviation,
    c.city,
    c.state,

    ts.tee_set_id,
    ts.tee_name,

    h.hole_number,
    h.hole_par        AS hole_par_men,
    h.hole_par_women,
    h.hole_index_men,
    h.hole_index_women,
    h.hole_yardage
  FROM used_tees ut
  JOIN public.course c
    ON c.course_id = ut.course_id
  JOIN public.tee_set ts
    ON ts.tee_set_id = ut.tee_set_id            -- ✅ only tee sets used in event
  JOIN public.hole h
    ON h.tee_set_id = ts.tee_set_id
),

holes_by_tee AS (
  SELECT
    course_id,
    tee_set_id,
    tee_name,
    jsonb_object_agg(
      hole_number::text,
      jsonb_build_object(
        'par', jsonb_build_object(
          'men', hole_par_men,
          'women', hole_par_women
        ),
        'yardage', hole_yardage,
        'index', jsonb_build_object(
          'men', hole_index_men,
          'women', hole_index_women
        )
      )
      ORDER BY hole_number
    ) AS holes
  FROM course_base
  GROUP BY course_id, tee_set_id, tee_name
),

tee_sets_by_course AS (
  SELECT
    course_id,
    jsonb_object_agg(
      tee_set_id::text,
      jsonb_build_object(
        'tee_set_id', tee_set_id,
        'name', tee_name,
        'holes', holes
      )
      ORDER BY tee_set_id
    ) AS tee_sets
  FROM holes_by_tee
  GROUP BY course_id
),

courses_payload AS (
  SELECT
    c.course_id,
    jsonb_build_object(
      'course', jsonb_build_object(
        'course_id', c.course_id,
        'course_key', lower(regexp_replace(c.course_name, '[^a-zA-Z0-9]+', '-', 'g')),
        'name', c.course_name,
        'abbreviation', c.abbreviation,
        'location', jsonb_build_object(
          'city',  c.city,
          'state', c.state
        )
      ),
      'tee_sets', tbc.tee_sets
    ) AS course_obj
  FROM (
    SELECT DISTINCT
      course_id, course_name, abbreviation, city, state
    FROM course_base
  ) c
  JOIN tee_sets_by_course tbc
    ON tbc.course_id = c.course_id
)

SELECT jsonb_build_object(
  'meta', jsonb_build_object(
    'schema_version', p_schema_version,
    'generated_at', now() AT TIME ZONE 'utc',
    'event_id', p_event_id,
    'event_name', (SELECT event_name FROM event_meta),
    'family', (SELECT family FROM event_meta),
    'used_tee_set_ids', COALESCE((SELECT ids FROM used_tee_set_ids), '[]'::jsonb)
  ),

  /* If only one course is expected, you can still keep this as an array safely */
  'courses', COALESCE(
    (SELECT jsonb_agg(course_obj ORDER BY course_id) FROM courses_payload),
    '[]'::jsonb
  )
);
$$;


ALTER FUNCTION public.get_course_manifest_json_by_event(p_event_id integer, p_schema_version integer) OWNER TO lioneye;

--
-- TOC entry 317 (class 1255 OID 630786)
-- Name: get_event_handicap_report(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_event_handicap_report(p_event_id bigint) RETURNS TABLE(player_name text, transport_mode text, group_label text, tee_time text, hcap_index numeric, flight_name text, tee_handicaps jsonb)
    LANGUAGE sql STABLE
    AS $$
WITH event_ctx AS (
    SELECT
        e.course_id
    FROM event e
    WHERE e.event_id = p_event_id
),

players AS (
    SELECT
        ep.event_player_id,
        CONCAT(p.first_name, '  ', p.last_name) AS player_name,
        p.gender,
        initcap(ep.transport_mode)              AS transport_mode,
        ep.hcap_index,
        ep.flight_name,
        eg.group_label,
        to_char(eg.tee_time, 'FMHH12:MI AM')    AS tee_time
    FROM event_player ep
    JOIN player p
      ON p.player_id = ep.player_id
    LEFT JOIN event_group eg
      ON eg.group_id = ep.group_id
     AND eg.event_id = ep.event_id   -- critical constraint
    WHERE ep.event_id = p_event_id
),

handicaps AS (
    SELECT
        pl.event_player_id,
        jsonb_object_agg(
            ts.tee_name,
            ROUND(
                (
                    pl.hcap_index
                    * CASE
                        WHEN pl.gender = 'F'
                          THEN ts.slope_women
                          ELSE ts.slope
                      END
                ) / 113
                +
                (
                    CASE
                        WHEN pl.gender = 'F'
                          THEN ts.rating_women - ts.total_par_women
                          ELSE ts.rating - ts.total_par
                    END
                ),
                0
            )::int
            ORDER BY ts.tee_name
        ) AS tee_handicaps
    FROM players pl
    JOIN event_ctx ec
      ON true
    JOIN tee_set ts
      ON ts.course_id = ec.course_id and ts.show_in_reports = true
    GROUP BY pl.event_player_id
)

SELECT
    pl.player_name,
    pl.transport_mode,
    pl.group_label,
    pl.tee_time,
    pl.hcap_index,
    pl.flight_name,
    h.tee_handicaps
FROM players pl
JOIN handicaps h
  ON h.event_player_id = pl.event_player_id
ORDER BY
    pl.group_label,
    pl.tee_time,
    pl.player_name;
$$;


ALTER FUNCTION public.get_event_handicap_report(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 320 (class 1255 OID 581633)
-- Name: get_event_index_jsonb(text, integer); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_event_index_jsonb(p_family text, p_schema_version integer DEFAULT 1) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
WITH e AS (
  SELECT
    e.event_id,
    e.event_name,
    e.event_date,
    e.event_details,
    e.total_purse,
    e.default_buy_in,
    e.player_count,
    lower(regexp_replace(e.event_name, '[^a-zA-Z0-9]+', '', 'g')) AS family
  FROM public.event e
  WHERE e.is_locked = true
),
filtered AS (
  SELECT *
  FROM e
  WHERE family = lower(p_family)
)
SELECT jsonb_build_object(
  'meta', jsonb_build_object(
    'schema_version', p_schema_version,
    'generated_at', now() AT TIME ZONE 'utc',
    'family', lower(p_family),
    'event_count', (SELECT count(*) FROM filtered)
  ),
  'events', COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', event_id,
          'name', event_name,
          'date', event_date,
          'details', event_details,
          'player_count', player_count,
          'total_purse', total_purse,
          'default_buy_in', default_buy_in,
          'results_file', event_id::text || '.json',
          'course_file',  event_id::text || '.course.json'
        )
        ORDER BY event_date DESC, event_id DESC
      )
      FROM filtered
    ),
    '[]'::jsonb
  )
);
$$;


ALTER FUNCTION public.get_event_index_jsonb(p_family text, p_schema_version integer) OWNER TO lioneye;

--
-- TOC entry 315 (class 1255 OID 647169)
-- Name: get_event_month_index_jsonb(text, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_event_month_index_jsonb(p_family text, p_year integer, p_month integer, p_schema_version integer) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
WITH e AS (
  SELECT
    e.event_id,
    e.event_name,
    e.event_date,
    e.event_details,
    e.total_purse,
    e.default_buy_in,
    e.player_count,
    lower(regexp_replace(e.event_name, '[^a-zA-Z0-9]+', '', 'g')) AS family
  FROM public.event e
  WHERE e.is_locked = true
),
filtered AS (
  SELECT *
  FROM e
  WHERE
    family = lower(p_family)
    AND EXTRACT(YEAR  FROM event_date) = p_year
    AND EXTRACT(MONTH FROM event_date) = p_month
)
SELECT jsonb_build_object(
  'year', p_year,
  'month', LPAD(p_month::text, 2, '0'),
  'events', COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'event_id', event_id,
        'name', event_name,
        'date', event_date,
        'details', event_details,
        'player_count', player_count,
        'total_purse', total_purse,
        'default_buy_in', default_buy_in
      )
      ORDER BY event_date DESC, event_id DESC
    ),
    '[]'::jsonb
  ),
  'meta', jsonb_build_object(
    'schema_version', p_schema_version,
    'generated_at', now() AT TIME ZONE 'utc',
    'family', lower(p_family)
  )
)
FROM filtered;
$$;


ALTER FUNCTION public.get_event_month_index_jsonb(p_family text, p_year integer, p_month integer, p_schema_version integer) OWNER TO lioneye;

--
-- TOC entry 318 (class 1255 OID 557057)
-- Name: get_event_scorecard_json(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_event_scorecard_json(p_event_id bigint) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$WITH base AS (
  SELECT *
  FROM v_player_hole_enriched_with_par_diff
  WHERE event_id = p_event_id
),

/* ---------------------------------------------------
   Event-level meta 
--------------------------------------------------- */
event_meta AS (
  SELECT
    event_id,
    event_name,
    event_details,
    event_date,
    total_purse,
    default_buy_in,
    player_count
  FROM public.event
  WHERE event_id = p_event_id
),

/* ---------------------------------------------------
   Hole-level competition results (skins)
--------------------------------------------------- */
comp_hole_results AS (
  SELECT
    ecr.event_id,
    ecr.player_id,
    ecr.scope_key     AS flight_name,
    ecr.hole_number,

    jsonb_agg(
      jsonb_build_object(
        'type',       ecr.type_code,
        'name',       ct.comp_name,
        'value',      ecr.metric_value,
        'payout',     ecr.payout_amount,
        'win_share',  1.0,                    -- 🔑 skins never split

        'details',
          CASE
            WHEN ecr.type_code IN ('GROSS_SKINS', 'NET_SKINS')
              THEN ecr.result_detail ->> 'par_result'
            ELSE NULL
          END
      )
      ORDER BY ct.comp_name
    ) AS competitions

  FROM public.event_competition_result ecr
  JOIN competition_type ct
    ON ecr.type_code = ct.type_code

  WHERE ecr.event_id = p_event_id
    AND ecr.hole_number IS NOT NULL

  GROUP BY
    ecr.event_id,
    ecr.player_id,
    ecr.scope_key,
    ecr.hole_number
),

/* ---------------------------------------------------
   Round-level competition results (LOW_NET / FINAL_4_NET)
--------------------------------------------------- */
comp_round_results AS (
  SELECT
    ecr.event_id,
    ecr.player_id,
    ecr.scope_key AS flight_name,

    jsonb_agg(
      jsonb_build_object(
        'type',       ecr.type_code,
        'name',       ct.comp_name,
        'value',      ecr.metric_value,
        'payout',     ecr.payout_amount,
        'win_share',  ecr.win_share,           -- 🔑 fractional wins

        'details',
          CASE
            WHEN ecr.type_code IN ('LOW_NET', 'FINAL_4_NET')
              THEN 'Tie-break: ' || (ecr.result_detail ->> 'tie_level')
            ELSE NULL
          END
      )
      ORDER BY ct.comp_name
    ) AS round_competitions

  FROM public.event_competition_result ecr
  JOIN competition_type ct
    ON ecr.type_code = ct.type_code

  WHERE ecr.event_id = p_event_id
    AND ecr.hole_number IS NULL

  GROUP BY
    ecr.event_id,
    ecr.player_id,
    ecr.scope_key
),

/* ---------------------------------------------------
   Players with holes + competitions
--------------------------------------------------- */
players_with_holes AS (
  SELECT
    b.event_player_id,
    b.player_id,
    b.full_name,
    b.flight_name,
    b.gender,
    b.course_handicap,
    b.tee_name,

    ep.tee_set_id,

    r.gross_total,
    r.net_total,
    r.gross_rank,
    r.net_rank,
    r.gross_rank_label,
    r.net_rank_label,

    cr_round.round_competitions,

    jsonb_object_agg(
      b.hole_number::text,
      jsonb_build_object(
        'gross', b.gross_score,
        'net',   b.net_score,
        'par',   b.hole_par,

        'par_index', jsonb_build_object(
          'men',   b.hole_index_men,
          'women', b.hole_index_women
        ),

        'gross_result', b.gross_par_decode,
        'net_result',   b.net_par_decode,
        'gross_diff',   b.gross_par_diff,
        'net_diff',     b.net_par_diff,

        'competitions', cr_hole.competitions
      )
      ORDER BY b.hole_number
    ) AS holes

  FROM base b

  JOIN public.event_player ep
    ON ep.event_player_id = b.event_player_id

  JOIN v_event_player_rank_view r
    ON r.event_id = b.event_id
   AND r.event_player_id = b.event_player_id

  LEFT JOIN comp_hole_results cr_hole
    ON cr_hole.event_id    = b.event_id
   AND cr_hole.player_id   = b.player_id
   AND cr_hole.flight_name = b.flight_name
   AND cr_hole.hole_number = b.hole_number

  LEFT JOIN comp_round_results cr_round
    ON cr_round.event_id    = b.event_id
   AND cr_round.player_id   = b.player_id
   AND cr_round.flight_name = b.flight_name

  GROUP BY
    b.event_player_id,
    b.player_id,
    b.full_name,
    b.flight_name,
    b.gender,
    b.course_handicap,
    b.tee_name,
    ep.tee_set_id,

    r.gross_total,
    r.net_total,
    r.gross_rank,
    r.net_rank,
    r.gross_rank_label,
    r.net_rank_label,
    cr_round.round_competitions
)

/* ---------------------------------------------------
   Final JSON payload
--------------------------------------------------- */
SELECT jsonb_build_object(

  'meta', jsonb_build_object(
    'schema_version', 8,              -- 🔑 bumped
    'event_id',        em.event_id,
    'event_name',      em.event_name,
    'family',          lower(regexp_replace(em.event_name, '[^a-zA-Z0-9]+', '', 'g')),
    'event_details',   em.event_details,
    'event_date',      em.event_date,
    'total_purse',     em.total_purse,
    'default_buy_in',  em.default_buy_in,
    'player_count',    em.player_count,
    'generated_at',    now() AT TIME ZONE 'utc'
  ),

  'players', players.players_json

)
FROM event_meta em
CROSS JOIN LATERAL (
  SELECT jsonb_agg(
    jsonb_build_object(
      'event_player_id', p.event_player_id,
      'player_id',        p.player_id,
      'name',             p.full_name,
      'flight',           p.flight_name,
      'gender',           p.gender,

      'tee_set_id',       p.tee_set_id,
      'tee_name',         p.tee_name,

      'course_handicap',  p.course_handicap,

      'gross_total',      p.gross_total,
      'net_total',        p.net_total,

      'gross_rank',       p.gross_rank,
      'net_rank',         p.net_rank,
      'gross_rank_label', p.gross_rank_label,
      'net_rank_label',   p.net_rank_label,

      'round_competitions', p.round_competitions,
      'holes', p.holes
    )
    ORDER BY
      p.flight_name,
      p.gross_rank,
      p.full_name
  ) AS players_json
  FROM players_with_holes p
) players;
$$;


ALTER FUNCTION public.get_event_scorecard_json(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 298 (class 1255 OID 114694)
-- Name: get_event_standings_with_skins(integer, text); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_event_standings_with_skins(p_event_id integer, p_score_type text) RETURNS TABLE(event_id integer, event_player_id integer, full_name text, flight_name text, course_handicap integer, "1" integer, "2" integer, "3" integer, "4" integer, "5" integer, "6" integer, "7" integer, "8" integer, "9" integer, "OUT" integer, "10" integer, "11" integer, "12" integer, "13" integer, "14" integer, "15" integer, "16" integer, "17" integer, "18" integer, "IN" integer, "TOTAL" integer, skins_won integer, skin_holes jsonb, low_net_total integer, is_low_net_winner boolean, final_four_total integer, is_final_four_winner boolean, tee_set_id integer, tee_name text)
    LANGUAGE sql STABLE
    AS $$
WITH hole_results AS (
  SELECT
    event_id,
    event_player_id,
    full_name,
    flight_name,
    course_handicap,
    hole_number,

    CASE
      WHEN lower(p_score_type) = 'gross' THEN gross_score
      ELSE net_score
    END AS score,

    CASE
      WHEN lower(p_score_type) = 'gross' THEN gross_par_decode
      ELSE net_par_decode
    END AS par_decode,

    net_score,
    tee_set_id,
    tee_name,

    MIN(
      CASE
        WHEN lower(p_score_type) = 'gross' THEN gross_score
        ELSE net_score
      END
    ) OVER (PARTITION BY event_id, flight_name, hole_number) AS hole_low_score,

    COUNT(*) OVER (
      PARTITION BY event_id, flight_name, hole_number,
      CASE
        WHEN lower(p_score_type) = 'gross' THEN gross_score
        ELSE net_score
      END
    ) AS score_count
  FROM v_player_hole_enriched_with_par_diff
  WHERE event_id = p_event_id
),

per_player AS (
  SELECT
    event_id,
    event_player_id,
    full_name,
    flight_name,
    tee_set_id,
    tee_name,
    course_handicap,

    SUM(net_score)                               AS low_net_total,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 10 AND 18) AS ln_back9,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 13 AND 18) AS ln_13_18,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 16 AND 18) AS ln_16_18,
    MAX(net_score) FILTER (WHERE hole_number = 18)              AS ln_18,

    SUM(net_score) FILTER (WHERE hole_number BETWEEN 15 AND 18) AS ff_15_18,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 16 AND 18) AS ff_16_18,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 17 AND 18) AS ff_17_18,
    MAX(net_score) FILTER (WHERE hole_number = 18)              AS ff_18

  FROM hole_results
  GROUP BY
    event_id,
    event_player_id,
    full_name,
    flight_name,
    tee_set_id,
    tee_name,
    course_handicap
),

ranked AS (
  SELECT
    p.*,

    DENSE_RANK() OVER (
      PARTITION BY event_id, flight_name
      ORDER BY
        low_net_total,
        ln_back9,
        ln_13_18,
        ln_16_18,
        ln_18,
        event_player_id
    ) AS low_net_rank,

    DENSE_RANK() OVER (
      PARTITION BY event_id, flight_name
      ORDER BY
        ff_15_18,
        ff_16_18,
        ff_17_18,
        ff_18,
        event_player_id
    ) AS final_four_rank
  FROM per_player p
)

SELECT
  hr.event_id,
  hr.event_player_id,
  hr.full_name,
  hr.flight_name,
  hr.course_handicap,

  MAX(score) FILTER (WHERE hole_number = 1)  AS "1",
  MAX(score) FILTER (WHERE hole_number = 2)  AS "2",
  MAX(score) FILTER (WHERE hole_number = 3)  AS "3",
  MAX(score) FILTER (WHERE hole_number = 4)  AS "4",
  MAX(score) FILTER (WHERE hole_number = 5)  AS "5",
  MAX(score) FILTER (WHERE hole_number = 6)  AS "6",
  MAX(score) FILTER (WHERE hole_number = 7)  AS "7",
  MAX(score) FILTER (WHERE hole_number = 8)  AS "8",
  MAX(score) FILTER (WHERE hole_number = 9)  AS "9",

  SUM(score) FILTER (WHERE hole_number BETWEEN 1 AND 9) AS "OUT",

  MAX(score) FILTER (WHERE hole_number = 10) AS "10",
  MAX(score) FILTER (WHERE hole_number = 11) AS "11",
  MAX(score) FILTER (WHERE hole_number = 12) AS "12",
  MAX(score) FILTER (WHERE hole_number = 13) AS "13",
  MAX(score) FILTER (WHERE hole_number = 14) AS "14",
  MAX(score) FILTER (WHERE hole_number = 15) AS "15",
  MAX(score) FILTER (WHERE hole_number = 16) AS "16",
  MAX(score) FILTER (WHERE hole_number = 17) AS "17",
  MAX(score) FILTER (WHERE hole_number = 18) AS "18",

  SUM(score) FILTER (WHERE hole_number BETWEEN 10 AND 18) AS "IN",
  SUM(score) AS "TOTAL",

  COUNT(*) FILTER (
    WHERE score = hole_low_score AND score_count = 1
  ) AS skins_won,

  jsonb_agg(
    jsonb_build_object(
      'hole', hole_number,
      'score', score,
      'par_result', par_decode
    )
    ORDER BY hole_number
  ) FILTER (
    WHERE score = hole_low_score AND score_count = 1
  ) AS skin_holes,

  r.low_net_total,
  (r.low_net_rank = 1) AS is_low_net_winner,

  r.ff_15_18 AS final_four_total,
  (r.final_four_rank = 1) AS is_final_four_winner,

  r.tee_set_id,
  r.tee_name

FROM hole_results hr
JOIN ranked r
  ON r.event_id = hr.event_id
 AND r.event_player_id = hr.event_player_id

GROUP BY
  hr.event_id,
  hr.event_player_id,
  hr.full_name,
  hr.flight_name,
  hr.course_handicap,
  r.low_net_total,
  r.low_net_rank,
  r.ff_15_18,
  r.final_four_rank,
  r.tee_set_id,
  r.tee_name

ORDER BY "TOTAL";
$$;


ALTER FUNCTION public.get_event_standings_with_skins(p_event_id integer, p_score_type text) OWNER TO lioneye;

--
-- TOC entry 321 (class 1255 OID 647168)
-- Name: get_family_event_index_jsonb(text, integer); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_family_event_index_jsonb(p_family text, p_schema_version integer DEFAULT 2) RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$WITH e AS (
  SELECT
    e.event_id,
    e.event_date,
    lower(regexp_replace(e.event_name, '[^a-zA-Z0-9]+', '', 'g')) AS family
  FROM public.event e
  WHERE e.is_locked = true
),
filtered AS (
  SELECT *
  FROM e
  WHERE family = lower(p_family)
),
latest AS (
  SELECT
    event_id,
    EXTRACT(YEAR  FROM event_date)::int                AS year,
    LPAD(EXTRACT(MONTH FROM event_date)::text, 2, '0') AS month
  FROM filtered
  ORDER BY event_date DESC, event_id DESC
  LIMIT 1
),
months AS (
  SELECT DISTINCT
    EXTRACT(YEAR  FROM event_date)::int                AS year,
    LPAD(EXTRACT(MONTH FROM event_date)::text, 2, '0') AS month
  FROM filtered
),
months_json AS (
  SELECT jsonb_object_agg(
    (year::text || '-' || month),
    jsonb_build_object(
      'year', year,
      'month', month,
      'path', format('events/%s/%s/index.json', year, month)
    )
    ORDER BY (year::text || '-' || month)
  ) AS months
  FROM months
)
SELECT jsonb_build_object(
  'family', lower(p_family),

  'latest', jsonb_build_object(
    'year', l.year,
    'month', l.month,
    'event_id', l.event_id
  ),

  'months', COALESCE(mj.months, '{}'::jsonb),

  'meta', jsonb_build_object(
    'schema_version', p_schema_version,
    'generated_at', now() AT TIME ZONE 'utc'
  )
)
FROM latest l
CROSS JOIN months_json mj;
$$;


ALTER FUNCTION public.get_family_event_index_jsonb(p_family text, p_schema_version integer) OWNER TO lioneye;

--
-- TOC entry 277 (class 1255 OID 106497)
-- Name: get_final_four_net_winners(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_final_four_net_winners(p_event_id bigint) RETURNS TABLE(flight_name text, event_player_id bigint, full_name text, net_15_18 integer, net_16_18 integer, net_17_18 integer, net_18 integer, is_winner boolean, tie_level text)
    LANGUAGE sql
    AS $$
WITH base AS (
  SELECT
    event_id,
    flight_name,
    event_player_id,
    full_name,

    SUM(net_score) FILTER (WHERE hole_number BETWEEN 15 AND 18) AS net_15_18,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 16 AND 18) AS net_16_18,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 17 AND 18) AS net_17_18,
    MAX(net_score) FILTER (WHERE hole_number = 18)              AS net_18

  FROM v_player_hole_enriched_with_par_diff
  WHERE event_id = p_event_id
    AND hole_number BETWEEN 15 AND 18
    AND net_score IS NOT NULL
  GROUP BY
    event_id,
    flight_name,
    event_player_id,
    full_name
),

ranked AS (
  SELECT
    *,
    DENSE_RANK() OVER (PARTITION BY flight_name ORDER BY net_15_18) AS r15_18,
    DENSE_RANK() OVER (PARTITION BY flight_name ORDER BY net_16_18) AS r16_18,
    DENSE_RANK() OVER (PARTITION BY flight_name ORDER BY net_17_18) AS r17_18,
    DENSE_RANK() OVER (PARTITION BY flight_name ORDER BY net_18)    AS r18
  FROM base
),

resolved AS (
  SELECT
    *,
    CASE
      WHEN r15_18 = 1 AND COUNT(*) FILTER (WHERE r15_18 = 1)
           OVER (PARTITION BY flight_name) = 1 THEN '15–18'
      WHEN r15_18 = 1 AND r16_18 = 1 AND COUNT(*) FILTER (WHERE r15_18 = 1 AND r16_18 = 1)
           OVER (PARTITION BY flight_name) = 1 THEN '16–18'
      WHEN r15_18 = 1 AND r16_18 = 1 AND r17_18 = 1 AND COUNT(*) FILTER (WHERE r15_18 = 1 AND r16_18 = 1 AND r17_18 = 1)
           OVER (PARTITION BY flight_name) = 1 THEN '17–18'
      WHEN r15_18 = 1 AND r16_18 = 1 AND r17_18 = 1 AND r18 = 1 THEN '18'
      ELSE 'split'
    END AS tie_level
  FROM ranked
)

SELECT
  flight_name,
  event_player_id,
  full_name,
  net_15_18,
  net_16_18,
  net_17_18,
  net_18,
  tie_level <> 'split' OR (
    tie_level = 'split'
    AND r15_18 = 1
    AND r16_18 = 1
    AND r17_18 = 1
    AND r18 = 1
  ) AS is_winner,
  tie_level
FROM resolved
WHERE
  r15_18 = 1
  AND (tie_level <> 'split' OR r18 = 1)
ORDER BY flight_name, full_name;
$$;


ALTER FUNCTION public.get_final_four_net_winners(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 278 (class 1255 OID 106500)
-- Name: get_low_net_total_winners(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.get_low_net_total_winners(p_event_id bigint) RETURNS TABLE(flight_name text, event_player_id bigint, full_name text, net_18_total integer, net_back_9 integer, net_13_18 integer, net_16_18 integer, net_18 integer, is_winner boolean, tie_level text)
    LANGUAGE sql
    AS $$
WITH base AS (
  SELECT
    event_id,
    flight_name,
    event_player_id,
    full_name,

    SUM(net_score) FILTER (WHERE hole_number BETWEEN 1 AND 18)  AS net_18_total,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 10 AND 18) AS net_back_9,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 13 AND 18) AS net_13_18,
    SUM(net_score) FILTER (WHERE hole_number BETWEEN 16 AND 18) AS net_16_18,
    MAX(net_score) FILTER (WHERE hole_number = 18)              AS net_18

  FROM v_player_hole_enriched_with_par_diff
  WHERE event_id = p_event_id
    AND net_score IS NOT NULL
  GROUP BY
    event_id,
    flight_name,
    event_player_id,
    full_name
),

-- STEP 1: lowest hole 18
s1 AS (
  SELECT *
  FROM base
  WHERE net_18_total = (
    SELECT MIN(net_18_total)
    FROM base b2
    WHERE b2.flight_name = base.flight_name
  )
),
-- STEP 2: lowest back 9
s2 AS (
  SELECT *
  FROM s1
  WHERE net_back_9 = (
    SELECT MIN(net_back_9)
    FROM s1 s
    WHERE s.flight_name = s1.flight_name
  )
),

-- STEP 3: lowest 13–18 (only if needed)
s3 AS (
  SELECT *
  FROM s2
  WHERE net_13_18 = (
    SELECT MIN(net_13_18)
    FROM s2 s
    WHERE s.flight_name = s2.flight_name
  )
),

-- STEP 4: lowest 16–18
s4 AS (
  SELECT *
  FROM s3
  WHERE net_16_18 = (
    SELECT MIN(net_16_18)
    FROM s3 s
    WHERE s.flight_name = s3.flight_name
  )
),
-- STEP 5: lowest 18th hole
s5 AS (
  SELECT *
  FROM s4
  WHERE net_18 = (
    SELECT MIN(net_18)
    FROM s4 s
    WHERE s.flight_name = s4.flight_name
  )
),



final AS (
  SELECT
    *,
    CASE
      WHEN COUNT(*) OVER (PARTITION BY flight_name) = 1 THEN
        CASE
          WHEN (SELECT COUNT(*) FROM s1  WHERE s1.flight_name  = s5.flight_name) = 1 THEN 'low_total_net'
          WHEN (SELECT COUNT(*) FROM s2  WHERE s2.flight_name  = s5.flight_name) = 1 THEN 'back_9'
          WHEN (SELECT COUNT(*) FROM s3  WHERE s3.flight_name  = s5.flight_name) = 1 THEN '13–18'
          WHEN (SELECT COUNT(*) FROM s4  WHERE s4.flight_name  = s5.flight_name) = 1 THEN '16–18'
          ELSE '18'
        END
      ELSE 'split'
    END AS tie_level
  FROM s5
)

SELECT
  flight_name,
  event_player_id,
  full_name,

  net_18_total,
  net_back_9,
  net_13_18,
  net_16_18,
  net_18,

  TRUE AS is_winner,
  tie_level
FROM final
ORDER BY flight_name, full_name;
$$;


ALTER FUNCTION public.get_low_net_total_winners(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 301 (class 1255 OID 376833)
-- Name: ledger_from_event_buyins(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.ledger_from_event_buyins(p_event_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_buyin numeric;
BEGIN
  SELECT default_buy_in
  INTO v_buyin
  FROM event
  WHERE event_id = p_event_id;

  IF v_buyin IS NULL OR v_buyin = 0 THEN
    RETURN;
  END IF;

  INSERT INTO player_ledger (
    event_id,
    player_id,
    source_type,
    event_competition_id,
    amount,
    memo,
	created_by
  )
  SELECT
    p_event_id,
    ep.player_id,
    'buyin',
    NULL,
    -v_buyin,
    'Event buy-in',
	'system'
  FROM event_player ep
  WHERE ep.event_id = p_event_id;
END;
$$;


ALTER FUNCTION public.ledger_from_event_buyins(p_event_id bigint) OWNER TO lioneye;

--
-- TOC entry 307 (class 1255 OID 376832)
-- Name: ledger_from_event_competition(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.ledger_from_event_competition(p_event_competition_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO player_ledger (
    event_id,
    player_id,
    source_type,
    event_competition_id,
    amount,
    memo,
	created_by
  )
  SELECT
    ecr.event_id,
    ecr.player_id,
    ecr.type_code,
    ecr.event_competition_id,
    ecr.payout_amount,
    CASE
      WHEN ecr.scope_type = 'HOLE'
        THEN format('%s – Hole %s - Flight %s', ecr.type_code, ecr.result_detail->>'hole', ecr.scope_key)
      WHEN ecr.scope_type = 'GROUP'
        THEN format('%s – Flight %s', ecr.type_code, ecr.scope_key)
      ELSE
        ecr.type_code || ' payout'
    END,
	'system'
  FROM event_competition_result ecr
  WHERE ecr.event_competition_id = p_event_competition_id;
END;
$$;


ALTER FUNCTION public.ledger_from_event_competition(p_event_competition_id bigint) OWNER TO lioneye;

--
-- TOC entry 313 (class 1255 OID 532480)
-- Name: ledger_from_manual_post(bigint, numeric, bigint, text, text); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.ledger_from_manual_post(p_player_id bigint, p_amount numeric, p_event_id bigint DEFAULT NULL::bigint, p_memo text DEFAULT NULL::text, p_created_by text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Guardrail: zero-dollar entries are not allowed
    IF p_amount = 0 THEN
        RAISE EXCEPTION 'Ledger amount cannot be zero';
    END IF;

    INSERT INTO player_ledger (
        player_id,
        source_type,
        event_id,
        amount,
        memo,
        created_by
    )
    VALUES (
        p_player_id,
        'manual',
        p_event_id,
        p_amount,
        p_memo,
        p_created_by
    );
END;
$$;


ALTER FUNCTION public.ledger_from_manual_post(p_player_id bigint, p_amount numeric, p_event_id bigint, p_memo text, p_created_by text) OWNER TO lioneye;

--
-- TOC entry 299 (class 1255 OID 262190)
-- Name: manage_event_competitions(bigint, text[], smallint[]); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.manage_event_competitions(p_event_id bigint, p_type_codes text[], p_ctp_holes smallint[] DEFAULT NULL::smallint[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- ============================================
    -- 1. Remove unselected competitions
    -- ============================================
    DELETE FROM event_competition
    WHERE event_id = p_event_id
      AND type_code NOT IN (
        SELECT unnest(p_type_codes)
      );

    -- ============================================
    -- 2. Insert selected competitions
    -- ============================================
    INSERT INTO event_competition (event_id, type_code)
    SELECT
        p_event_id,
        unnest(p_type_codes)
    ON CONFLICT (event_id, type_code) DO NOTHING;

    -- ============================================
    -- 3. Handle CTP hole configuration
    -- ============================================
    IF 'CTP' = ANY (p_type_codes) THEN

        -- Remove existing CTP holes
        DELETE FROM competition_hole
        WHERE event_id = p_event_id
          AND type_code = 'CTP';

        -- Insert selected holes
        INSERT INTO competition_hole (
            event_id,
            type_code,
            hole_number
        )
        SELECT
            p_event_id,
            'CTP',
            unnest(p_ctp_holes);

    ELSE
        -- CTP removed entirely → clean up holes
        DELETE FROM competition_hole
        WHERE event_id = p_event_id
          AND type_code = 'CTP';
    END IF;

END;
$$;


ALTER FUNCTION public.manage_event_competitions(p_event_id bigint, p_type_codes text[], p_ctp_holes smallint[]) OWNER TO lioneye;

--
-- TOC entry 280 (class 1255 OID 221191)
-- Name: prevent_event_delete_when_ledger_posted(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.prevent_event_delete_when_ledger_posted() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.ledger_posted_at IS NOT NULL THEN
    RAISE EXCEPTION
      'Event % cannot be deleted: ledger was posted at % by %',
      OLD.event_id,
      OLD.ledger_posted_at,
      COALESCE(OLD.ledger_posted_by, 'unknown')
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  RETURN OLD;
END;
$$;


ALTER FUNCTION public.prevent_event_delete_when_ledger_posted() OWNER TO lioneye;

--
-- TOC entry 289 (class 1255 OID 81921)
-- Name: recalc_event_player_strokes(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.recalc_event_player_strokes(p_event_player_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tee_set BIGINT;
    v_course_handicap INT;
    v_is_men BOOLEAN := TRUE;
    v_strokes INT;
    v_extra_strokes INT;
    v_hole_idx INT;
BEGIN
    SELECT tee_set_id, course_handicap
    INTO v_tee_set, v_course_handicap
    FROM event_player
    WHERE event_player_id = p_event_player_id;

    v_strokes := FLOOR((v_course_handicap - 1) / 18);
    v_extra_strokes := ((v_course_handicap - 1) % 18) + 1;

    UPDATE event_player_hole eph
    SET strokes_received = v_strokes +
        CASE
            WHEN (
               (v_is_men AND h.hole_index_men <= v_extra_strokes)
               OR (NOT v_is_men AND h.hole_index_women <= v_extra_strokes)
            )
            THEN 1 ELSE 0
        END
    FROM hole h
    WHERE eph.event_player_id = p_event_player_id
      AND h.tee_set_id = v_tee_set
      AND h.hole_number = eph.hole_number;
END;
$$;


ALTER FUNCTION public.recalc_event_player_strokes(p_event_player_id bigint) OWNER TO lioneye;

--
-- TOC entry 308 (class 1255 OID 483328)
-- Name: recalculate_event_player_strokes(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.recalculate_event_player_strokes(p_event_player_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_tee_set BIGINT;
  v_course_handicap INT;
  v_gender TEXT;
  v_base INT;
  v_extra INT;
  v_receives BOOLEAN;
BEGIN
  -- Fetch authoritative context
  SELECT
    ep.tee_set_id,
    ep.course_handicap,
    p.gender
  INTO
    v_tee_set,
    v_course_handicap,
    v_gender
  FROM event_player ep
  JOIN player p
    ON p.player_id = ep.player_id
  WHERE ep.event_player_id = p_event_player_id;

  IF v_tee_set IS NULL THEN
    RAISE EXCEPTION 'Invalid event_player_id %', p_event_player_id;
  END IF;

  v_receives := v_course_handicap >= 0;

  v_base  := FLOOR((ABS(v_course_handicap) - 1) / 18);
  v_extra := ((ABS(v_course_handicap) - 1) % 18) + 1;

  UPDATE event_player_hole eph
  SET strokes_received =
    CASE
      WHEN v_receives THEN
        v_base +
        CASE
          WHEN v_gender = 'M'
               AND h.hole_index_men <= v_extra THEN 1
          WHEN v_gender <> 'M'
               AND h.hole_index_women <= v_extra THEN 1
          ELSE 0
        END
      ELSE
        -(v_base +
          CASE
            WHEN v_gender = 'M'
                 AND h.hole_index_men >= (19 - v_extra) THEN 1
            WHEN v_gender <> 'M'
                 AND h.hole_index_women >= (19 - v_extra) THEN 1
            ELSE 0
          END)
    END
  FROM hole h
  WHERE eph.event_player_id = p_event_player_id
    AND h.hole_number = eph.hole_number
    AND h.tee_set_id  = v_tee_set;
END;
$$;


ALTER FUNCTION public.recalculate_event_player_strokes(p_event_player_id bigint) OWNER TO lioneye;

--
-- TOC entry 291 (class 1255 OID 81920)
-- Name: seed_event_player_holes(bigint); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.seed_event_player_holes(p_event_player_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    v_tee_set BIGINT;
    v_course_handicap INT;
    v_gender TEXT;
    v_base INT;
    v_extra INT;
    v_threshold INT;
BEGIN
    -- Lazy-seed guard
    IF EXISTS (
        SELECT 1
        FROM event_player_hole
        WHERE event_player_id = p_event_player_id
    ) THEN
        RETURN;
    END IF;

    SELECT
        ep.tee_set_id,
        ep.course_handicap,
        p.gender
    INTO
        v_tee_set,
        v_course_handicap,
        v_gender
    FROM event_player ep
    JOIN player p ON p.player_id = ep.player_id
    WHERE ep.event_player_id = p_event_player_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'event_player_id % not found', p_event_player_id;
    END IF;

    v_gender := UPPER(COALESCE(v_gender, 'M'));

    IF v_course_handicap > 0 THEN
        v_base  := FLOOR((v_course_handicap - 1) / 18);
        v_extra := ((v_course_handicap - 1) % 18) + 1;

        INSERT INTO event_player_hole (event_player_id, hole_number, strokes_received)
        SELECT
            p_event_player_id,
            h.hole_number,
            v_base +
            CASE
                WHEN v_gender = 'M' AND h.hole_index_men <= v_extra THEN 1
                WHEN v_gender <> 'M' AND h.hole_index_women <= v_extra THEN 1
                ELSE 0
            END
        FROM hole h
        WHERE h.tee_set_id = v_tee_set
        ORDER BY h.hole_number;

    ELSE
        v_course_handicap := ABS(v_course_handicap);
        v_base  := FLOOR((v_course_handicap - 1) / 18);
        v_extra := ((v_course_handicap - 1) % 18) + 1;
        v_threshold := 19 - v_extra;

        INSERT INTO event_player_hole (event_player_id, hole_number, strokes_received)
        SELECT
            p_event_player_id,
            h.hole_number,
            -(v_base +
              CASE
                WHEN v_gender = 'M' AND h.hole_index_men >= v_threshold THEN 1
                WHEN v_gender <> 'M' AND h.hole_index_women >= v_threshold THEN 1
                ELSE 0
              END)
        FROM hole h
        WHERE h.tee_set_id = v_tee_set
        ORDER BY h.hole_number;
    END IF;
END;
$$;


ALTER FUNCTION public.seed_event_player_holes(p_event_player_id bigint) OWNER TO lioneye;

--
-- TOC entry 281 (class 1255 OID 245763)
-- Name: sync_ctp_payload(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.sync_ctp_payload() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.hole_number IS NOT NULL THEN
    NEW.payload =
      coalesce(NEW.payload, '{}'::jsonb)
      || jsonb_build_object(
           'hole_number', NEW.hole_number,
           'flight_name', NEW.flight_name
         );
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.sync_ctp_payload() OWNER TO lioneye;

--
-- TOC entry 285 (class 1255 OID 507904)
-- Name: trg_ctp_append_previous_player(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_ctp_append_previous_player() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  player_rank integer;
BEGIN
  /*
    Rank is based on created_at DESC
    Count how many existing rows are newer than this one
  */
  SELECT COUNT(*) + 1
  INTO player_rank
  FROM public."CTP_Winner_Temp"
  WHERE flight_name = NEW.flight_name
    AND created_at > NEW.created_at;

  -- Append "rank. player_name" to array
  NEW.previous_players :=
    COALESCE(NEW.previous_players, ARRAY[]::text[])
    || (player_rank::text || '. ' || NEW.player_name);

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_ctp_append_previous_player() OWNER TO lioneye;

--
-- TOC entry 286 (class 1255 OID 507906)
-- Name: trg_ctp_build_previous_players(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_ctp_build_previous_players() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE public."CTP_Winner_Temp" t
  SET previous_players = (
    SELECT array_agg(
      (row_number() OVER (ORDER BY created_at DESC))::text
      || '. '
      || player_name
      ORDER BY created_at DESC
    )
    FROM public."CTP_Winner_Temp"
    WHERE flight_name = NEW.flight_name
  )
  WHERE t.ctp_winner_id = NEW.ctp_winner_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_ctp_build_previous_players() OWNER TO lioneye;

--
-- TOC entry 309 (class 1255 OID 507968)
-- Name: trg_ctp_init_previous_players(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_ctp_init_previous_players() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Only initialize if empty
  IF NEW.previous_players IS NULL THEN
    NEW.previous_players := ARRAY['1. ' || NEW.player_name];
  END IF;

  NEW.created_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_ctp_init_previous_players() OWNER TO lioneye;

--
-- TOC entry 311 (class 1255 OID 507919)
-- Name: trg_ctp_merge_previous_players(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_ctp_merge_previous_players() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  existing_players text[];
  cleaned_players  text[];
  rebuilt_players  text[];
  p text;
  rank integer := 1;
BEGIN
  -- Fetch existing row for SAME flight + hole
  SELECT previous_players
  INTO existing_players
  FROM public."CTP_Winner_Temp"
  WHERE flight_name = NEW.flight_name
    AND hole_number = NEW.hole_number;

  IF FOUND THEN
    -- Remove duplicate of incoming player
    cleaned_players := ARRAY[]::text[];

    FOREACH p IN ARRAY existing_players LOOP
      IF regexp_replace(p, '^\d+\.\s*', '') <> NEW.player_name THEN
        cleaned_players := cleaned_players || p;
      END IF;
    END LOOP;

    -- Rebuild ranked history (most recent first)
    rebuilt_players := ARRAY['1. ' || NEW.player_name];

    FOREACH p IN ARRAY cleaned_players LOOP
      rebuilt_players :=
        rebuilt_players || ((rank + 1)::text || '. ' || regexp_replace(p, '^\d+\.\s*', ''));
      rank := rank + 1;
    END LOOP;

    UPDATE public."CTP_Winner_Temp"
    SET
      player_name      = NEW.player_name,
      distance         = NEW.distance,
      created_at       = now(),
      previous_players = rebuilt_players
    WHERE flight_name = NEW.flight_name
      AND hole_number = NEW.hole_number;

    RETURN NULL; -- cancel INSERT, we updated instead
  END IF;

  -- First-ever insert for this flight + hole
  NEW.previous_players := ARRAY['1. ' || NEW.player_name];
  NEW.created_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_ctp_merge_previous_players() OWNER TO lioneye;

--
-- TOC entry 310 (class 1255 OID 507976)
-- Name: trg_ctp_public_form_upsert(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_ctp_public_form_upsert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  existing_id bigint;
BEGIN
  SELECT ctp_winner_id
  INTO existing_id
  FROM public."CTP_Winner_Temp"
  WHERE flight_name = NEW.flight_name
    AND hole_number = NEW.hole_number;

  IF FOUND THEN
    UPDATE public."CTP_Winner_Temp"
    SET
      player_name = NEW.player_name,
      distance    = NEW.distance,
      created_at  = now()
    WHERE ctp_winner_id = existing_id;

    -- cancel insert
    RETURN NULL;
  END IF;

  -- first-ever insert
  NEW.created_at := now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_ctp_public_form_upsert() OWNER TO lioneye;

--
-- TOC entry 296 (class 1255 OID 507912)
-- Name: trg_ctp_replace_keep_history(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_ctp_replace_keep_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  old_players text[];
  rebuilt_players text[];
  idx integer := 1;
BEGIN
  /*
   * Step 1: Fetch existing previous_players (if any)
   */
  SELECT previous_players
  INTO old_players
  FROM public."CTP_Winner_Temp"
  WHERE flight_name = NEW.flight_name
  ORDER BY created_at DESC
  LIMIT 1;

  /*
   * Step 2: Start new array with current player ranked #1
   */
  rebuilt_players := ARRAY[
    '1. ' || NEW.player_name
  ];

  /*
   * Step 3: Append old players, re-ranked
   */
  IF old_players IS NOT NULL THEN
    FOREACH idx IN ARRAY generate_series(1, array_length(old_players, 1)) LOOP
      rebuilt_players := rebuilt_players
        || regexp_replace(old_players[idx], '^\d+\.\s*', (idx + 1) || '. ');
    END LOOP;
  END IF;

  /*
   * Step 4: Remove old rows
   */
  DELETE FROM public."CTP_Winner_Temp"
  WHERE flight_name = NEW.flight_name;

  /*
   * Step 5: Assign merged history
   */
  NEW.previous_players := rebuilt_players;
  NEW.created_at := now();

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_ctp_replace_keep_history() OWNER TO lioneye;

--
-- TOC entry 312 (class 1255 OID 507950)
-- Name: trg_ctp_update_previous_players(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_ctp_update_previous_players() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  existing_players text[];
  cleaned_players  text[];
  rebuilt_players  text[];
  p text;
  rank integer := 1;
BEGIN
  -- Only run if player_name actually changed
  IF NEW.player_name = OLD.player_name THEN
    RETURN NEW;
  END IF;

  existing_players := COALESCE(OLD.previous_players, ARRAY[]::text[]);

  -- Remove duplicate of incoming player
  cleaned_players := ARRAY[]::text[];
  FOREACH p IN ARRAY existing_players LOOP
    IF regexp_replace(p, '^\d+\.\s*', '') <> NEW.player_name THEN
      cleaned_players := cleaned_players || p;
    END IF;
  END LOOP;

  -- Rebuild ranked list
  rebuilt_players := ARRAY['1. ' || NEW.player_name];

  FOREACH p IN ARRAY cleaned_players LOOP
    rebuilt_players :=
      rebuilt_players || ((rank + 1)::text || '. ' || regexp_replace(p, '^\d+\.\s*', ''));
    rank := rank + 1;
  END LOOP;

  NEW.previous_players := rebuilt_players;
  NEW.created_at := now();

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_ctp_update_previous_players() OWNER TO lioneye;

--
-- TOC entry 293 (class 1255 OID 335876)
-- Name: trg_event_player_added(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_event_player_added() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM compute_event_purse(NEW.event_id);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_event_player_added() OWNER TO lioneye;

--
-- TOC entry 290 (class 1255 OID 81924)
-- Name: trg_event_player_after_update(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_event_player_after_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (NEW.tee_set_id <> OLD.tee_set_id
        OR NEW.course_handicap <> OLD.course_handicap)
    THEN
        PERFORM recalc_event_player_strokes(NEW.event_player_id);
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_event_player_after_update() OWNER TO lioneye;

--
-- TOC entry 294 (class 1255 OID 335878)
-- Name: trg_event_player_removed(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_event_player_removed() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM compute_event_purse(OLD.event_id);
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.trg_event_player_removed() OWNER TO lioneye;

--
-- TOC entry 292 (class 1255 OID 335874)
-- Name: trg_event_recompute_purse(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_event_recompute_purse() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.default_buy_in IS DISTINCT FROM OLD.default_buy_in THEN
        PERFORM compute_event_purse(NEW.event_id);
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_event_recompute_purse() OWNER TO lioneye;

--
-- TOC entry 282 (class 1255 OID 49155)
-- Name: trg_update_tee_set_totals(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.trg_update_tee_set_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    t_yard numeric;
    t_par  numeric;
	t_par_women numeric;
    tid    int;
BEGIN
    -- Determine the correct tee_set_id (for INSERT, UPDATE, DELETE)
    tid := COALESCE(NEW.tee_set_id, OLD.tee_set_id);

    -- Compute both totals
    SELECT total_yardage, total_par, total_par_women
    INTO t_yard, t_par, t_par_women
    FROM compute_totals_for_tee_set(tid);

    -- Update tee_set with both totals
    UPDATE tee_set
    SET 
        total_yardage = t_yard,
        total_par     = t_par,
		total_par_women     = t_par_women
    WHERE tee_set_id = tid;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_update_tee_set_totals() OWNER TO lioneye;

--
-- TOC entry 275 (class 1255 OID 49185)
-- Name: update_event_player_stats(); Type: FUNCTION; Schema: public; Owner: lioneye
--

CREATE FUNCTION public.update_event_player_stats() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    eid bigint;
    p_count integer;
    e_purse numeric;
    default_buy numeric;
BEGIN
    -- Determine event_id from NEW or OLD (INSERT/UPDATE/DELETE)
    eid := COALESCE(NEW.event_id, OLD.event_id);

    -- Get the event's default buy-in (constant for purse calc)
    SELECT default_buy_in
    INTO default_buy
    FROM event
    WHERE event_id = eid;

    -- Get live player count
    SELECT COUNT(*)
    INTO p_count
    FROM event_player
    WHERE event_id = eid;

    -- Compute purse from live data
    e_purse := default_buy * p_count;

    -- Update both fields at once
    UPDATE event
    SET 
        player_count = p_count,
        total_purse  = e_purse,
        updated_at = now()
    WHERE event_id = eid;

    -- Return correct row
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION public.update_event_player_stats() OWNER TO lioneye;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 261 (class 1259 OID 491521)
-- Name: CTP_Winner_Temp; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public."CTP_Winner_Temp" (
    ctp_winner_id bigint NOT NULL,
    flight_name text NOT NULL,
    player_name text NOT NULL,
    distance text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    hole_number integer
);


ALTER TABLE public."CTP_Winner_Temp" OWNER TO lioneye;

--
-- TOC entry 260 (class 1259 OID 491520)
-- Name: CTP_Winner_Temp_ctp_winner_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public."CTP_Winner_Temp_ctp_winner_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."CTP_Winner_Temp_ctp_winner_id_seq" OWNER TO lioneye;

--
-- TOC entry 3666 (class 0 OID 0)
-- Dependencies: 260
-- Name: CTP_Winner_Temp_ctp_winner_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public."CTP_Winner_Temp_ctp_winner_id_seq" OWNED BY public."CTP_Winner_Temp".ctp_winner_id;


--
-- TOC entry 252 (class 1259 OID 262168)
-- Name: competition_hole; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.competition_hole (
    competition_hole_id bigint NOT NULL,
    event_id bigint NOT NULL,
    type_code text NOT NULL,
    hole_number smallint NOT NULL,
    purse_amount numeric(10,2),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT competition_hole_hole_number_check CHECK (((hole_number >= 1) AND (hole_number <= 18)))
);


ALTER TABLE public.competition_hole OWNER TO lioneye;

--
-- TOC entry 251 (class 1259 OID 262167)
-- Name: competition_hole_competition_hole_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.competition_hole_competition_hole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.competition_hole_competition_hole_id_seq OWNER TO lioneye;

--
-- TOC entry 3669 (class 0 OID 0)
-- Dependencies: 251
-- Name: competition_hole_competition_hole_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.competition_hole_competition_hole_id_seq OWNED BY public.competition_hole.competition_hole_id;


--
-- TOC entry 229 (class 1259 OID 40987)
-- Name: competition_type; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.competition_type (
    type_code text NOT NULL,
    input_mode public.competition_input_mode NOT NULL,
    engine_function text NOT NULL,
    scope public.competition_type_scope,
    comp_name text
);


ALTER TABLE public.competition_type OWNER TO lioneye;

--
-- TOC entry 230 (class 1259 OID 40992)
-- Name: course; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.course (
    course_id bigint NOT NULL,
    course_name text NOT NULL,
    address text,
    city text,
    state text,
    phone text,
    zip text,
    updated_at timestamp without time zone DEFAULT '2025-11-27 19:30:02.386893'::timestamp without time zone,
    abbreviation text
);


ALTER TABLE public.course OWNER TO lioneye;

--
-- TOC entry 231 (class 1259 OID 40998)
-- Name: course_course_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.course_course_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_course_id_seq OWNER TO lioneye;

--
-- TOC entry 3673 (class 0 OID 0)
-- Dependencies: 231
-- Name: course_course_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.course_course_id_seq OWNED BY public.course.course_id;


--
-- TOC entry 232 (class 1259 OID 40999)
-- Name: event; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.event (
    event_id bigint NOT NULL,
    event_name text NOT NULL,
    event_details text,
    event_date date NOT NULL,
    course_id bigint NOT NULL,
    status text DEFAULT 'DRAFT'::text NOT NULL,
    total_purse numeric(10,2),
    default_buy_in numeric(10,2) DEFAULT 30.00 NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    player_count numeric(4,0) DEFAULT 0,
    ledger_posted_at timestamp with time zone,
    ledger_posted_by text,
    is_locked boolean DEFAULT false NOT NULL
);


ALTER TABLE public.event OWNER TO lioneye;

--
-- TOC entry 250 (class 1259 OID 262145)
-- Name: event_competition; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.event_competition (
    event_competition_id bigint NOT NULL,
    event_id bigint NOT NULL,
    type_code text NOT NULL,
    purse_override numeric(10,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.event_competition OWNER TO lioneye;

--
-- TOC entry 249 (class 1259 OID 262144)
-- Name: event_competition_event_competition_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.event_competition_event_competition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_competition_event_competition_id_seq OWNER TO lioneye;

--
-- TOC entry 3677 (class 0 OID 0)
-- Dependencies: 249
-- Name: event_competition_event_competition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.event_competition_event_competition_id_seq OWNED BY public.event_competition.event_competition_id;


--
-- TOC entry 255 (class 1259 OID 286721)
-- Name: event_competition_result; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.event_competition_result (
    event_competition_result_id bigint NOT NULL,
    event_id bigint NOT NULL,
    type_code text NOT NULL,
    scope_type text NOT NULL,
    scope_key text NOT NULL,
    player_id bigint NOT NULL,
    metric_value numeric NOT NULL,
    winner_flag boolean DEFAULT true NOT NULL,
    payout_amount numeric NOT NULL,
    result_detail jsonb,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    hole_number smallint,
    event_competition_id bigint,
    win_share numeric DEFAULT 1 NOT NULL,
    CONSTRAINT chk_hole_scope_requires_hole CHECK ((((scope_type = 'HOLE'::text) AND (hole_number IS NOT NULL)) OR ((scope_type <> 'HOLE'::text) AND (hole_number IS NULL)))),
    CONSTRAINT chk_scope_type CHECK ((scope_type = ANY (ARRAY['EVENT'::text, 'GROUP'::text, 'HOLE'::text]))),
    CONSTRAINT event_competition_result_payout_amount_check CHECK ((payout_amount >= (0)::numeric))
);


ALTER TABLE public.event_competition_result OWNER TO lioneye;

--
-- TOC entry 254 (class 1259 OID 286720)
-- Name: event_competition_result_event_competition_result_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.event_competition_result_event_competition_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_competition_result_event_competition_result_id_seq OWNER TO lioneye;

--
-- TOC entry 3680 (class 0 OID 0)
-- Dependencies: 254
-- Name: event_competition_result_event_competition_result_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.event_competition_result_event_competition_result_id_seq OWNED BY public.event_competition_result.event_competition_result_id;


--
-- TOC entry 253 (class 1259 OID 270362)
-- Name: event_ctp_result; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.event_ctp_result (
    event_id bigint NOT NULL,
    flight_name text NOT NULL,
    hole_number integer NOT NULL,
    player_id bigint NOT NULL,
    distance_feet numeric(6,2),
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.event_ctp_result OWNER TO lioneye;

--
-- TOC entry 233 (class 1259 OID 41007)
-- Name: event_event_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.event_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_event_id_seq OWNER TO lioneye;

--
-- TOC entry 3683 (class 0 OID 0)
-- Dependencies: 233
-- Name: event_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.event_event_id_seq OWNED BY public.event.event_id;


--
-- TOC entry 234 (class 1259 OID 41008)
-- Name: event_group; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.event_group (
    group_id bigint NOT NULL,
    event_id bigint NOT NULL,
    group_label text,
    tee_time time without time zone,
    starting_hole smallint
);


ALTER TABLE public.event_group OWNER TO lioneye;

--
-- TOC entry 235 (class 1259 OID 41013)
-- Name: event_group_group_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.event_group_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_group_group_id_seq OWNER TO lioneye;

--
-- TOC entry 3686 (class 0 OID 0)
-- Dependencies: 235
-- Name: event_group_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.event_group_group_id_seq OWNED BY public.event_group.group_id;


--
-- TOC entry 236 (class 1259 OID 41014)
-- Name: event_player; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.event_player (
    event_player_id bigint NOT NULL,
    event_id bigint NOT NULL,
    player_id bigint NOT NULL,
    tee_set_id bigint NOT NULL,
    hcap_index numeric(4,1),
    course_handicap numeric(4,0),
    group_id bigint,
    status text DEFAULT 'ACTIVE'::text NOT NULL,
    buy_in_amount numeric(10,2),
    host_player_id bigint,
    updated_at timestamp with time zone DEFAULT '2025-12-04 18:01:08.701722+00'::timestamp with time zone,
    flight_name text,
    transport_mode text,
    CONSTRAINT event_player_transport_mode_check CHECK ((transport_mode = ANY (ARRAY['walk'::text, 'ride'::text])))
);


ALTER TABLE public.event_player OWNER TO lioneye;

--
-- TOC entry 237 (class 1259 OID 41021)
-- Name: event_player_event_player_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.event_player_event_player_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_player_event_player_id_seq OWNER TO lioneye;

--
-- TOC entry 3689 (class 0 OID 0)
-- Dependencies: 237
-- Name: event_player_event_player_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.event_player_event_player_id_seq OWNED BY public.event_player.event_player_id;


--
-- TOC entry 247 (class 1259 OID 73728)
-- Name: event_player_hole; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.event_player_hole (
    event_player_id bigint NOT NULL,
    hole_number smallint NOT NULL,
    gross_score smallint,
    net_score smallint,
    strokes_received smallint DEFAULT 0 NOT NULL,
    notes text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT event_player_hole_hole_number_check CHECK (((hole_number >= 1) AND (hole_number <= 18)))
);


ALTER TABLE public.event_player_hole OWNER TO lioneye;

--
-- TOC entry 238 (class 1259 OID 41031)
-- Name: hole; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.hole (
    tee_set_id bigint NOT NULL,
    hole_number integer NOT NULL,
    hole_par integer,
    hole_yardage integer,
    hole_index_men integer,
    hole_index_women integer,
    hole_par_women integer,
    CONSTRAINT chk_hole_number_range CHECK (((hole_number >= 1) AND (hole_number <= 18))),
    CONSTRAINT chk_hole_par_range CHECK (((hole_par >= 3) AND (hole_par <= 6)))
);


ALTER TABLE public.hole OWNER TO lioneye;

--
-- TOC entry 239 (class 1259 OID 41042)
-- Name: player; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.player (
    player_id bigint NOT NULL,
    email text,
    ghin_number bigint,
    hcap_index numeric(4,1),
    is_guest boolean DEFAULT false,
    public_token text,
    phone text,
    updated_at timestamp with time zone DEFAULT '2025-11-27 13:53:48.418379+00'::timestamp with time zone,
    gender character(1) DEFAULT 'M'::bpchar,
    notes text,
    first_name text NOT NULL,
    last_name text NOT NULL,
    full_name text GENERATED ALWAYS AS (((last_name || ', '::text) || first_name)) STORED,
    default_tee_set_id bigint,
    CONSTRAINT player_gender_check CHECK ((gender = ANY (ARRAY['M'::bpchar, 'F'::bpchar])))
);


ALTER TABLE public.player OWNER TO lioneye;

--
-- TOC entry 258 (class 1259 OID 360449)
-- Name: player_ledger; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.player_ledger (
    player_ledger_id bigint NOT NULL,
    event_id bigint,
    player_id bigint NOT NULL,
    source_type text NOT NULL,
    event_competition_id bigint,
    amount numeric(10,2) NOT NULL,
    memo text,
    computed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text
);


ALTER TABLE public.player_ledger OWNER TO lioneye;

--
-- TOC entry 257 (class 1259 OID 360448)
-- Name: player_ledger_player_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.player_ledger_player_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.player_ledger_player_ledger_id_seq OWNER TO lioneye;

--
-- TOC entry 3695 (class 0 OID 0)
-- Dependencies: 257
-- Name: player_ledger_player_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.player_ledger_player_ledger_id_seq OWNED BY public.player_ledger.player_ledger_id;


--
-- TOC entry 240 (class 1259 OID 41057)
-- Name: player_player_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.player_player_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.player_player_id_seq OWNER TO lioneye;

--
-- TOC entry 3697 (class 0 OID 0)
-- Dependencies: 240
-- Name: player_player_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.player_player_id_seq OWNED BY public.player.player_id;


--
-- TOC entry 241 (class 1259 OID 41058)
-- Name: team; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.team (
    team_id bigint NOT NULL,
    event_id bigint NOT NULL,
    team_name text NOT NULL
);


ALTER TABLE public.team OWNER TO lioneye;

--
-- TOC entry 242 (class 1259 OID 41063)
-- Name: team_member; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.team_member (
    team_id bigint NOT NULL,
    event_player_id bigint NOT NULL
);


ALTER TABLE public.team_member OWNER TO lioneye;

--
-- TOC entry 243 (class 1259 OID 41066)
-- Name: team_team_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.team_team_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.team_team_id_seq OWNER TO lioneye;

--
-- TOC entry 3701 (class 0 OID 0)
-- Dependencies: 243
-- Name: team_team_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.team_team_id_seq OWNED BY public.team.team_id;


--
-- TOC entry 244 (class 1259 OID 41067)
-- Name: tee_set; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.tee_set (
    tee_set_id bigint NOT NULL,
    course_id bigint NOT NULL,
    tee_name text NOT NULL,
    rating numeric(4,1),
    slope numeric(5,1),
    total_yardage numeric(4,0),
    total_par numeric(4,0),
    rating_women numeric(4,1),
    slope_women numeric(5,1),
    total_par_women numeric(4,0),
    show_in_reports boolean DEFAULT true
);


ALTER TABLE public.tee_set OWNER TO lioneye;

--
-- TOC entry 245 (class 1259 OID 41072)
-- Name: tee_set_tee_set_id_seq; Type: SEQUENCE; Schema: public; Owner: lioneye
--

CREATE SEQUENCE public.tee_set_tee_set_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tee_set_tee_set_id_seq OWNER TO lioneye;

--
-- TOC entry 3704 (class 0 OID 0)
-- Dependencies: 245
-- Name: tee_set_tee_set_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: lioneye
--

ALTER SEQUENCE public.tee_set_tee_set_id_seq OWNED BY public.tee_set.tee_set_id;


--
-- TOC entry 246 (class 1259 OID 41073)
-- Name: tee_set_tee_set_id_seq1; Type: SEQUENCE; Schema: public; Owner: lioneye
--

ALTER TABLE public.tee_set ALTER COLUMN tee_set_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tee_set_tee_set_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 263 (class 1259 OID 598016)
-- Name: v_event_competition_id; Type: TABLE; Schema: public; Owner: lioneye
--

CREATE TABLE public.v_event_competition_id (
    event_competition_id bigint
);


ALTER TABLE public.v_event_competition_id OWNER TO lioneye;

--
-- TOC entry 259 (class 1259 OID 475136)
-- Name: v_player_hole_enriched_with_par_diff; Type: VIEW; Schema: public; Owner: lioneye
--

CREATE VIEW public.v_player_hole_enriched_with_par_diff AS
 SELECT ep.event_id,
    eph.event_player_id,
    ep.player_id,
    concat(p.first_name, ' ', p.last_name) AS full_name,
    ts.tee_set_id,
    ts.tee_name,
    ep.course_handicap,
    ep.flight_name,
    h.hole_number,
    h.hole_par,
    h.hole_index_men,
    h.hole_index_women,
    eph.gross_score,
    eph.net_score,
    (eph.gross_score - h.hole_par) AS gross_par_diff,
    (
        CASE
            WHEN ((eph.gross_score - h.hole_par) = '-3'::integer) THEN 'ALBATROSS'::text
            WHEN ((eph.gross_score - h.hole_par) = '-2'::integer) THEN 'EAGLE'::text
            WHEN ((eph.gross_score - h.hole_par) = '-1'::integer) THEN 'BIRDIE'::text
            WHEN ((eph.gross_score - h.hole_par) = 0) THEN 'PAR'::text
            WHEN ((eph.gross_score - h.hole_par) = 1) THEN 'BOGEY'::text
            WHEN ((eph.gross_score - h.hole_par) = 2) THEN 'DBL BOGEY'::text
            WHEN ((eph.gross_score - h.hole_par) = 3) THEN 'TRPL BOGEY'::text
            WHEN ((eph.gross_score - h.hole_par) > 3) THEN 'OTHER'::text
            ELSE '?'::text
        END ||
        CASE
            WHEN (eph.gross_score = 1) THEN ' (HOLE IN ONE!)'::text
            ELSE ''::text
        END) AS gross_par_decode,
    (eph.net_score - h.hole_par) AS net_par_diff,
        CASE
            WHEN ((eph.net_score - h.hole_par) = '-3'::integer) THEN 'ALBATROSS'::text
            WHEN ((eph.net_score - h.hole_par) = '-2'::integer) THEN 'EAGLE'::text
            WHEN ((eph.net_score - h.hole_par) = '-1'::integer) THEN 'BIRDIE'::text
            WHEN ((eph.net_score - h.hole_par) = 0) THEN 'PAR'::text
            WHEN ((eph.net_score - h.hole_par) = 1) THEN 'BOGEY'::text
            WHEN ((eph.net_score - h.hole_par) = 2) THEN 'DBL BOGEY'::text
            WHEN ((eph.net_score - h.hole_par) = 3) THEN 'TRPL BOGEY'::text
            WHEN ((eph.net_score - h.hole_par) > 3) THEN 'OTHER'::text
            ELSE '?'::text
        END AS net_par_decode,
    p.gender
   FROM (((((public.event_player_hole eph
     JOIN public.event_player ep ON ((ep.event_player_id = eph.event_player_id)))
     JOIN public.player p ON ((p.player_id = ep.player_id)))
     JOIN public.event e ON ((e.event_id = ep.event_id)))
     JOIN public.tee_set ts ON ((ts.tee_set_id = ep.tee_set_id)))
     JOIN public.hole h ON (((h.tee_set_id = ts.tee_set_id) AND (h.hole_number = eph.hole_number))));


ALTER VIEW public.v_player_hole_enriched_with_par_diff OWNER TO lioneye;

--
-- TOC entry 262 (class 1259 OID 548864)
-- Name: v_event_player_rank_view; Type: VIEW; Schema: public; Owner: lioneye
--

CREATE VIEW public.v_event_player_rank_view AS
 WITH base AS (
         SELECT v_player_hole_enriched_with_par_diff.event_id,
            v_player_hole_enriched_with_par_diff.event_player_id,
            v_player_hole_enriched_with_par_diff.flight_name,
            v_player_hole_enriched_with_par_diff.gross_score,
            v_player_hole_enriched_with_par_diff.net_score
           FROM public.v_player_hole_enriched_with_par_diff
        ), totals AS (
         SELECT base.event_id,
            base.event_player_id,
            base.flight_name,
            sum(base.gross_score) AS gross_total,
            sum(base.net_score) AS net_total
           FROM base
          GROUP BY base.event_id, base.event_player_id, base.flight_name
        ), ranks AS (
         SELECT totals.event_id,
            totals.event_player_id,
            totals.flight_name,
            totals.gross_total,
            totals.net_total,
            rank() OVER (PARTITION BY totals.event_id, totals.flight_name ORDER BY totals.gross_total) AS gross_rank,
            rank() OVER (PARTITION BY totals.event_id, totals.flight_name ORDER BY totals.net_total) AS net_rank
           FROM totals
        )
 SELECT event_id,
    event_player_id,
    flight_name,
    gross_total,
    net_total,
    gross_rank,
    net_rank,
        CASE
            WHEN (count(*) OVER (PARTITION BY event_id, flight_name, gross_rank) > 1) THEN ('T'::text || gross_rank)
            ELSE (gross_rank)::text
        END AS gross_rank_label,
        CASE
            WHEN (count(*) OVER (PARTITION BY event_id, flight_name, net_rank) > 1) THEN ('T'::text || net_rank)
            ELSE (net_rank)::text
        END AS net_rank_label
   FROM ranks;


ALTER VIEW public.v_event_player_rank_view OWNER TO lioneye;

--
-- TOC entry 256 (class 1259 OID 303104)
-- Name: v_event_winner_summary; Type: VIEW; Schema: public; Owner: lioneye
--

CREATE VIEW public.v_event_winner_summary AS
 SELECT r.event_id,
    ep.flight_name,
    r.player_id,
    p.full_name,
    sum(r.payout_amount) AS total_winnings,
    jsonb_agg(jsonb_build_object('competition_code', r.type_code, 'competition_name', ct.comp_name, 'scope_type', r.scope_type, 'scope_key', r.scope_key, 'metric_value', r.metric_value, 'payout_amount', r.payout_amount, 'detail', r.result_detail) ORDER BY r.payout_amount DESC) AS wins
   FROM (((public.event_competition_result r
     JOIN public.event_player ep ON (((ep.event_id = r.event_id) AND (ep.player_id = r.player_id))))
     JOIN public.player p ON ((p.player_id = r.player_id)))
     JOIN public.competition_type ct ON ((ct.type_code = r.type_code)))
  WHERE (r.winner_flag = true)
  GROUP BY r.event_id, ep.flight_name, r.player_id, p.full_name;


ALTER VIEW public.v_event_winner_summary OWNER TO lioneye;

--
-- TOC entry 248 (class 1259 OID 73743)
-- Name: v_player_hole_enriched; Type: VIEW; Schema: public; Owner: lioneye
--

CREATE VIEW public.v_player_hole_enriched AS
 SELECT ep.event_player_id,
    eph.hole_number,
    h.hole_par,
    h.hole_yardage,
    h.hole_index_men,
    h.hole_index_women,
    eph.gross_score,
    eph.net_score,
    eph.strokes_received,
    eph.updated_at,
    ep.tee_set_id,
    ts.tee_name,
    ep.event_id,
    ep.player_id
   FROM (((public.event_player_hole eph
     JOIN public.event_player ep ON ((eph.event_player_id = ep.event_player_id)))
     JOIN public.tee_set ts ON ((ep.tee_set_id = ts.tee_set_id)))
     JOIN public.hole h ON (((h.tee_set_id = ts.tee_set_id) AND (h.hole_number = eph.hole_number))))
  ORDER BY ep.event_player_id, eph.hole_number;


ALTER VIEW public.v_player_hole_enriched OWNER TO lioneye;

--
-- TOC entry 3406 (class 2604 OID 491524)
-- Name: CTP_Winner_Temp ctp_winner_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public."CTP_Winner_Temp" ALTER COLUMN ctp_winner_id SET DEFAULT nextval('public."CTP_Winner_Temp_ctp_winner_id_seq"'::regclass);


--
-- TOC entry 3395 (class 2604 OID 262171)
-- Name: competition_hole competition_hole_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.competition_hole ALTER COLUMN competition_hole_id SET DEFAULT nextval('public.competition_hole_competition_hole_id_seq'::regclass);


--
-- TOC entry 3373 (class 2604 OID 41095)
-- Name: course course_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.course ALTER COLUMN course_id SET DEFAULT nextval('public.course_course_id_seq'::regclass);


--
-- TOC entry 3375 (class 2604 OID 41096)
-- Name: event event_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event ALTER COLUMN event_id SET DEFAULT nextval('public.event_event_id_seq'::regclass);


--
-- TOC entry 3393 (class 2604 OID 262148)
-- Name: event_competition event_competition_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition ALTER COLUMN event_competition_id SET DEFAULT nextval('public.event_competition_event_competition_id_seq'::regclass);


--
-- TOC entry 3399 (class 2604 OID 286724)
-- Name: event_competition_result event_competition_result_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition_result ALTER COLUMN event_competition_result_id SET DEFAULT nextval('public.event_competition_result_event_competition_result_id_seq'::regclass);


--
-- TOC entry 3381 (class 2604 OID 41098)
-- Name: event_player event_player_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player ALTER COLUMN event_player_id SET DEFAULT nextval('public.event_player_event_player_id_seq'::regclass);


--
-- TOC entry 3384 (class 2604 OID 41101)
-- Name: player player_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player ALTER COLUMN player_id SET DEFAULT nextval('public.player_player_id_seq'::regclass);


--
-- TOC entry 3403 (class 2604 OID 360452)
-- Name: player_ledger player_ledger_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player_ledger ALTER COLUMN player_ledger_id SET DEFAULT nextval('public.player_ledger_player_ledger_id_seq'::regclass);


--
-- TOC entry 3389 (class 2604 OID 41102)
-- Name: team team_id; Type: DEFAULT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.team ALTER COLUMN team_id SET DEFAULT nextval('public.team_team_id_seq'::regclass);


--
-- TOC entry 3473 (class 2606 OID 491528)
-- Name: CTP_Winner_Temp CTP_Winner_Temp_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public."CTP_Winner_Temp"
    ADD CONSTRAINT "CTP_Winner_Temp_pkey" PRIMARY KEY (ctp_winner_id);


--
-- TOC entry 3454 (class 2606 OID 262177)
-- Name: competition_hole competition_hole_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.competition_hole
    ADD CONSTRAINT competition_hole_pkey PRIMARY KEY (competition_hole_id);


--
-- TOC entry 3418 (class 2606 OID 41110)
-- Name: competition_type competition_type_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.competition_type
    ADD CONSTRAINT competition_type_pkey PRIMARY KEY (type_code);


--
-- TOC entry 3420 (class 2606 OID 41112)
-- Name: course course_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_pkey PRIMARY KEY (course_id);


--
-- TOC entry 3450 (class 2606 OID 262153)
-- Name: event_competition event_competition_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition
    ADD CONSTRAINT event_competition_pkey PRIMARY KEY (event_competition_id);


--
-- TOC entry 3460 (class 2606 OID 286732)
-- Name: event_competition_result event_competition_result_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition_result
    ADD CONSTRAINT event_competition_result_pkey PRIMARY KEY (event_competition_result_id);


--
-- TOC entry 3458 (class 2606 OID 270370)
-- Name: event_ctp_result event_ctp_result_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_ctp_result
    ADD CONSTRAINT event_ctp_result_pkey PRIMARY KEY (event_id, flight_name, hole_number);


--
-- TOC entry 3424 (class 2606 OID 65544)
-- Name: event_group event_group_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_group
    ADD CONSTRAINT event_group_pkey PRIMARY KEY (event_id, group_id);


--
-- TOC entry 3422 (class 2606 OID 41116)
-- Name: event event_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (event_id);


--
-- TOC entry 3443 (class 2606 OID 73737)
-- Name: event_player_hole event_player_hole_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player_hole
    ADD CONSTRAINT event_player_hole_pkey PRIMARY KEY (event_player_id, hole_number);


--
-- TOC entry 3426 (class 2606 OID 41120)
-- Name: event_player event_player_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player
    ADD CONSTRAINT event_player_pkey PRIMARY KEY (event_player_id);


--
-- TOC entry 3429 (class 2606 OID 73754)
-- Name: hole hole_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.hole
    ADD CONSTRAINT hole_pkey PRIMARY KEY (tee_set_id, hole_number);


--
-- TOC entry 3431 (class 2606 OID 41126)
-- Name: hole hole_tee_set_hole_number_key; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.hole
    ADD CONSTRAINT hole_tee_set_hole_number_key UNIQUE (tee_set_id, hole_number);


--
-- TOC entry 3433 (class 2606 OID 41130)
-- Name: player player_ghin_number_key; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player
    ADD CONSTRAINT player_ghin_number_key UNIQUE (ghin_number);


--
-- TOC entry 3471 (class 2606 OID 360458)
-- Name: player_ledger player_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player_ledger
    ADD CONSTRAINT player_ledger_pkey PRIMARY KEY (player_ledger_id);


--
-- TOC entry 3435 (class 2606 OID 41134)
-- Name: player player_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player
    ADD CONSTRAINT player_pkey PRIMARY KEY (player_id);


--
-- TOC entry 3439 (class 2606 OID 41138)
-- Name: team_member team_member_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.team_member
    ADD CONSTRAINT team_member_pkey PRIMARY KEY (team_id, event_player_id);


--
-- TOC entry 3437 (class 2606 OID 41140)
-- Name: team team_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (team_id);


--
-- TOC entry 3441 (class 2606 OID 41142)
-- Name: tee_set tee_set_pkey; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.tee_set
    ADD CONSTRAINT tee_set_pkey PRIMARY KEY (tee_set_id);


--
-- TOC entry 3452 (class 2606 OID 262155)
-- Name: event_competition uq_event_competition; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition
    ADD CONSTRAINT uq_event_competition UNIQUE (event_id, type_code);


--
-- TOC entry 3456 (class 2606 OID 262179)
-- Name: competition_hole uq_event_competition_hole; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.competition_hole
    ADD CONSTRAINT uq_event_competition_hole UNIQUE (event_id, type_code, hole_number);


--
-- TOC entry 3466 (class 2606 OID 327681)
-- Name: event_competition_result uq_event_competition_player_scope; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition_result
    ADD CONSTRAINT uq_event_competition_player_scope UNIQUE (event_id, type_code, scope_type, scope_key, hole_number, player_id);


--
-- TOC entry 3448 (class 2606 OID 344065)
-- Name: event_player_hole uq_event_player_hole; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player_hole
    ADD CONSTRAINT uq_event_player_hole UNIQUE (event_player_id, hole_number);


--
-- TOC entry 3475 (class 2606 OID 524289)
-- Name: CTP_Winner_Temp ux_ctp_player_flight_hole; Type: CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public."CTP_Winner_Temp"
    ADD CONSTRAINT ux_ctp_player_flight_hole UNIQUE (player_name, flight_name, hole_number);


--
-- TOC entry 3461 (class 1259 OID 286750)
-- Name: idx_ecr_event; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_ecr_event ON public.event_competition_result USING btree (event_id);


--
-- TOC entry 3462 (class 1259 OID 286751)
-- Name: idx_ecr_event_player; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_ecr_event_player ON public.event_competition_result USING btree (event_id, player_id);


--
-- TOC entry 3463 (class 1259 OID 286752)
-- Name: idx_ecr_event_type; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_ecr_event_type ON public.event_competition_result USING btree (event_id, type_code);


--
-- TOC entry 3464 (class 1259 OID 327692)
-- Name: idx_ecr_event_winner; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_ecr_event_winner ON public.event_competition_result USING btree (event_id) WHERE (winner_flag = true);


--
-- TOC entry 3427 (class 1259 OID 385025)
-- Name: idx_ep_event; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_ep_event ON public.event_player USING btree (event_id, event_player_id);


--
-- TOC entry 3444 (class 1259 OID 385024)
-- Name: idx_eph_event_player; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_eph_event_player ON public.event_player_hole USING btree (event_player_id);


--
-- TOC entry 3445 (class 1259 OID 385027)
-- Name: idx_eph_net_score; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_eph_net_score ON public.event_player_hole USING btree (net_score) WHERE (net_score IS NOT NULL);


--
-- TOC entry 3446 (class 1259 OID 385026)
-- Name: idx_eph_scored; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_eph_scored ON public.event_player_hole USING btree (event_player_id, hole_number) WHERE (gross_score IS NOT NULL);


--
-- TOC entry 3467 (class 1259 OID 360484)
-- Name: idx_player_ledger_event; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_player_ledger_event ON public.player_ledger USING btree (event_id);


--
-- TOC entry 3468 (class 1259 OID 360486)
-- Name: idx_player_ledger_event_comp; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_player_ledger_event_comp ON public.player_ledger USING btree (event_competition_id);


--
-- TOC entry 3469 (class 1259 OID 360485)
-- Name: idx_player_ledger_event_player; Type: INDEX; Schema: public; Owner: lioneye
--

CREATE INDEX idx_player_ledger_event_player ON public.player_ledger USING btree (event_id, player_id);


--
-- TOC entry 3504 (class 2620 OID 81925)
-- Name: event_player event_player_after_update; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER event_player_after_update AFTER UPDATE ON public.event_player FOR EACH ROW EXECUTE FUNCTION public.trg_event_player_after_update();


--
-- TOC entry 3505 (class 2620 OID 49209)
-- Name: event_player trg_compute_event_player_course_hcap; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER trg_compute_event_player_course_hcap BEFORE INSERT OR UPDATE OF tee_set_id, player_id, hcap_index ON public.event_player FOR EACH ROW EXECUTE FUNCTION public.compute_event_player_course_hcap();


--
-- TOC entry 3502 (class 2620 OID 335875)
-- Name: event trg_event_buyin_changed; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER trg_event_buyin_changed AFTER UPDATE OF default_buy_in ON public.event FOR EACH ROW EXECUTE FUNCTION public.trg_event_recompute_purse();


--
-- TOC entry 3506 (class 2620 OID 335879)
-- Name: event_player trg_event_player_delete; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER trg_event_player_delete AFTER DELETE ON public.event_player FOR EACH ROW EXECUTE FUNCTION public.trg_event_player_removed();


--
-- TOC entry 3507 (class 2620 OID 335877)
-- Name: event_player trg_event_player_insert; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER trg_event_player_insert AFTER INSERT ON public.event_player FOR EACH ROW EXECUTE FUNCTION public.trg_event_player_added();


--
-- TOC entry 3503 (class 2620 OID 221192)
-- Name: event trg_prevent_event_delete_when_ledger_posted; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER trg_prevent_event_delete_when_ledger_posted BEFORE DELETE ON public.event FOR EACH ROW EXECUTE FUNCTION public.prevent_event_delete_when_ledger_posted();


--
-- TOC entry 3508 (class 2620 OID 49186)
-- Name: event_player trg_update_event_player_stats; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER trg_update_event_player_stats AFTER INSERT OR DELETE OR UPDATE ON public.event_player FOR EACH ROW EXECUTE FUNCTION public.update_event_player_stats();


--
-- TOC entry 3509 (class 2620 OID 49156)
-- Name: hole update_tee_set_totals; Type: TRIGGER; Schema: public; Owner: lioneye
--

CREATE TRIGGER update_tee_set_totals AFTER INSERT OR DELETE OR UPDATE ON public.hole FOR EACH ROW EXECUTE FUNCTION public.trg_update_tee_set_totals();


--
-- TOC entry 3491 (class 2606 OID 262180)
-- Name: competition_hole competition_hole_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.competition_hole
    ADD CONSTRAINT competition_hole_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(event_id) ON DELETE CASCADE;


--
-- TOC entry 3492 (class 2606 OID 262185)
-- Name: competition_hole competition_hole_type_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.competition_hole
    ADD CONSTRAINT competition_hole_type_code_fkey FOREIGN KEY (type_code) REFERENCES public.competition_type(type_code);


--
-- TOC entry 3489 (class 2606 OID 262156)
-- Name: event_competition event_competition_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition
    ADD CONSTRAINT event_competition_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(event_id) ON DELETE CASCADE;


--
-- TOC entry 3490 (class 2606 OID 262161)
-- Name: event_competition event_competition_type_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition
    ADD CONSTRAINT event_competition_type_code_fkey FOREIGN KEY (type_code) REFERENCES public.competition_type(type_code);


--
-- TOC entry 3476 (class 2606 OID 41173)
-- Name: event event_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event
    ADD CONSTRAINT event_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id);


--
-- TOC entry 3493 (class 2606 OID 270371)
-- Name: event_ctp_result event_ctp_result_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_ctp_result
    ADD CONSTRAINT event_ctp_result_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(event_id);


--
-- TOC entry 3494 (class 2606 OID 270376)
-- Name: event_ctp_result event_ctp_result_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_ctp_result
    ADD CONSTRAINT event_ctp_result_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.player(player_id);


--
-- TOC entry 3477 (class 2606 OID 450560)
-- Name: event_group event_group_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_group
    ADD CONSTRAINT event_group_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(event_id) ON DELETE CASCADE;


--
-- TOC entry 3478 (class 2606 OID 434176)
-- Name: event_player event_player_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player
    ADD CONSTRAINT event_player_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(event_id) ON DELETE CASCADE;


--
-- TOC entry 3479 (class 2606 OID 65557)
-- Name: event_player event_player_group_fk; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player
    ADD CONSTRAINT event_player_group_fk FOREIGN KEY (event_id, group_id) REFERENCES public.event_group(event_id, group_id) ON DELETE SET NULL;


--
-- TOC entry 3488 (class 2606 OID 73738)
-- Name: event_player_hole event_player_hole_event_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player_hole
    ADD CONSTRAINT event_player_hole_event_player_id_fkey FOREIGN KEY (event_player_id) REFERENCES public.event_player(event_player_id) ON DELETE CASCADE;


--
-- TOC entry 3480 (class 2606 OID 41208)
-- Name: event_player event_player_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player
    ADD CONSTRAINT event_player_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.player(player_id);


--
-- TOC entry 3481 (class 2606 OID 41213)
-- Name: event_player event_player_tee_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player
    ADD CONSTRAINT event_player_tee_set_id_fkey FOREIGN KEY (tee_set_id) REFERENCES public.tee_set(tee_set_id);


--
-- TOC entry 3495 (class 2606 OID 286745)
-- Name: event_competition_result fk_ecr_competition_type; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition_result
    ADD CONSTRAINT fk_ecr_competition_type FOREIGN KEY (type_code) REFERENCES public.competition_type(type_code);


--
-- TOC entry 3496 (class 2606 OID 286735)
-- Name: event_competition_result fk_ecr_event; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition_result
    ADD CONSTRAINT fk_ecr_event FOREIGN KEY (event_id) REFERENCES public.event(event_id);


--
-- TOC entry 3497 (class 2606 OID 368640)
-- Name: event_competition_result fk_ecr_event_competition; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition_result
    ADD CONSTRAINT fk_ecr_event_competition FOREIGN KEY (event_competition_id) REFERENCES public.event_competition(event_competition_id) ON DELETE CASCADE;


--
-- TOC entry 3498 (class 2606 OID 286740)
-- Name: event_competition_result fk_ecr_player; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_competition_result
    ADD CONSTRAINT fk_ecr_player FOREIGN KEY (player_id) REFERENCES public.player(player_id);


--
-- TOC entry 3482 (class 2606 OID 41238)
-- Name: event_player player.player_id; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.event_player
    ADD CONSTRAINT "player.player_id" FOREIGN KEY (host_player_id) REFERENCES public.player(player_id);


--
-- TOC entry 3499 (class 2606 OID 442368)
-- Name: player_ledger player_ledger_event_competition_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player_ledger
    ADD CONSTRAINT player_ledger_event_competition_fkey FOREIGN KEY (event_competition_id) REFERENCES public.event_competition(event_competition_id) ON DELETE CASCADE;


--
-- TOC entry 3500 (class 2606 OID 434181)
-- Name: player_ledger player_ledger_event_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player_ledger
    ADD CONSTRAINT player_ledger_event_fkey FOREIGN KEY (event_id) REFERENCES public.event(event_id) ON DELETE RESTRICT;


--
-- TOC entry 3501 (class 2606 OID 434186)
-- Name: player_ledger player_ledger_player_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.player_ledger
    ADD CONSTRAINT player_ledger_player_fkey FOREIGN KEY (player_id) REFERENCES public.player(player_id) ON DELETE RESTRICT;


--
-- TOC entry 3484 (class 2606 OID 41243)
-- Name: team team_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.event(event_id);


--
-- TOC entry 3485 (class 2606 OID 41248)
-- Name: team_member team_member_event_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.team_member
    ADD CONSTRAINT team_member_event_player_id_fkey FOREIGN KEY (event_player_id) REFERENCES public.event_player(event_player_id);


--
-- TOC entry 3486 (class 2606 OID 41253)
-- Name: team_member team_member_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.team_member
    ADD CONSTRAINT team_member_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(team_id);


--
-- TOC entry 3483 (class 2606 OID 41258)
-- Name: hole tee_set.tee_set_id; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.hole
    ADD CONSTRAINT "tee_set.tee_set_id" FOREIGN KEY (tee_set_id) REFERENCES public.tee_set(tee_set_id);


--
-- TOC entry 3487 (class 2606 OID 41263)
-- Name: tee_set tee_set_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: lioneye
--

ALTER TABLE ONLY public.tee_set
    ADD CONSTRAINT tee_set_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id);


--
-- TOC entry 3664 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: lioneye
--

GRANT USAGE ON SCHEMA public TO retool;


--
-- TOC entry 3665 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE "CTP_Winner_Temp"; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."CTP_Winner_Temp" TO retool;


--
-- TOC entry 3667 (class 0 OID 0)
-- Dependencies: 260
-- Name: SEQUENCE "CTP_Winner_Temp_ctp_winner_id_seq"; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public."CTP_Winner_Temp_ctp_winner_id_seq" TO retool;


--
-- TOC entry 3668 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE competition_hole; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.competition_hole TO retool;


--
-- TOC entry 3670 (class 0 OID 0)
-- Dependencies: 251
-- Name: SEQUENCE competition_hole_competition_hole_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.competition_hole_competition_hole_id_seq TO retool;


--
-- TOC entry 3671 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE competition_type; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.competition_type TO retool;


--
-- TOC entry 3672 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE course; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.course TO retool;


--
-- TOC entry 3674 (class 0 OID 0)
-- Dependencies: 231
-- Name: SEQUENCE course_course_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.course_course_id_seq TO retool;


--
-- TOC entry 3675 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE event; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.event TO retool;


--
-- TOC entry 3676 (class 0 OID 0)
-- Dependencies: 250
-- Name: TABLE event_competition; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.event_competition TO retool;


--
-- TOC entry 3678 (class 0 OID 0)
-- Dependencies: 249
-- Name: SEQUENCE event_competition_event_competition_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.event_competition_event_competition_id_seq TO retool;


--
-- TOC entry 3679 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE event_competition_result; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.event_competition_result TO retool;


--
-- TOC entry 3681 (class 0 OID 0)
-- Dependencies: 254
-- Name: SEQUENCE event_competition_result_event_competition_result_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.event_competition_result_event_competition_result_id_seq TO retool;


--
-- TOC entry 3682 (class 0 OID 0)
-- Dependencies: 253
-- Name: TABLE event_ctp_result; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.event_ctp_result TO retool;


--
-- TOC entry 3684 (class 0 OID 0)
-- Dependencies: 233
-- Name: SEQUENCE event_event_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.event_event_id_seq TO retool;


--
-- TOC entry 3685 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE event_group; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.event_group TO retool;


--
-- TOC entry 3687 (class 0 OID 0)
-- Dependencies: 235
-- Name: SEQUENCE event_group_group_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.event_group_group_id_seq TO retool;


--
-- TOC entry 3688 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE event_player; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.event_player TO retool;


--
-- TOC entry 3690 (class 0 OID 0)
-- Dependencies: 237
-- Name: SEQUENCE event_player_event_player_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.event_player_event_player_id_seq TO retool;


--
-- TOC entry 3691 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE event_player_hole; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.event_player_hole TO retool;


--
-- TOC entry 3692 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE hole; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.hole TO retool;


--
-- TOC entry 3693 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE player; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.player TO retool;


--
-- TOC entry 3694 (class 0 OID 0)
-- Dependencies: 258
-- Name: TABLE player_ledger; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.player_ledger TO retool;


--
-- TOC entry 3696 (class 0 OID 0)
-- Dependencies: 257
-- Name: SEQUENCE player_ledger_player_ledger_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.player_ledger_player_ledger_id_seq TO retool;


--
-- TOC entry 3698 (class 0 OID 0)
-- Dependencies: 240
-- Name: SEQUENCE player_player_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.player_player_id_seq TO retool;


--
-- TOC entry 3699 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE team; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.team TO retool;


--
-- TOC entry 3700 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE team_member; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.team_member TO retool;


--
-- TOC entry 3702 (class 0 OID 0)
-- Dependencies: 243
-- Name: SEQUENCE team_team_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.team_team_id_seq TO retool;


--
-- TOC entry 3703 (class 0 OID 0)
-- Dependencies: 244
-- Name: TABLE tee_set; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tee_set TO retool;


--
-- TOC entry 3705 (class 0 OID 0)
-- Dependencies: 245
-- Name: SEQUENCE tee_set_tee_set_id_seq; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.tee_set_tee_set_id_seq TO retool;


--
-- TOC entry 3706 (class 0 OID 0)
-- Dependencies: 246
-- Name: SEQUENCE tee_set_tee_set_id_seq1; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,USAGE ON SEQUENCE public.tee_set_tee_set_id_seq1 TO retool;


--
-- TOC entry 3707 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE v_event_competition_id; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.v_event_competition_id TO retool;


--
-- TOC entry 3708 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE v_player_hole_enriched_with_par_diff; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.v_player_hole_enriched_with_par_diff TO retool;


--
-- TOC entry 3709 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE v_event_player_rank_view; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.v_event_player_rank_view TO retool;


--
-- TOC entry 3710 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE v_event_winner_summary; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.v_event_winner_summary TO retool;


--
-- TOC entry 3711 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE v_player_hole_enriched; Type: ACL; Schema: public; Owner: lioneye
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.v_player_hole_enriched TO retool;


--
-- TOC entry 2206 (class 826 OID 33088)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO neon_superuser WITH GRANT OPTION;


--
-- TOC entry 2207 (class 826 OID 41268)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: lioneye
--

ALTER DEFAULT PRIVILEGES FOR ROLE lioneye IN SCHEMA public GRANT SELECT,USAGE ON SEQUENCES TO retool;


--
-- TOC entry 2205 (class 826 OID 33087)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON TABLES TO neon_superuser WITH GRANT OPTION;


--
-- TOC entry 2208 (class 826 OID 41269)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: lioneye
--

ALTER DEFAULT PRIVILEGES FOR ROLE lioneye IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO retool;


-- Completed on 2026-01-12 13:50:26 MST

--
-- PostgreSQL database dump complete
--

\unrestrict AyUIGP0UcExq1AFbYZAaXEryIslb1QfSqE9O5AU5peCbDNHqc51YcloVULc7j3h

