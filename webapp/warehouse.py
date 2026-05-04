"""Register bronze CSVs and silver-style views used by gold-layer queries (DuckDB)."""

from pathlib import Path


def _lit(path: Path) -> str:
    return str(path.resolve()).replace("'", "''")


def register_views(con, datasets_dir: Path) -> None:
    d = datasets_dir

    def load(name: str, csv_name: str) -> None:
        p = _lit(d / csv_name)
        con.execute(
            f"CREATE OR REPLACE VIEW {name} AS "
            f"SELECT * FROM read_csv_auto('{p}', header=true, nullstr='\\N');"
        )

    load("races", "races.csv")
    load("results", "results.csv")
    load("drivers", "drivers.csv")
    load("constructors", "constructors.csv")
    load("circuits", "circuits.csv")
    load("qualifying", "qualifying.csv")
    load("pit_stops", "pit_stops.csv")
    load("lap_times", "lap_times.csv")
    load("driver_standings", "driver_standings.csv")
    load("constructor_standings", "constructor_standings.csv")
    load("status", "status.csv")

    con.execute(
        """
        CREATE OR REPLACE VIEW dim_races AS
        SELECT
            raceId AS race_id,
            CAST(year AS INTEGER) AS season_year,
            CAST(round AS INTEGER) AS round_number,
            circuitId AS circuit_id,
            name AS race_name,
            CAST(date AS DATE) AS race_date
        FROM races;
        """
    )
    con.execute(
        """
        CREATE OR REPLACE VIEW dim_drivers AS
        SELECT
            driverId AS driver_id,
            NULLIF(TRIM(driverRef), '') AS driver_ref,
            TRIM(forename) || ' ' || TRIM(surname) AS full_name,
            forename,
            surname,
            nationality,
            TRY_CAST(dob AS DATE) AS dob,
            code,
            CAST(number AS VARCHAR) AS number
        FROM drivers;
        """
    )
    con.execute(
        """
        CREATE OR REPLACE VIEW dim_constructors AS
        SELECT
            constructorId AS constructor_id,
            constructorRef AS constructor_ref,
            name AS constructor_name,
            nationality
        FROM constructors;
        """
    )
    con.execute(
        """
        CREATE OR REPLACE VIEW dim_circuits AS
        SELECT
            circuitId AS circuit_id,
            circuitRef AS circuit_ref,
            name AS circuit_name,
            location AS city,
            country AS country,
            TRY_CAST(lat AS DOUBLE) AS latitude,
            TRY_CAST(lng AS DOUBLE) AS longitude,
            TRY_CAST(alt AS INTEGER) AS altitude
        FROM circuits;
        """
    )
    con.execute(
        """
        CREATE OR REPLACE VIEW fct_race_results AS
        SELECT
            resultId AS result_id,
            raceId AS race_id,
            driverId AS driver_id,
            constructorId AS constructor_id,
            TRY_CAST(grid AS INTEGER) AS grid_position,
            TRY_CAST(position AS INTEGER) AS finish_position,
            TRY_CAST(positionOrder AS INTEGER) AS position_order,
            TRY_CAST(points AS DOUBLE) AS points,
            TRY_CAST(laps AS INTEGER) AS laps_completed,
            TRY_CAST(milliseconds AS BIGINT) AS race_time_ms,
            TRY_CAST(fastestLap AS INTEGER) AS fastest_lap_number,
            fastestLapTime AS fastest_lap_time,
            TRY_CAST(fastestLapSpeed AS DOUBLE) AS fastest_lap_speed,
            CASE
                WHEN positionText IN ('R', 'D', 'E', 'W', 'F', 'N') THEN true
                ELSE false
            END AS is_dnf,
            TRY_CAST(statusId AS INTEGER) AS status_id
        FROM results;
        """
    )
    con.execute(
        """
        CREATE OR REPLACE VIEW fct_qualifying AS
        SELECT
            qualifyId AS qualify_id,
            raceId AS race_id,
            driverId AS driver_id,
            constructorId AS constructor_id,
            TRY_CAST(position AS INTEGER) AS qualify_position,
            q1 AS q1_time,
            q2 AS q2_time,
            q3 AS q3_time,
            CASE
                WHEN q3 IS NOT NULL THEN 'Q3'
                WHEN q2 IS NOT NULL THEN 'Q2'
                ELSE 'Q1'
            END AS best_session
        FROM qualifying;
        """
    )
    con.execute(
        """
        CREATE OR REPLACE VIEW fct_pit_stops AS
        SELECT
            raceId AS race_id,
            driverId AS driver_id,
            CAST(stop AS INTEGER) AS stop_number,
            TRY_CAST(lap AS INTEGER) AS lap,
            duration AS duration_raw,
            TRY_CAST(milliseconds AS INTEGER) AS duration_ms
        FROM pit_stops;
        """
    )
    con.execute(
        """
        CREATE OR REPLACE VIEW fct_lap_times AS
        SELECT
            raceId AS race_id,
            driverId AS driver_id,
            CAST(lap AS INTEGER) AS lap_number,
            TRY_CAST(position AS INTEGER) AS track_position,
            time AS lap_time,
            TRY_CAST(milliseconds AS INTEGER) AS lap_time_ms
        FROM lap_times;
        """
    )
