from __future__ import annotations

import json
from pathlib import Path

import duckdb
import pandas as pd
from flask import Flask, jsonify, render_template, request

from warehouse import register_views


BASE_DIR = Path(__file__).resolve().parent
DATASETS_DIR = BASE_DIR.parent / "datasets"

app = Flask(__name__)

_db: duckdb.DuckDBPyConnection | None = None


def get_db() -> duckdb.DuckDBPyConnection:
    global _db
    if _db is None:
        _db = duckdb.connect(":memory:")
        register_views(_db, DATASETS_DIR)
    return _db


def json_records(df: pd.DataFrame) -> list:
    if df is None or df.empty:
        return []
    return json.loads(df.to_json(orient="records", date_format="iso"))

@app.get("/api/debug")
def debug():
    import os
    con = get_db()
    try:
        race_count = con.execute("SELECT COUNT(*) FROM dim_races").fetchone()[0]
    except Exception as e:
        race_count = f"ERROR: {e}"
    return jsonify({
        "datasets_dir": str(DATASETS_DIR),
        "datasets_dir_exists": DATASETS_DIR.exists(),
        "files_found": [f.name for f in DATASETS_DIR.glob("*.csv")] if DATASETS_DIR.exists() else [],
        "race_count": race_count
    })
    
@app.get("/")
def index():
    return render_template("index.html")


@app.get("/api/seasons")
def seasons():
    con = get_db()
    rows = con.execute(
        """
        SELECT DISTINCT season_year AS y
        FROM dim_races
        ORDER BY y DESC
        """
    ).fetchall()
    return jsonify([row[0] for row in rows])


