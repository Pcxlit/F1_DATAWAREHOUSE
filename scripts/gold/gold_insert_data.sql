
WITH season_results AS (
    SELECT
        r.driver_id,
        ra.season_year,
        COUNT(*)                                                        AS races_entered,
        SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END)         AS wins,
        SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END)        AS podiums,
        SUM(CASE WHEN r.grid_position   = 1 THEN 1 ELSE 0 END)         AS poles,
        SUM(CASE WHEN r.is_dnf          = 1 THEN 1 ELSE 0 END)         AS dnfs,
        SUM(ISNULL(r.points, 0))                                        AS points_scored,
        ROUND(AVG(r.finish_position ),1)                          AS avg_finish_position,
        ROUND(AVG(r.grid_position),1)                           AS avg_grid_position,
        SUM(CASE WHEN r.fastest_lap_number IS NOT NULL
                  AND r.fastest_lap_speed IS NOT NULL THEN 1 ELSE 0 END) AS fastest_laps
    FROM silver.fct_race_results  r
    JOIN silver.dim_races         ra 
    ON ra.race_id = r.race_id
    GROUP BY r.driver_id, ra.season_year
),

last_race_per_season AS (
    SELECT season_year, MAX(race_id) AS last_race_id
    FROM silver.dim_races
    GROUP BY season_year
),
champ AS (
    SELECT ds.driverId  AS driver_id,
           dr.season_year,
           ds.position  AS championship_position,
           ds.points    AS championship_points
    FROM bronze.driver_standings  ds          
    JOIN last_race_per_season     dr 
    ON dr.last_race_id = ds.raceId
),

last_constructor AS (
    SELECT r.driver_id, ra.season_year, c.constructor_name,
           ROW_NUMBER() OVER (
               PARTITION BY r.driver_id, ra.season_year
               ORDER BY ra.race_date DESC
           ) AS rn
    FROM silver.fct_race_results r
    JOIN silver.dim_races        ra 
    ON ra.race_id       = r.race_id
    JOIN silver.dim_constructors c  
    ON c.constructor_id = r.constructor_id
)
INSERT INTO gold.driver_season_stats
SELECT
    sr.driver_id,
    sr.season_year,
    d.full_name,
    d.nationality,
    lc.constructor_name,
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
FROM season_results          sr
JOIN silver.dim_drivers      d  ON d.driver_id  = sr.driver_id
LEFT JOIN champ              ch ON ch.driver_id  = sr.driver_id
                                AND ch.season_year = sr.season_year
LEFT JOIN last_constructor   lc ON lc.driver_id   = sr.driver_id
                                AND lc.season_year = sr.season_year
                                AND lc.rn = 1;
GO

-------------------------------------------------------------------------------
--2.)
-------------------------------------------------------------------------------

WITH csr AS (
    SELECT
        r.constructor_id,
        ra.season_year,
        COUNT(DISTINCT ra.race_id)                                      AS races_entered,
        SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END)         AS wins,
        SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END)        AS podiums,
        SUM(CASE WHEN r.grid_position   = 1 THEN 1 ELSE 0 END)         AS poles,
        SUM(CASE WHEN r.is_dnf          = 1 THEN 1 ELSE 0 END)         AS dnfs,
        SUM(ISNULL(r.points, 0))                                        AS points_scored,
        COUNT(DISTINCT r.driver_id)                                     AS drivers_used
    FROM silver.fct_race_results  r
    JOIN silver.dim_races         ra ON ra.race_id = r.race_id
    GROUP BY r.constructor_id, ra.season_year
),
last_race_per_season AS (
    SELECT season_year, MAX(race_id) AS last_race_id
    FROM silver.dim_races
    GROUP BY season_year
),
champcon AS (
    SELECT cs.constructorId AS constructor_id,
           dr.season_year,
           cs.position      AS championship_position,
           cs.points        AS championship_points
    FROM bronze.constructor_standings cs
    JOIN last_race_per_season         dr ON dr.last_race_id = cs.raceId
)
INSERT INTO gold.constructor_season_stats
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
JOIN silver.dim_constructors c  ON c.constructor_id = csr.constructor_id
LEFT JOIN champcon             ch ON ch.constructor_id = csr.constructor_id
                                AND ch.season_year   = csr.season_year;
