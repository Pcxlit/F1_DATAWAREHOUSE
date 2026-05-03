----------------------------------------- 1-------------------------------------
DROP TABLE IF EXISTS gold.driver_season_stats;
GO
 
CREATE TABLE gold.driver_season_stats (
    driver_id               INT         NOT NULL,
    season_year             INT    NOT NULL,
    full_name               VARCHAR(100)NOT NULL,
    nationality             VARCHAR(50) NULL,
    constructor_name        VARCHAR(100)NULL,      
    races_entered           INT    NOT NULL,
    wins                    INT    NOT NULL,
    podiums                 INT    NOT NULL,  
    poles                   INT    NOT NULL,
    dnfs                    INT    NOT NULL,
    points_scored           INT       NOT NULL,
    avg_finish_position     INT      NULL,
    avg_grid_position       INT       NULL,
    fastest_laps            INT    NOT NULL,
    championship_position   INT     NULL,
    championship_points     INT       NULL,
    CONSTRAINT PK_driver_season_stats PRIMARY KEY (driver_id, season_year)
);
GO

ALTER TABLE gold.driver_season_stats 
ALTER COLUMN championship_points DECIMAL(10, 2);

ALTER TABLE gold.driver_season_stats 
ALTER COLUMN points_scored DECIMAL(10, 2);

-------------------------------------2.)------------------------------------------

DROP TABLE IF EXISTS gold.constructor_season_stats;
GO
 
CREATE TABLE gold.constructor_season_stats (
    constructor_id          INT          NOT NULL,
    season_year             INT     NOT NULL,
    constructor_name        VARCHAR(100) NOT NULL,
    nationality             VARCHAR(50)  NULL,
    races_entered           INT     NOT NULL,
    wins                    INT     NOT NULL,
    podiums                 INT     NOT NULL,
    poles                   INT     NOT NULL,
    dnfs                    INT     NOT NULL,
    points_scored           FLOAT        NOT NULL,
    drivers_used            TINYINT      NOT NULL,  -- distinct drivers that season
    championship_position   TINYINT      NULL,
    championship_points     FLOAT        NULL,
    CONSTRAINT PK_constructor_season_stats PRIMARY KEY (constructor_id, season_year)
);
GO
----------------------------------------3.)--------------------------------------------------

DROP TABLE IF EXISTS gold.driver_career_stats;
GO
 
CREATE TABLE gold.driver_career_stats (
    driver_id               INT             NOT NULL PRIMARY KEY,
    full_name               VARCHAR(100)    NOT NULL,
    nationality             VARCHAR(50)     NULL,
    career_start_year       INT        NULL,
    career_end_year         INT        NULL,
    seasons_active          INT        NOT NULL,
    total_races             INT        NOT NULL,
    total_wins              INT        NOT NULL,
    total_podiums           INT        NOT NULL,
    total_poles             INT        NOT NULL,
    total_dnfs              INT        NOT NULL,
    total_points            FLOAT           NOT NULL,
    win_rate_pct            FLOAT           NULL,     
    podium_rate_pct         FLOAT           NULL,
    avg_finish_position     FLOAT           NULL,
    championships           INT        NOT NULL  
);
GO

---------------------------------4.)------------------------------------------------

DROP TABLE IF EXISTS gold.circuit_race_stats;
GO
 
CREATE TABLE gold.circuit_race_stats (
    circuit_id              INT             NOT NULL PRIMARY KEY,
    circuit_name            VARCHAR(100)    NULL,
    city                    VARCHAR(100)    NULL,
    country                 VARCHAR(100)    NULL,
    altitude             INT             NULL,
    total_races_held        INT        NOT NULL,
    first_race_year         INT        NULL,
    last_race_year          INT        NULL,
    most_wins_driver        VARCHAR(100)    NULL,   
    most_wins_count         INT         NULL,
    avg_pit_stops_per_race  FLOAT           NULL,
    avg_lap_time_ms         BIGINT             NULL    
);
GO
----------------------------------------------------5.)--------------------------------------------

IF OBJECT_ID('gold.driver_standings_current', 'U') IS NOT NULL
    DROP TABLE gold.driver_standings_current;
GO

CREATE TABLE gold.driver_standings_current (
    position                INT             NOT NULL,
    positionText            NVARCHAR(10)    NULL,
    driverId                INT             NOT NULL,
    driverRef               NVARCHAR(100)   NULL,
    code                    NVARCHAR(10)    NULL,
    permanentNumber         NVARCHAR(10)    NULL,
    fullName                NVARCHAR(200)   NOT NULL,
    nationality             NVARCHAR(100)   NULL,
    constructorName         NVARCHAR(200)   NULL,
    constructorRef          NVARCHAR(100)   NULL,
    points                  FLOAT           NULL,
    wins                    INT             NULL,
    season                  INT             NOT NULL,
    lastRaceName            NVARCHAR(200)   NULL,
    lastRaceDate            NVARCHAR(20)    NULL,
    roundsCompleted         INT             NULL,
    CONSTRAINT PK_gold_driver_standings_current PRIMARY KEY (driverId)
);
GO
----------------------------------------------6.)-------------------------------------------------------

