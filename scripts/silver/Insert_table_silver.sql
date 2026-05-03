INSERT INTO silver.dim_drivers
SELECT
    driverId                                            AS driver_id,
    NULLIF(driverRef, '\N')                             AS driver_ref,
    TRIM(forename) + ' ' + TRIM(surname)                AS full_name,
    NULLIF(TRIM(forename), '\N')                        AS forename,
    NULLIF(TRIM(surname),  '\N')                        AS surname,
    NULLIF(nationality, '\N')                           AS nationality,
    TRY_CAST(NULLIF(dob, '\N') AS DATE)                 AS dob,
    NULLIF(code,   '\N')                                AS code,
    NULLIF(number, '\N')                                AS number
FROM bronze.drivers;
GO



INSERT INTO silver.dim_circuits
SELECT
    circuitId                               AS circuit_id,
    NULLIF(circuitRef, '\N')                AS circuit_ref,
    NULLIF(name,       '\N')                AS circuit_name,
    NULLIF(location,   '\N')                AS city,
    NULLIF(country,    '\N')                AS country,
    TRY_CAST(NULLIF(lat, '\N') AS FLOAT)    AS latitude,
    TRY_CAST(NULLIF(lng, '\N') AS FLOAT)    AS longitude,
    TRY_CAST(NULLIF(alt, '\N') AS INT)      AS altitude
FROM bronze.circuits;
GO

INSERT INTO silver.dim_races
SELECT
    raceId                                      AS race_id,
    CAST(year      AS INT)                 AS season_year,
    CAST(round     AS INT)                  AS round_number,
    circuitId                                   AS circuit_id,
    NULLIF(name, '\N')                        AS race_name,
    TRY_CAST(NULLIF(date, '\N') AS DATE)        AS race_date
FROM bronze.races;
GO


INSERT INTO silver.dim_constructors
SELECT
    constructorId                           AS constructor_id,
    NULLIF(constructorRef, '\N')            AS constructor_ref,
    NULLIF(name,           '\N')            AS constructor_name,
    NULLIF(nationality,    '\N')            AS nationality
FROM bronze.constructors;
GO
 

 INSERT INTO silver.fct_race_results
SELECT
    resultId                                                            AS result_id,
    raceId                                                              AS race_id,
    driverId                                                            AS driver_id,
    constructorId                                                       AS constructor_id,
    TRY_CAST(NULLIF(grid, '\N')         AS INT)                         AS grid_position,

    
         TRY_CAST(NULLIF(position, '\N') AS INT )                       AS finish_position,
    TRY_CAST(NULLIF(positionOrder, '\N') AS INT)                   AS position_order,
    TRY_CAST(NULLIF(points,        '\N') AS INT)                     AS points,
    TRY_CAST(NULLIF(laps,          '\N') AS INT)                  AS laps_completed,
    TRY_CAST(NULLIF(milliseconds,  '\N') AS INT)                    AS race_time_ms,
    TRY_CAST(NULLIF(fastestLap,    '\N') AS INT)                  AS fastest_lap_number,
    NULLIF(fastestLapTime,  '\N')                                       AS fastest_lap_time,
    TRY_CAST(NULLIF(fastestLapSpeed, '\N') AS FLOAT)                   AS fastest_lap_speed,
    CASE
        WHEN NULLIF(positionText, '\N') IN ('R','D','E','W','F','N')   THEN 1
        ELSE 0
    END                                                                 AS is_dnf,
    TRY_CAST(NULLIF(statusId, '\N') AS INT)                            AS status_id
FROM bronze.results;
GO




INSERT INTO silver.fct_pit_stops
SELECT
    raceId                                              AS race_id,
    driverId                                            AS driver_id,
    CAST(stop AS INT)                                  AS stop_number,
    TRY_CAST(NULLIF(lap, '\N') AS INT)             AS lap,
    TRY_CAST(NULLIF(time, '\N') AS TIME)                AS stop_time_of_day,
    TRY_CAST(NULLIF(duration,     '\N') AS FLOAT)       AS duration_seconds,
    TRY_CAST(NULLIF(milliseconds, '\N') AS INT)         AS duration_ms
FROM bronze.pit_stops;
GO


INSERT INTO silver.fct_lap_times
SELECT
    raceId                                          AS race_id,
    driverId                                        AS driver_id,
    CAST(lap          AS INT)                  AS lap_number,
    TRY_CAST(NULLIF(position,     '\N') AS INT) AS track_position,
    NULLIF(time,      '\N')                         AS lap_time,
    TRY_CAST(NULLIF(milliseconds, '\N') AS INT)     AS lap_time_ms
FROM bronze.lap_times;
GO



INSERT INTO silver.fct_qualifying
SELECT
    qualifyId                                       AS qualify_id,
    raceId                                          AS race_id,
    driverId                                        AS driver_id,
    constructorId                                   AS constructor_id,
    TRY_CAST(NULLIF(position, '\N') AS INT)     AS qualify_position,
    NULLIF(q1, '\N')                                AS q1_time,
    NULLIF(q2, '\N')                                AS q2_time,
    NULLIF(q3, '\N')                                AS q3_time,
    CASE
        WHEN NULLIF(q3, '\N') IS NOT NULL THEN 'Q3'
        WHEN NULLIF(q2, '\N') IS NOT NULL THEN 'Q2'
        ELSE 'Q1'
    END                                             AS best_session
FROM bronze.brz_qualifying;
GO
 