GO
 ----------------------------------------------------------------------------------------
 --3.)
 ---------------------------------------------------------------------------------------

 WITH career AS (
    SELECT
        r.driver_id,
        MIN(ra.season_year)                                              AS career_start_year,
        MAX(ra.season_year)                                              AS career_end_year,
        COUNT(DISTINCT ra.season_year)                                   AS seasons_active,
        COUNT(*)                                                         AS total_races,
        SUM(CASE WHEN r.finish_position = 1 THEN 1 ELSE 0 END)          AS total_wins,
        SUM(CASE WHEN r.finish_position <= 3 THEN 1 ELSE 0 END)         AS total_podiums,
        SUM(CASE WHEN r.grid_position   = 1 THEN 1 ELSE 0 END)          AS total_poles,
        SUM(CASE WHEN r.is_dnf          = 1 THEN 1 ELSE 0 END)          AS total_dnfs,
        SUM(ISNULL(r.points, 0))                                         AS total_points,
        AVG(CAST(r.finish_position AS FLOAT))                            AS avg_finish_position
    FROM silver.fct_race_results r
    JOIN silver.dim_races        ra ON ra.race_id = r.race_id
    GROUP BY r.driver_id
),
champs AS (
    SELECT driver_id, COUNT(*) AS championships
    FROM gold.driver_season_stats               -- built above
    WHERE championship_position = 1
    GROUP BY driver_id
)
INSERT INTO gold.driver_career_stats
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
    ROUND(CAST(c.total_wins    AS FLOAT) / NULLIF(c.total_races, 0) * 100, 2) AS win_rate_pct,
    ROUND(CAST(c.total_podiums AS FLOAT) / NULLIF(c.total_races, 0) * 100, 2) AS podium_rate_pct,
    c.avg_finish_position,
    ISNULL(ch.championships, 0)                                                AS championships
FROM career              c
JOIN silver.dim_drivers  d  ON d.driver_id  = c.driver_id
LEFT JOIN champs         ch ON ch.driver_id = c.driver_id;
GO
----------------------------------------------------------------------------------------------------------
--4.)
-----------------------------------------------------------------------------------------------------------
 
 WITH race_counts AS (
    SELECT
        ra.circuit_id,
        COUNT(DISTINCT ra.race_id)  AS total_races_held,
        MIN(ra.season_year)         AS first_race_year,
        MAX(ra.season_year)         AS last_race_year
    FROM silver.dim_races ra
    GROUP BY ra.circuit_id
),
wins_per_driver AS (
    SELECT
        ra.circuit_id,
        r.driver_id,
        COUNT(*) AS wins,
        ROW_NUMBER() OVER ( PARTITION BY ra.circuit_id    ORDER BY COUNT(*) DESC, r.driver_id ASC) AS rnk
    FROM silver.fct_race_results r
    JOIN silver.dim_races        ra ON ra.race_id = r.race_id
    WHERE r.finish_position = 1
    GROUP BY ra.circuit_id, r.driver_id
),
top_winner AS (
    SELECT w.circuit_id, d.full_name AS most_wins_driver, w.wins AS most_wins_count
    FROM wins_per_driver    w
    JOIN silver.dim_drivers d ON d.driver_id = w.driver_id
    WHERE w.rnk = 1
),
pit_avg AS (
    SELECT
        ra.circuit_id,
        AVG(CAST(ps.stop_number AS FLOAT)) AS avg_pit_stops_per_race
    FROM silver.fct_pit_stops ps
    JOIN silver.dim_races     ra ON ra.race_id = ps.race_id
    GROUP BY ra.circuit_id
),
lap_avg AS (
    SELECT
        ra.circuit_id,
        AVG(CAST(lt.lap_time_ms AS BIGINT)) AS avg_lap_time_ms
    FROM silver.fct_lap_times lt
    JOIN silver.dim_races     ra ON ra.race_id = lt.race_id
    GROUP BY ra.circuit_id
)
INSERT INTO gold.circuit_race_stats
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
FROM silver.dim_circuits       ci
JOIN race_counts               rc ON rc.circuit_id = ci.circuit_id
LEFT JOIN top_winner           tw ON tw.circuit_id = ci.circuit_id
LEFT JOIN pit_avg              pa ON pa.circuit_id = ci.circuit_id
LEFT JOIN lap_avg              la ON la.circuit_id = ci.circuit_id;
GO