IF OBJECT_ID(N'gold.constructor_profile', N'U') IS NOT NULL
    DROP TABLE gold.constructor_profile;
GO

CREATE TABLE gold.constructor_profile
(
    constructorId               INT             NOT NULL,
    constructorRef              NVARCHAR(100)   NOT NULL,
    name                        NVARCHAR(200)   NOT NULL,
    nationality                 NVARCHAR(100)       NULL,
    wikipediaUrl                NVARCHAR(500)       NULL,
    firstSeasonYear             INT                 NULL,
    lastSeasonYear              INT                 NULL,
    seasonsRaced                INT                 NULL,
    totalRaceEntries            INT                 NULL,
    totalWins                   INT                 NULL,
    totalPodiums                INT                 NULL,
    totalPoles                  INT                 NULL,
    totalFastestLaps            INT                 NULL,
    totalCareerPoints           FLOAT               NULL,
    constructorChampionships    INT                 NULL,
    totalDriversFielded         INT                 NULL,
    CONSTRAINT PK_gold_constructor_profile PRIMARY KEY (constructorId)
);
GO
--------------------------7.)---------------------------------------------------------
IF OBJECT_ID(N'gold.constructor_standings_current', N'U') IS NOT NULL
    DROP TABLE gold.constructor_standings_current;
GO

CREATE TABLE gold.constructor_standings_current
(
    standingPosition    INT             NOT NULL,
    positionText        NVARCHAR(10)        NULL,
    constructorId       INT             NOT NULL,
    constructorRef      NVARCHAR(100)       NULL,
    constructorName     NVARCHAR(200)   NOT NULL,
    nationality         NVARCHAR(100)       NULL,
    points              FLOAT               NULL,
    wins                INT                 NULL,
    season              INT             NOT NULL,
    lastRaceName        NVARCHAR(200)       NULL,
    lastRaceDate        NVARCHAR(20)        NULL,
    roundsCompleted     INT                 NULL,
    CONSTRAINT PK_gold_constructor_standings_current PRIMARY KEY (constructorId)
);
GO


---------------------------------------------8.)---------------------------------------
IF OBJECT_ID(N'gold.season_schedule', N'U') IS NOT NULL
    DROP TABLE gold.season_schedule;
GO

CREATE TABLE gold.season_schedule
(
    raceId              INT             NOT NULL,
    season              INT             NOT NULL,
    round               INT             NOT NULL,
    raceName            NVARCHAR(200)   NOT NULL,
    raceWikiUrl         NVARCHAR(500)       NULL,
    raceDate            DATE                NULL,
    raceTime            NVARCHAR(20)        NULL,
    fp1_date            NVARCHAR(20)        NULL,
    fp1_time            NVARCHAR(20)        NULL,
    fp2_date            NVARCHAR(20)        NULL,
    fp2_time            NVARCHAR(20)        NULL,
    fp3_date            NVARCHAR(20)        NULL,
    fp3_time            NVARCHAR(20)        NULL,
    quali_date          NVARCHAR(20)        NULL,
    quali_time          NVARCHAR(20)        NULL,
    sprint_date         NVARCHAR(20)        NULL,
    sprint_time         NVARCHAR(20)        NULL,
    isSprintWeekend     TINYINT         NOT NULL    CONSTRAINT DF_season_schedule_isSprint DEFAULT 0,
    circuitId           INT             NOT NULL,
    circuitRef          NVARCHAR(100)       NULL,
    circuitName         NVARCHAR(200)       NULL,
    circuitLocation     NVARCHAR(200)       NULL,
    circuitCountry      NVARCHAR(100)       NULL,
    circuitLat          FLOAT               NULL,
    circuitLng          FLOAT               NULL,
    circuitWikiUrl      NVARCHAR(500)       NULL,
    raceStatus          NVARCHAR(20)    NOT NULL,
    winnerName          NVARCHAR(200)       NULL,
    winnerConstructor   NVARCHAR(200)       NULL,
    CONSTRAINT PK_gold_season_schedule PRIMARY KEY (raceId)
);
GO

----------------------------9.)-----------------------------------------------------------------
IF OBJECT_ID(N'gold.race_qualifying', N'U') IS NOT NULL
    DROP TABLE gold.race_qualifying;
GO