@app.get("/api/drivers")
def drivers_list():
    q = (request.args.get("q") or "").strip().lower()
    con = get_db()
    if q:
        df = con.execute(
            """
            SELECT driver_id, full_name, nationality, code
            FROM dim_drivers
            WHERE lower(full_name) LIKE '%' || ? || '%'
            ORDER BY full_name
            LIMIT 100
            """,
            [q],
        ).fetchdf()
    else:
        df = con.execute(
            """
            SELECT driver_id, full_name, nationality, code
            FROM dim_drivers
            ORDER BY full_name
            """
        ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/driver-season-stats")
def gold_driver_season_stats():
    season = request.args.get("season", type=int)
    driver_id = request.args.get("driver_id", type=int)
    if not season:
        return jsonify({"error": "season is required"}), 400
    con = get_db()
    sql = """
    WITH season_results AS (
        SELECT
            r.driver_id,
            ra.season_year,
            COUNT(*) AS races_entered,
            SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END) AS wins,
            SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END) AS podiums,
            SUM(CASE WHEN r.grid_position = 1 THEN 1 ELSE 0 END) AS poles,
            SUM(CASE WHEN r.is_dnf THEN 1 ELSE 0 END) AS dnfs,
            SUM(COALESCE(r.points, 0)) AS points_scored,
            ROUND(AVG(r.finish_position), 1) AS avg_finish_position,
            ROUND(AVG(r.grid_position), 1) AS avg_grid_position,
            SUM(
                CASE
                    WHEN r.fastest_lap_number IS NOT NULL AND r.fastest_lap_speed IS NOT NULL
                    THEN 1 ELSE 0
                END
            ) AS fastest_laps
        FROM fct_race_results r
        JOIN dim_races ra ON ra.race_id = r.race_id
        GROUP BY 1, 2
    ),
    last_race_per_season AS (
        SELECT season_year, MAX(race_id) AS last_race_id
        FROM dim_races
        GROUP BY season_year
    ),
    champ AS (
        SELECT
            ds.driverId AS driver_id,
            dr.season_year,
            ds.position AS championship_position,
            TRY_CAST(ds.points AS DOUBLE) AS championship_points
        FROM driver_standings ds
        JOIN last_race_per_season dr ON dr.last_race_id = ds.raceId
    ),
    last_constructor AS (
        SELECT driver_id, season_year, constructor_name, last_constructor_id
        FROM (
            SELECT
                r.driver_id,
                ra.season_year,
                c.constructor_name,
                c.constructor_id AS last_constructor_id,
                ROW_NUMBER() OVER (
                    PARTITION BY r.driver_id, ra.season_year
                    ORDER BY ra.race_date DESC
                ) AS rn
            FROM fct_race_results r
            JOIN dim_races ra ON ra.race_id = r.race_id
            JOIN dim_constructors c ON c.constructor_id = r.constructor_id
        ) x
        WHERE rn = 1
    )
    SELECT
        sr.driver_id,
        sr.season_year,
        d.full_name,
        d.nationality,
        lc.constructor_name,
        lc.last_constructor_id,
        sr.races_entered,
        sr.wins,
        sr.podiums,
        sr.poles,
        sr.dnfs,
        sr.points_scored,
        sr.avg_finish_position,
        sr.avg_grid_position,
        sr.fastest_laps,
        ch.championship_position,
        ch.championship_points
    FROM season_results sr
    JOIN dim_drivers d ON d.driver_id = sr.driver_id
    LEFT JOIN champ ch
        ON ch.driver_id = sr.driver_id AND ch.season_year = sr.season_year
    LEFT JOIN last_constructor lc
        ON lc.driver_id = sr.driver_id AND lc.season_year = sr.season_year
    WHERE sr.season_year = ?
    """
    params: list = [season]
    if driver_id is not None:
        sql += " AND sr.driver_id = ?"
        params.append(driver_id)
    sql += " ORDER BY sr.points_scored DESC NULLS LAST, sr.wins DESC"
    df = con.execute(sql, params).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/driver-season-history")
def gold_driver_season_history():
    driver_id = request.args.get("driver_id", type=int)
    if not driver_id:
        return jsonify({"error": "driver_id is required"}), 400
    con = get_db()
    df = con.execute(
        """
        WITH season_results AS (
            SELECT
                r.driver_id,
                ra.season_year,
                COUNT(*) AS races_entered,
                SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END) AS wins,
                SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END) AS podiums,
                SUM(CASE WHEN r.grid_position = 1 THEN 1 ELSE 0 END) AS poles,
                SUM(CASE WHEN r.is_dnf THEN 1 ELSE 0 END) AS dnfs,
                SUM(COALESCE(r.points, 0)) AS points_scored,
                ROUND(AVG(r.finish_position), 1) AS avg_finish_position,
                ROUND(AVG(r.grid_position), 1) AS avg_grid_position,
                SUM(
                    CASE
                        WHEN r.fastest_lap_number IS NOT NULL AND r.fastest_lap_speed IS NOT NULL
                        THEN 1 ELSE 0
                    END
                ) AS fastest_laps
            FROM fct_race_results r
            JOIN dim_races ra ON ra.race_id = r.race_id
            GROUP BY 1, 2
        ),
        last_race_per_season AS (
            SELECT season_year, MAX(race_id) AS last_race_id
            FROM dim_races
            GROUP BY season_year
        ),
        champ AS (
            SELECT
                ds.driverId AS driver_id,
                dr.season_year,
                ds.position AS championship_position,
                TRY_CAST(ds.points AS DOUBLE) AS championship_points
            FROM driver_standings ds
            JOIN last_race_per_season dr ON dr.last_race_id = ds.raceId
        ),
        last_constructor AS (
            SELECT driver_id, season_year, constructor_name, last_constructor_id
            FROM (
                SELECT
                    r.driver_id,
                    ra.season_year,
                    c.constructor_name,
                    c.constructor_id AS last_constructor_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY r.driver_id, ra.season_year
                        ORDER BY ra.race_date DESC
                    ) AS rn
                FROM fct_race_results r
                JOIN dim_races ra ON ra.race_id = r.race_id
                JOIN dim_constructors c ON c.constructor_id = r.constructor_id
            ) x
            WHERE rn = 1
        )
        SELECT
            sr.driver_id,
            sr.season_year,
            d.full_name,
            d.nationality,
            lc.constructor_name,
            lc.last_constructor_id,
            sr.races_entered,
            sr.wins,
            sr.podiums,
            sr.poles,
            sr.dnfs,
            sr.points_scored,
            sr.avg_finish_position,
            sr.avg_grid_position,
            sr.fastest_laps,
            ch.championship_position,
            ch.championship_points
        FROM season_results sr
        JOIN dim_drivers d ON d.driver_id = sr.driver_id
        LEFT JOIN champ ch
            ON ch.driver_id = sr.driver_id AND ch.season_year = sr.season_year
        LEFT JOIN last_constructor lc
            ON lc.driver_id = sr.driver_id AND lc.season_year = sr.season_year
        WHERE sr.driver_id = ?
        ORDER BY sr.season_year DESC
        """,
        [driver_id],
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/constructor-season-stats")
def gold_constructor_season_stats():
    season = request.args.get("season", type=int)
    if not season:
        return jsonify({"error": "season is required"}), 400
    con = get_db()
    df = con.execute(
        """
        WITH csr AS (
            SELECT
                r.constructor_id,
                ra.season_year,
                COUNT(DISTINCT ra.race_id) AS races_entered,
                SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END) AS wins,
                SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END) AS podiums,
                SUM(CASE WHEN r.grid_position = 1 THEN 1 ELSE 0 END) AS poles,
                SUM(CASE WHEN r.is_dnf THEN 1 ELSE 0 END) AS dnfs,
                SUM(COALESCE(r.points, 0)) AS points_scored,
                COUNT(DISTINCT r.driver_id) AS drivers_used
            FROM fct_race_results r
            JOIN dim_races ra ON ra.race_id = r.race_id
            GROUP BY 1, 2
        ),
        last_race_per_season AS (
            SELECT season_year, MAX(race_id) AS last_race_id
            FROM dim_races
            GROUP BY season_year
        ),
        champcon AS (
            SELECT
                cs.constructorId AS constructor_id,
                dr.season_year,
                cs.position AS championship_position,
                TRY_CAST(cs.points AS DOUBLE) AS championship_points
            FROM constructor_standings cs
            JOIN last_race_per_season dr ON dr.last_race_id = cs.raceId
        )
        SELECT
            csr.constructor_id,
            csr.season_year,
            c.constructor_name,
            c.nationality,
            csr.races_entered,
            csr.wins,
            csr.podiums,
            csr.poles,
            csr.dnfs,
            csr.points_scored,
            csr.drivers_used,
            ch.championship_position,
            ch.championship_points
        FROM csr
        JOIN dim_constructors c ON c.constructor_id = csr.constructor_id
        LEFT JOIN champcon ch
            ON ch.constructor_id = csr.constructor_id
            AND ch.season_year = csr.season_year
        WHERE csr.season_year = ?
        ORDER BY csr.points_scored DESC NULLS LAST, csr.wins DESC
        """,
        [season],
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/driver-career-stats")
def gold_driver_career_stats():
    driver_id = request.args.get("driver_id", type=int)
    con = get_db()
    where = ""
    params: list = []
    if driver_id is not None:
        where = "WHERE c.driver_id = ?"
        params.append(driver_id)
    df = con.execute(
        f"""
        WITH last_race_per_season AS (
            SELECT season_year, MAX(race_id) AS last_race_id
            FROM dim_races
            GROUP BY season_year
        ),
        champ AS (
            SELECT
                ds.driverId AS driver_id,
                dr.season_year,
                ds.position AS championship_position
            FROM driver_standings ds
            JOIN last_race_per_season dr ON dr.last_race_id = ds.raceId
        ),
        champs AS (
            SELECT driver_id, COUNT(*) AS championships
            FROM champ
            WHERE CAST(championship_position AS INTEGER) = 1
            GROUP BY driver_id
        ),
        career AS (
            SELECT
                r.driver_id,
                MIN(ra.season_year) AS career_start_year,
                MAX(ra.season_year) AS career_end_year,
                COUNT(DISTINCT ra.season_year) AS seasons_active,
                COUNT(*) AS total_races,
                SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END) AS total_wins,
                SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END) AS total_podiums,
                SUM(CASE WHEN r.grid_position = 1 THEN 1 ELSE 0 END) AS total_poles,
                SUM(CASE WHEN r.is_dnf THEN 1 ELSE 0 END) AS total_dnfs,
                SUM(COALESCE(r.points, 0)) AS total_points,
                AVG(CAST(r.finish_position AS DOUBLE)) AS avg_finish_position
            FROM fct_race_results r
            JOIN dim_races ra ON ra.race_id = r.race_id
            GROUP BY r.driver_id
        )
        SELECT
            c.driver_id,
            d.full_name,
            d.nationality,
            c.career_start_year,
            c.career_end_year,
            c.seasons_active,
            c.total_races,
            c.total_wins,
            c.total_podiums,
            c.total_poles,
            c.total_dnfs,
            c.total_points,
            ROUND(CAST(c.total_wins AS DOUBLE) / NULLIF(c.total_races, 0) * 100, 2) AS win_rate_pct,
            ROUND(CAST(c.total_podiums AS DOUBLE) / NULLIF(c.total_races, 0) * 100, 2) AS podium_rate_pct,
            ROUND(c.avg_finish_position, 2) AS avg_finish_position,
            COALESCE(ch.championships, 0) AS championships
        FROM career c
        LEFT JOIN dim_drivers d ON d.driver_id = c.driver_id
        LEFT JOIN champs ch ON ch.driver_id = c.driver_id
        {where}
        ORDER BY c.total_points DESC NULLS LAST
        """,
        params,
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/constructor-detail")
def gold_constructor_detail():
    constructor_id = request.args.get("constructor_id", type=int)
    if not constructor_id:
        return jsonify({"error": "constructor_id is required"}), 400
    con = get_db()
    profile_df = con.execute(
        """
        SELECT
            c.constructorId AS constructor_id,
            c.constructorRef AS constructor_ref,
            c.name AS name,
            c.nationality AS nationality,
            c.url AS wikipedia_url,
            MIN(r.year) AS first_season_year,
            MAX(r.year) AS last_season_year,
            COUNT(DISTINCT r.year) AS seasons_raced,
            COUNT(DISTINCT res.resultId) AS total_race_entries,
            SUM(CASE WHEN res.positionOrder = 1 THEN 1 ELSE 0 END) AS total_wins,
            SUM(CASE WHEN res.positionOrder <= 3 THEN 1 ELSE 0 END) AS total_podiums,
            SUM(CASE WHEN res.grid = 1 THEN 1 ELSE 0 END) AS total_poles,
            SUM(CASE WHEN CAST(res.rank AS VARCHAR) = '1' THEN 1 ELSE 0 END) AS total_fastest_laps,
            SUM(TRY_CAST(res.points AS DOUBLE)) AS total_career_points,
            COUNT(DISTINCT res.driverId) AS total_drivers_fielded
        FROM constructors c
        JOIN results res ON res.constructorId = c.constructorId
        JOIN races r ON r.raceId = res.raceId
        WHERE c.constructorId = ?
        GROUP BY
            c.constructorId, c.constructorRef, c.name, c.nationality, c.url
        """,
        [constructor_id],
    ).fetchdf()
    seasons_df = con.execute(
        """
        WITH csr AS (
            SELECT
                r.constructor_id,
                ra.season_year,
                COUNT(DISTINCT ra.race_id) AS races_entered,
                SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END) AS wins,
                SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END) AS podiums,
                SUM(CASE WHEN r.grid_position = 1 THEN 1 ELSE 0 END) AS poles,
                SUM(CASE WHEN r.is_dnf THEN 1 ELSE 0 END) AS dnfs,
                SUM(COALESCE(r.points, 0)) AS points_scored,
                COUNT(DISTINCT r.driver_id) AS drivers_used
            FROM fct_race_results r
            JOIN dim_races ra ON ra.race_id = r.race_id
            GROUP BY 1, 2
        ),
        last_race_per_season AS (
            SELECT season_year, MAX(race_id) AS last_race_id
            FROM dim_races
            GROUP BY season_year
        ),
        champcon AS (
            SELECT
                cs.constructorId AS constructor_id,
                dr.season_year,
                cs.position AS championship_position,
                TRY_CAST(cs.points AS DOUBLE) AS championship_points
            FROM constructor_standings cs
            JOIN last_race_per_season dr ON dr.last_race_id = cs.raceId
        )
        SELECT
            csr.constructor_id,
            csr.season_year,
            c.constructor_name,
            c.nationality,
            csr.races_entered,
            csr.wins,
            csr.podiums,
            csr.poles,
            csr.dnfs,
            csr.points_scored,
            csr.drivers_used,
            ch.championship_position,
            ch.championship_points
        FROM csr
        JOIN dim_constructors c ON c.constructor_id = csr.constructor_id
        LEFT JOIN champcon ch
            ON ch.constructor_id = csr.constructor_id
            AND ch.season_year = csr.season_year
        WHERE csr.constructor_id = ?
        ORDER BY csr.season_year DESC
        """,
        [constructor_id],
    ).fetchdf()
    prof_list = json_records(profile_df)
    return jsonify(
        {
            "profile": prof_list[0] if prof_list else None,
            "seasons": json_records(seasons_df),
        }
    )


@app.get("/api/gold/circuit-stats")
def gold_circuit_stats():
    con = get_db()
    df = con.execute(
        """
        WITH race_counts AS (
            SELECT
                ra.circuit_id,
                COUNT(DISTINCT ra.race_id) AS total_races_held,
                MIN(ra.season_year) AS first_race_year,
                MAX(ra.season_year) AS last_race_year
            FROM dim_races ra
            GROUP BY ra.circuit_id
        ),
        wins_per_driver AS (
            SELECT
                ra.circuit_id,
                r.driver_id,
                COUNT(*) AS wins,
                ROW_NUMBER() OVER (
                    PARTITION BY ra.circuit_id
                    ORDER BY COUNT(*) DESC, r.driver_id ASC
                ) AS rnk
            FROM fct_race_results r
            JOIN dim_races ra ON ra.race_id = r.race_id
            WHERE r.finish_position = 1
            GROUP BY ra.circuit_id, r.driver_id
        ),
        top_winner AS (
            SELECT w.circuit_id, d.full_name AS most_wins_driver, w.wins AS most_wins_count
            FROM wins_per_driver w
            JOIN dim_drivers d ON d.driver_id = w.driver_id
            WHERE w.rnk = 1
        ),
        pit_avg AS (
            SELECT
                ra.circuit_id,
                AVG(CAST(ps.stop_number AS DOUBLE)) AS avg_pit_stops_per_race
            FROM fct_pit_stops ps
            JOIN dim_races ra ON ra.race_id = ps.race_id
            GROUP BY ra.circuit_id
        ),
        lap_avg AS (
            SELECT
                ra.circuit_id,
                AVG(CAST(lt.lap_time_ms AS BIGINT)) AS avg_lap_time_ms
            FROM fct_lap_times lt
            JOIN dim_races ra ON ra.race_id = lt.race_id
            GROUP BY ra.circuit_id
        )
        SELECT
            ci.circuit_id,
            ci.circuit_name,
            ci.city,
            ci.country,
            ci.altitude,
            rc.total_races_held,
            rc.first_race_year,
            rc.last_race_year,
            tw.most_wins_driver,
            tw.most_wins_count,
            pa.avg_pit_stops_per_race,
            la.avg_lap_time_ms
        FROM dim_circuits ci
        JOIN race_counts rc ON rc.circuit_id = ci.circuit_id
        LEFT JOIN top_winner tw ON tw.circuit_id = ci.circuit_id
        LEFT JOIN pit_avg pa ON pa.circuit_id = ci.circuit_id
        LEFT JOIN lap_avg la ON la.circuit_id = ci.circuit_id
        ORDER BY rc.total_races_held DESC
        """
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/season-schedule")
def gold_season_schedule():
    season = request.args.get("season", type=int)
    if not season:
        return jsonify({"error": "season is required"}), 400
    con = get_db()
    df = con.execute(
        r"""
        SELECT
            r.raceId AS race_id,
            r.year AS season,
            r.round AS round,
            r.name AS race_name,
            r.url AS race_wiki_url,
            TRY_CAST(r.date AS DATE) AS race_date,
            r.time AS race_time,
            circ.circuitId AS circuit_id,
            circ.name AS circuit_name,
            circ.location AS circuit_location,
            circ.country AS circuit_country,
            TRY_CAST(circ.lat AS DOUBLE) AS circuit_lat,
            TRY_CAST(circ.lng AS DOUBLE) AS circuit_lng,
            CASE
                WHEN TRY_CAST(r.date AS DATE) < CURRENT_DATE THEN 'completed'
                WHEN TRY_CAST(r.date AS DATE) = CURRENT_DATE THEN 'today'
                WHEN TRY_CAST(r.date AS DATE) IS NULL THEN 'unknown'
                ELSE 'upcoming'
            END AS race_status,
            (
                SELECT TRIM(d2.forename) || ' ' || TRIM(d2.surname)
                FROM results rw
                JOIN drivers d2 ON d2.driverId = rw.driverId
                WHERE rw.raceId = r.raceId AND rw.positionOrder = 1
                LIMIT 1
            ) AS winner_name,
            (
                SELECT c2.name
                FROM results rw2
                JOIN constructors c2 ON c2.constructorId = rw2.constructorId
                WHERE rw2.raceId = r.raceId AND rw2.positionOrder = 1
                LIMIT 1
            ) AS winner_constructor,
            CASE
                WHEN r.sprint_date IS NOT NULL
                AND r.sprint_date != '\N'
                AND TRIM(r.sprint_date) != ''
                THEN 1 ELSE 0
            END AS is_sprint_weekend
        FROM races r
        JOIN circuits circ ON circ.circuitId = r.circuitId
        WHERE r.year = ?
        ORDER BY r.round
        """,
        [season],
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/constructor-profile")
def gold_constructor_profile():
    con = get_db()
    df = con.execute(
        """
        SELECT
            c.constructorId AS constructor_id,
            c.constructorRef AS constructor_ref,
            c.name AS name,
            c.nationality AS nationality,
            c.url AS wikipedia_url,
            MIN(r.year) AS first_season_year,
            MAX(r.year) AS last_season_year,
            COUNT(DISTINCT r.year) AS seasons_raced,
            COUNT(DISTINCT res.resultId) AS total_race_entries,
            SUM(CASE WHEN res.positionOrder = 1 THEN 1 ELSE 0 END) AS total_wins,
            SUM(CASE WHEN res.positionOrder <= 3 THEN 1 ELSE 0 END) AS total_podiums,
            SUM(CASE WHEN res.grid = 1 THEN 1 ELSE 0 END) AS total_poles,
            SUM(CASE WHEN CAST(res.rank AS VARCHAR) = '1' THEN 1 ELSE 0 END) AS total_fastest_laps,
            SUM(TRY_CAST(res.points AS DOUBLE)) AS total_career_points,
            COUNT(DISTINCT res.driverId) AS total_drivers_fielded
        FROM constructors c
        JOIN results res ON res.constructorId = c.constructorId
        JOIN races r ON r.raceId = res.raceId
        GROUP BY
            c.constructorId, c.constructorRef, c.name, c.nationality, c.url
        ORDER BY total_career_points DESC NULLS LAST
        """
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/standings-current")
def gold_standings_current():
    """Latest completed round in max season (aligned with your gold 'current' pattern)."""
    con = get_db()
    meta = con.execute(
        """
        WITH mx AS (SELECT MAX(year) AS y FROM races),
        lr AS (
            SELECT r.raceId, r.year, r.round, r.name AS race_name, CAST(r.date AS DATE) AS race_date
            FROM races r
            JOIN mx ON r.year = mx.y
            ORDER BY r.round DESC
            LIMIT 1
        )
        SELECT * FROM lr
        """
    ).fetchdf()
    if meta.empty:
        return jsonify({"season": None, "last_race": None, "drivers": [], "constructors": []})
    race_id = int(meta.iloc[0]["raceId"])
    season = int(meta.iloc[0]["year"])
    last_race = {
        "race_id": race_id,
        "season": season,
        "round": int(meta.iloc[0]["round"]),
        "race_name": meta.iloc[0]["race_name"],
        "race_date": meta.iloc[0]["race_date"],
    }
    drivers = con.execute(
        """
        SELECT
            ds.position,
            ds.positionText AS position_text,
            d.driverId AS driver_id,
            d.code,
            TRIM(d.forename) || ' ' || TRIM(d.surname) AS full_name,
            d.nationality,
            c.constructorId AS constructor_id,
            c.name AS constructor_name,
            TRY_CAST(ds.points AS DOUBLE) AS points,
            ds.wins
        FROM driver_standings ds
        JOIN drivers d ON d.driverId = ds.driverId
        JOIN results res ON res.raceId = ds.raceId AND res.driverId = ds.driverId
        JOIN constructors c ON c.constructorId = res.constructorId
        WHERE ds.raceId = ?
        ORDER BY ds.position ASC
        """,
        [race_id],
    ).fetchdf()
    constructors = con.execute(
        """
        SELECT
            cs.position AS standing_position,
            cs.positionText AS position_text,
            c.constructorId AS constructor_id,
            c.constructorRef AS constructor_ref,
            c.name AS constructor_name,
            c.nationality,
            TRY_CAST(cs.points AS DOUBLE) AS points,
            cs.wins
        FROM constructor_standings cs
        JOIN constructors c ON c.constructorId = cs.constructorId
        WHERE cs.raceId = ?
        ORDER BY cs.position ASC
        """,
        [race_id],
    ).fetchdf()
    return jsonify(
        {
            "season": season,
            "last_race": last_race,
            "drivers": json_records(drivers),
            "constructors": json_records(constructors),
        }
    )


@app.get("/api/gold/race-qualifying")
def gold_race_qualifying():
    race_id = request.args.get("race_id", type=int)
    if not race_id:
        return jsonify({"error": "race_id is required"}), 400
    con = get_db()
    df = con.execute(
        """
        SELECT
            q.qualifyId AS qualify_id,
            q.raceId AS race_id,
            r.year AS season,
            r.name AS race_name,
            q.position AS qualifying_position,
            q.number AS driver_number,
            d.driverId AS driver_id,
            d.code AS driver_code,
            TRIM(d.forename) || ' ' || TRIM(d.surname) AS driver_name,
            d.nationality AS driver_nationality,
            c.constructorId AS constructor_id,
            c.name AS constructor_name,
            q.q1 AS q1_time,
            q.q2 AS q2_time,
            q.q3 AS q3_time,
            COALESCE(q.q3, q.q2, q.q1) AS best_qualifying_time,
            CASE
                WHEN q.q3 IS NOT NULL THEN 'Q3'
                WHEN q.q2 IS NOT NULL THEN 'Q2'
                ELSE 'Q1'
            END AS session_reached,
            res.grid AS grid_position
        FROM qualifying q
        JOIN races r ON r.raceId = q.raceId
        JOIN drivers d ON d.driverId = q.driverId
        JOIN constructors c ON c.constructorId = q.constructorId
        LEFT JOIN results res ON res.raceId = q.raceId AND res.driverId = q.driverId
        WHERE q.raceId = ?
        ORDER BY q.position ASC NULLS LAST
        """,
        [race_id],
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/race-results-detail")
def gold_race_results_detail():
    season = request.args.get("season", type=int)
    race_id = request.args.get("race_id", type=int)
    if not season:
        return jsonify({"error": "season is required"}), 400
    con = get_db()
    if race_id:
        df = con.execute(
            """
            SELECT
                r.result_id,
                r.race_id,
                ra.season_year AS season,
                race.round AS round,
                race.name AS race_name,
                ra.race_date,
                ci.circuit_name,
                ci.country AS circuit_country,
                r.driver_id,
                d.code AS driver_code,
                d.full_name AS driver_name,
                d.nationality AS driver_nationality,
                d.number AS permanent_number,
                r.constructor_id,
                c.constructor_name,
                r.grid_position,
                r.finish_position,
                CAST(res_raw.positionText AS VARCHAR) AS position_text,
                r.position_order,
                r.points,
                r.laps_completed,
                r.race_time_ms,
                res_raw.time AS race_time_formatted,
                CASE
                    WHEN r.finish_position = 1 THEN NULL
                    WHEN r.race_time_ms IS NULL THEN NULL
                    ELSE r.race_time_ms - winner_ms.race_time_ms
                END AS gap_to_leader_ms,
                r.fastest_lap_number,
                r.fastest_lap_time,
                r.fastest_lap_speed,
                CASE WHEN CAST(res_raw.rank AS VARCHAR) = '1' THEN true ELSE false END AS is_fastest_lap,
                r.is_dnf AS is_dnf,
                r.status_id,
                st.status AS status_description
            FROM fct_race_results r
            JOIN results res_raw ON res_raw.resultId = r.result_id
            JOIN dim_races ra ON ra.race_id = r.race_id
            JOIN races race ON race.raceId = r.race_id
            JOIN dim_circuits ci ON ci.circuit_id = ra.circuit_id
            JOIN dim_drivers d ON d.driver_id = r.driver_id
            JOIN dim_constructors c ON c.constructor_id = r.constructor_id
            LEFT JOIN status st ON st.statusId = r.status_id
            LEFT JOIN (
                SELECT DISTINCT race_id, race_time_ms
                FROM fct_race_results
                WHERE finish_position = 1 AND race_time_ms IS NOT NULL
            ) winner_ms ON winner_ms.race_id = r.race_id
            WHERE ra.season_year = ? AND r.race_id = ?
            ORDER BY r.position_order ASC NULLS LAST
            """,
            [season, race_id],
        ).fetchdf()
        return jsonify(json_records(df))

    df = con.execute(
        """
        SELECT
            ra.race_id,
            ra.round_number AS round,
            ra.race_name,
            ra.race_date,
            ci.circuit_name,
            (
                SELECT d2.full_name
                FROM fct_race_results r2
                JOIN dim_drivers d2 ON d2.driver_id = r2.driver_id
                WHERE r2.race_id = ra.race_id AND r2.finish_position = 1
                LIMIT 1
            ) AS winner_name
        FROM dim_races ra
        JOIN dim_circuits ci ON ci.circuit_id = ra.circuit_id
        WHERE ra.season_year = ?
        ORDER BY ra.round_number
        """,
        [season],
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/head-to-head")
def gold_head_to_head():
    season = request.args.get("season", type=int)
    constructor_id = request.args.get("constructor_id", type=int)
    if not season:
        return jsonify({"error": "season is required"}), 400
    con = get_db()
    filt = ""
    params: list = [season]
    if constructor_id is not None:
        filt = "AND tc.constructor_id = ?"
        params.append(constructor_id)
    df = con.execute(
        f"""
        WITH teammate_comparison AS (
            SELECT
                r_main.season_year,
                rA.constructor_id,
                rA.driver_id AS driver_a_id,
                rB.driver_id AS driver_b_id,
                CASE WHEN NOT rA.is_dnf AND NOT rB.is_dnf THEN 1 ELSE 0 END AS race_valid,
                CASE
                    WHEN NOT rA.is_dnf AND NOT rB.is_dnf AND rA.finish_position < rB.finish_position
                    THEN 1 ELSE 0
                END AS a_race_win,
                CASE
                    WHEN NOT rA.is_dnf AND NOT rB.is_dnf AND rB.finish_position < rA.finish_position
                    THEN 1 ELSE 0
                END AS b_race_win,
                CASE
                    WHEN qA.qualify_position IS NOT NULL AND qB.qualify_position IS NOT NULL
                    THEN 1 ELSE 0
                END AS quali_valid,
                CASE WHEN qA.qualify_position < qB.qualify_position THEN 1 ELSE 0 END AS a_quali_win,
                CASE WHEN qB.qualify_position < qA.qualify_position THEN 1 ELSE 0 END AS b_quali_win
            FROM fct_race_results rA
            JOIN fct_race_results rB
                ON rA.race_id = rB.race_id
                AND rA.constructor_id = rB.constructor_id
                AND rA.driver_id < rB.driver_id
            JOIN dim_races r_main ON rA.race_id = r_main.race_id
            LEFT JOIN fct_qualifying qA
                ON rA.race_id = qA.race_id AND rA.driver_id = qA.driver_id
            LEFT JOIN fct_qualifying qB
                ON rB.race_id = qB.race_id AND rB.driver_id = qB.driver_id
        ),
        points_summary AS (
            SELECT
                r_pts.season_year,
                r.constructor_id,
                r.driver_id,
                SUM(r.points) AS total_points
            FROM fct_race_results r
            JOIN dim_races r_pts ON r.race_id = r_pts.race_id
            GROUP BY r_pts.season_year, r.constructor_id, r.driver_id
        )
        SELECT
            tc.driver_a_id,
            dA.full_name AS driver_a_name,
            tc.driver_b_id,
            dB.full_name AS driver_b_name,
            tc.constructor_id,
            con.constructor_name,
            tc.season_year AS season,
            SUM(tc.race_valid) AS races_compared,
            SUM(tc.a_race_win) AS driver_a_finished_ahead_count,
            SUM(tc.b_race_win) AS driver_b_finished_ahead_count,
            SUM(tc.quali_valid) AS quali_races_compared,
            SUM(tc.a_quali_win) AS driver_a_quali_ahead_count,
            SUM(tc.b_quali_win) AS driver_b_quali_ahead_count,
            COALESCE(pA.total_points, 0) AS driver_a_team_points,
            COALESCE(pB.total_points, 0) AS driver_b_team_points
        FROM teammate_comparison tc
        JOIN dim_drivers dA ON tc.driver_a_id = dA.driver_id
        JOIN dim_drivers dB ON tc.driver_b_id = dB.driver_id
        JOIN dim_constructors con ON tc.constructor_id = con.constructor_id
        LEFT JOIN points_summary pA
            ON tc.driver_a_id = pA.driver_id
            AND tc.season_year = pA.season_year
            AND tc.constructor_id = pA.constructor_id
        LEFT JOIN points_summary pB
            ON tc.driver_b_id = pB.driver_id
            AND tc.season_year = pB.season_year
            AND tc.constructor_id = pB.constructor_id
        WHERE tc.season_year = ?
        {filt}
        GROUP BY
            tc.driver_a_id, dA.full_name, tc.driver_b_id, dB.full_name,
            tc.constructor_id, con.constructor_name, tc.season_year,
            pA.total_points, pB.total_points
        HAVING SUM(tc.race_valid) > 0
        ORDER BY races_compared DESC
        LIMIT 200
        """,
        params,
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/gold/constructors-in-season")
def constructors_in_season():
    season = request.args.get("season", type=int)
    if not season:
        return jsonify({"error": "season is required"}), 400
    con = get_db()
    df = con.execute(
        """
        SELECT DISTINCT c.constructor_id, c.constructor_name
        FROM fct_race_results r
        JOIN dim_races ra ON ra.race_id = r.race_id
        JOIN dim_constructors c ON c.constructor_id = r.constructor_id
        WHERE ra.season_year = ?
        ORDER BY c.constructor_name
        """,
        [season],
    ).fetchdf()
    return jsonify(json_records(df))


# --- Legacy chart endpoints (reuse gold-friendly season_year) ---

@app.get("/api/driver-standings")
def driver_standings():
    season = request.args.get("season", type=int)
    if not season:
        return jsonify({"error": "season query param is required"}), 400
    con = get_db()
    df = con.execute(
        """
        SELECT
            r.driver_id AS driver_id,
            d.full_name AS driver_name,
            c.constructor_name AS constructor_name,
            SUM(COALESCE(r.points, 0)) AS points,
            SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END) AS wins
        FROM fct_race_results r
        JOIN dim_races ra ON ra.race_id = r.race_id
        JOIN dim_drivers d ON d.driver_id = r.driver_id
        JOIN dim_constructors c ON c.constructor_id = r.constructor_id
        WHERE ra.season_year = ?
        GROUP BY 1, 2, 3
        ORDER BY points DESC, wins DESC, driver_name
        LIMIT 20
        """,
        [season],
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/constructor-standings")
def constructor_standings():
    season = request.args.get("season", type=int)
    if not season:
        return jsonify({"error": "season query param is required"}), 400
    con = get_db()
    df = con.execute(
        """
        SELECT
            c.constructor_id AS constructor_id,
            c.constructor_name AS constructor_name,
            SUM(COALESCE(r.points, 0)) AS points,
            SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END) AS wins
        FROM fct_race_results r
        JOIN dim_races ra ON ra.race_id = r.race_id
        JOIN dim_constructors c ON c.constructor_id = r.constructor_id
        WHERE ra.season_year = ?
        GROUP BY 1, 2
        ORDER BY points DESC, wins DESC, constructor_name
        LIMIT 10
        """,
        [season],
    ).fetchdf()
    return jsonify(json_records(df))


@app.get("/api/race-winners")
def race_winners():
    season = request.args.get("season", type=int)
    if not season:
        return jsonify({"error": "season query param is required"}), 400
    con = get_db()
    df = con.execute(
        """
        SELECT
            ra.race_id AS race_id,
            ra.round_number AS round,
            ra.race_name AS race_name,
            r.driver_id AS winner_driver_id,
            d.full_name AS winner_name,
            r.constructor_id AS winner_constructor_id,
            c.constructor_name AS constructor_name
        FROM fct_race_results r
        JOIN dim_races ra ON ra.race_id = r.race_id
        JOIN dim_drivers d ON d.driver_id = r.driver_id
        JOIN dim_constructors c ON c.constructor_id = r.constructor_id
        WHERE ra.season_year = ? AND r.finish_position = 1
        ORDER BY ra.round_number
        """,
        [season],
    ).fetchdf()
    return jsonify(json_records(df))


if __name__ == "__main__":
    app.run(debug=True, port=5050)