----------------------------------------------------------------------
--5.)
---------------------------------------------------------------------


WITH CurrentSeason AS (
    SELECT MAX(year) AS season FROM bronze.races
),
LatestRound AS (
    SELECT TOP 1 r.raceId, r.year, r.round, r.name AS raceName, r.date
    FROM   bronze.races r
    JOIN   CurrentSeason cs ON r.year = cs.season
    ORDER  BY r.round DESC
)
INSERT INTO gold.driver_standings_current
SELECT
    ds.position,
    CAST(ds.positionText AS NVARCHAR(10)),
    d.driverId,
    d.driverRef,
    d.code,
    d.number                                AS permanentNumber,
    CONCAT(d.forename, ' ', d.surname)      AS fullName,
    d.nationality,
    c.name                                  AS constructorName,
    c.constructorRef,
    CAST(ds.points AS FLOAT)                AS points,
    ds.wins,
    lr.year                                 AS season,
    lr.raceName                             AS lastRaceName,
    lr.date                                 AS lastRaceDate,
    lr.round                                AS roundsCompleted
FROM bronze.driver_standings ds
JOIN LatestRound              lr  ON lr.raceId       = ds.raceId
JOIN bronze.drivers           d   ON d.driverId      = ds.driverId
JOIN (
    SELECT res.driverId, res.constructorId
    FROM   bronze.results res
    JOIN   LatestRound    lr2 ON lr2.raceId = res.raceId
) last_res ON last_res.driverId = ds.driverId
JOIN bronze.constructors c ON c.constructorId = last_res.constructorId;
GO
--------------------------------------------------------------------------------
--6.)
--------------------------------------------------------------------------------

INSERT INTO gold.constructor_profile
(
    constructorId, 
    constructorRef, 
    name, 
    nationality, 
    wikipediaUrl,
    firstSeasonYear, 
    lastSeasonYear, 
    seasonsRaced,
    totalRaceEntries, 
    totalWins, 
    totalPodiums, 
    totalPoles,
    totalFastestLaps, 
    totalCareerPoints,
    constructorChampionships, 
    totalDriversFielded
)
SELECT
    c.constructorId,
    c.constructorRef,
    c.name,
    c.nationality,
    c.url AS wikipediaUrl,
    MIN(r.year) AS firstSeasonYear,
    MAX(r.year) AS lastSeasonYear,
    COUNT(DISTINCT r.year) AS seasonsRaced,
    COUNT(DISTINCT res.resultId) AS totalRaceEntries,
    
    SUM(CASE WHEN res.positionOrder = 1  THEN 1 ELSE 0 END) AS totalWins,
    SUM(CASE WHEN res.positionOrder <= 3 THEN 1 ELSE 0 END) AS totalPodiums,
    SUM(CASE WHEN res.grid = 1           THEN 1 ELSE 0 END) AS totalPoles,
    
    SUM(CASE WHEN res.[rank] = '1' THEN 1 ELSE 0 END) AS totalFastestLaps,
    
   
    SUM(TRY_CAST(res.points AS FLOAT)) AS totalCareerPoints,
    
   
    (
        SELECT COUNT(*)
        FROM (
            SELECT 
                cs_i.constructorId,
                r_i.year,
                cs_i.position,
                ROW_NUMBER() OVER (
                    PARTITION BY r_i.year 
                    ORDER BY r_i.round DESC
                ) AS rn
            FROM bronze.constructor_standings AS cs_i
            JOIN bronze.races AS r_i ON r_i.raceId = cs_i.raceId
            WHERE cs_i.constructorId = c.constructorId
        ) AS champ
        WHERE champ.rn = 1 
          AND champ.position = 1
    ) AS constructorChampionships,
    
    COUNT(DISTINCT res.driverId) AS totalDriversFielded