CREATE TABLE gold.race_qualifying
(
    qualifyId               INT             NOT NULL,
    raceId                  INT             NOT NULL,
    season                  INT             NOT NULL,
    raceName                NVARCHAR(200)   NOT NULL,
    raceDate                NVARCHAR(20)        NULL,
    qualifyingDate          NVARCHAR(20)        NULL,
    qualifyingPosition      INT             NOT NULL,
    driverNumber            INT                 NULL,
    driverId                INT             NOT NULL,
    driverCode              NVARCHAR(10)        NULL,
    driverName              NVARCHAR(200)   NOT NULL,
    driverNationality       NVARCHAR(100)       NULL,
    constructorId           INT             NOT NULL,
    constructorName         NVARCHAR(200)   NOT NULL,
    q1Time                  NVARCHAR(20)        NULL,
    q2Time                  NVARCHAR(20)        NULL,
    q3Time                  NVARCHAR(20)        NULL,
    bestQualifyingTime      NVARCHAR(20)        NULL,
    sessionReached          NVARCHAR(5)         NULL,
    gridPosition            INT                 NULL,
    CONSTRAINT PK_gold_race_qualifying PRIMARY KEY (qualifyId)
);
GO

---------------------------------10.)-------------------------------------------------
IF OBJECT_ID(N'gold.race_results_detail', N'U') IS NOT NULL
    DROP TABLE gold.race_results_detail;
GO
 
CREATE TABLE gold.race_results_detail (
    resultId                INT             NOT NULL,
    raceId                  INT             NOT NULL,
    season                  INT             NOT NULL,
    round                   INT             NOT NULL,
    raceName                NVARCHAR(200)   NOT NULL,
    raceDate                DATE            NULL,
    circuitName             NVARCHAR(200)   NULL,
    circuitCountry          NVARCHAR(100)   NULL,
    driverId                INT             NOT NULL,
    driverCode              NVARCHAR(10)    NULL,
    driverName              NVARCHAR(200)   NOT NULL,
    driverNationality       NVARCHAR(100)   NULL,
    permanentNumber         NVARCHAR(10)    NULL,
    constructorId           INT             NOT NULL,
    constructorName         NVARCHAR(200)   NOT NULL,
    gridPosition            INT             NULL,
    finishPosition          INT             NULL,
    positionText            NVARCHAR(10)    NULL,   
    positionOrder           INT             NULL,
    points                  FLOAT           NULL,
    lapsCompleted           INT             NULL,
    raceTimeMs              BIGINT          NULL,
    raceTimeFormatted       NVARCHAR(30)    NULL,   
    gapToLeaderMs           BIGINT          NULL,   
    fastestLapNumber        INT             NULL,
    fastestLapTime          NVARCHAR(15)    NULL,
    fastestLapSpeed         FLOAT           NULL,
    isFastestLap            BIT             NOT NULL DEFAULT 0,  
    isDNF                   BIT             NOT NULL DEFAULT 0,
    statusId                INT             NULL,
    statusDescription       NVARCHAR(100)   NULL,   
    CONSTRAINT PK_gold_race_results_detail PRIMARY KEY (resultId)
);
GO
CREATE NONCLUSTERED INDEX IX_rrd_raceId   ON gold.race_results_detail (raceId);
CREATE NONCLUSTERED INDEX IX_rrd_driverId ON gold.race_results_detail (driverId, season);


-----------------------11.)----------------------------------------------------------

IF OBJECT_ID(N'gold.head_to_head_stats', N'U') IS NOT NULL
    DROP TABLE gold.head_to_head_stats;
GO
 
CREATE TABLE gold.head_to_head_stats (
    driverAId               INT             NOT NULL,
    driverAName             NVARCHAR(200)   NOT NULL,
    driverBId               INT             NOT NULL,
    driverBName             NVARCHAR(200)   NOT NULL,
    constructorId           INT             NOT NULL,
    constructorName         NVARCHAR(200)   NOT NULL,
    season                  INT             NOT NULL,
    racesCompared           INT             NOT NULL DEFAULT 0,
    driverAFinishedAheadCount   INT         NOT NULL DEFAULT 0,
    driverBFinishedAheadCount   INT         NOT NULL DEFAULT 0,
    qualiRacesCompared          INT         NOT NULL DEFAULT 0,
    driverAQualiAheadCount      INT         NOT NULL DEFAULT 0,
    driverBQualiAheadCount      INT         NOT NULL DEFAULT 0,
    driverATeamPoints       FLOAT           NOT NULL DEFAULT 0,
    driverBTeamPoints       FLOAT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_gold_h2h PRIMARY KEY (driverAId, driverBId, constructorId, season),
    CONSTRAINT CK_gold_h2h_order CHECK (driverAId < driverBId)
);
GO