FROM bronze.constructors AS c
JOIN bronze.results      AS res ON res.constructorId = c.constructorId
JOIN bronze.races        AS r   ON r.raceId          = res.raceId
GROUP BY 
    c.constructorId, 
    c.constructorRef, 
    c.name, 
    c.nationality, 
    c.url;
GO


-----------------------------------------------------------------------------
--7.)
-----------------------------------------------------------------------------
WITH
CurrentSeason AS
(
    SELECT MAX(year) AS season
    FROM   bronze.races
),
LatestRound AS
(
    SELECT TOP 1
        r.raceId,
        r.year,
        r.round,
        r.name AS raceName,
        r.date
    FROM  bronze.races  AS r
    JOIN  CurrentSeason AS cs  ON r.year = cs.season
    ORDER BY r.round DESC
)
INSERT INTO gold.constructor_standings_current
(
    standingPosition, positionText,
    constructorId, constructorRef, constructorName, nationality,
    points, wins,
    season, lastRaceName, lastRaceDate, roundsCompleted
)
SELECT
    cs.position                                             AS standingPosition,
    CAST(cs.positionText AS NVARCHAR(10))                   AS positionText,
    c.constructorId,
    c.constructorRef,
    c.name                                                  AS constructorName,
    c.nationality,
    CAST(cs.points AS FLOAT)                                AS points,
    cs.wins,
    lr.year                                                 AS season,
    lr.raceName                                             AS lastRaceName,
    lr.date                                                 AS lastRaceDate,
    lr.round                                                AS roundsCompleted
FROM  bronze.constructor_standings  AS cs
JOIN  LatestRound                   AS lr   ON lr.raceId       = cs.raceId
JOIN  bronze.constructors           AS c    ON c.constructorId = cs.constructorId;
GO

------------------------------------------------------------------------------
--8.)
------------------------------------------------------------------------------
INSERT INTO gold.season_schedule
(
    raceId, season, round, raceName, raceWikiUrl,
    raceDate, raceTime,
    fp1_date, fp1_time, fp2_date, fp2_time,
    fp3_date, fp3_time, quali_date, quali_time,
    sprint_date, sprint_time, isSprintWeekend,
    circuitId, circuitRef, circuitName, circuitLocation,
    circuitCountry, circuitLat, circuitLng, circuitWikiUrl,
    raceStatus, winnerName, winnerConstructor
)
SELECT
    r.raceId,
    r.year                                                  AS season,
    r.round,
    r.name                                                  AS raceName,
    r.url                                                   AS raceWikiUrl,
    TRY_CAST(r.date AS DATE)                                AS raceDate,
    r.time                                                  AS raceTime,
    NULLIF(r.fp1_date,    N'\\N'),
    NULLIF(r.fp1_time,    N'\\N'),
    NULLIF(r.fp2_date,    N'\\N'),
    NULLIF(r.fp2_time,    N'\\N'),
    NULLIF(r.fp3_date,    N'\\N'),
    NULLIF(r.fp3_time,    N'\\N'),
    NULLIF(r.quali_date,  N'\\N'),
    NULLIF(r.quali_time,  N'\\N'),
    NULLIF(r.sprint_date, N'\\N'),
    NULLIF(r.sprint_time, N'\\N'),
    CAST(
        CASE
            WHEN NULLIF(r.sprint_date, N'\\N') IS NOT NULL THEN 1
            ELSE 0
        END
    AS TINYINT)                                             AS isSprintWeekend,
    circ.circuitId,
    circ.circuitRef,
    circ.name                                               AS circuitName,
    circ.location                                           AS circuitLocation,
    circ.country                                            AS circuitCountry,
    circ.lat                                                AS circuitLat,
    circ.lng                                                AS circuitLng,
    circ.url                                                AS circuitWikiUrl,
    CASE
        WHEN TRY_CAST(r.date AS DATE) < CAST(GETDATE() AS DATE) THEN N'completed'
        WHEN TRY_CAST(r.date AS DATE) = CAST(GETDATE() AS DATE) THEN N'today'
        ELSE                                                          N'upcoming'
    END                                                     AS raceStatus,
    (
        SELECT TOP 1 CONCAT(dw.forename, N' ', dw.surname)
        FROM  bronze.results AS rw
        JOIN  bronze.drivers AS dw  ON dw.driverId = rw.driverId
        WHERE rw.raceId        = r.raceId
          AND rw.positionOrder = 1
    )                                                       AS winnerName,
    (
        SELECT TOP 1 cw.name
        FROM  bronze.results      AS rw2
        JOIN  bronze.constructors AS cw  ON cw.constructorId = rw2.constructorId
        WHERE rw2.raceId        = r.raceId
          AND rw2.positionOrder = 1
    )                                                       AS winnerConstructor
FROM  bronze.races    AS r
JOIN  bronze.circuits AS circ  ON circ.circuitId = r.circuitId;
GO

--------------------------------------------------9.)------------------------------------------
INSERT INTO gold.race_qualifying
(
    qualifyId, raceId, season, raceName, raceDate, qualifyingDate,
    qualifyingPosition, driverNumber,
    driverId, driverCode, driverName, driverNationality,
    constructorId, constructorName,
    q1Time, q2Time, q3Time, bestQualifyingTime, sessionReached,
    gridPosition
)
SELECT
    q.qualifyId,
    q.raceId,
    r.year                                                  AS season,
    r.name                                                  AS raceName,
    r.date                                                  AS raceDate,
    r.quali_date                                            AS qualifyingDate,
    q.position                                              AS qualifyingPosition,
    q.number                                                AS driverNumber,
    d.driverId,
    d.code                                                  AS driverCode,
    CONCAT(d.forename, N' ', d.surname)                     AS driverName,
    d.nationality                                           AS driverNationality,
    c.constructorId,
    c.name                                                  AS constructorName,
    NULLIF(q.q1, N'\\N')                                    AS q1Time,
    NULLIF(q.q2, N'\\N')                                    AS q2Time,
    NULLIF(q.q3, N'\\N')                                    AS q3Time,
    COALESCE(
        NULLIF(q.q3, N'\\N'),
        NULLIF(q.q2, N'\\N'),
        NULLIF(q.q1, N'\\N')
    )                                                       AS bestQualifyingTime,
    CASE
        WHEN NULLIF(q.q3, N'\\N') IS NOT NULL THEN N'Q3'
        WHEN NULLIF(q.q2, N'\\N') IS NOT NULL THEN N'Q2'
        ELSE                                       N'Q1'
    END                                                     AS sessionReached,
    res.grid                                                AS gridPosition
FROM  bronze.brz_qualifying   AS q
JOIN  bronze.races        AS r    ON r.raceId        = q.raceId
JOIN  bronze.drivers      AS d    ON d.driverId      = q.driverId
JOIN  bronze.constructors AS c    ON c.constructorId = q.constructorId
LEFT JOIN bronze.results  AS res  ON res.raceId      = q.raceId
                                 AND res.driverId     = q.driverId;
GO





