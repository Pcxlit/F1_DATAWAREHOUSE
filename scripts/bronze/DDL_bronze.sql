DROP TABLE IF EXISTS bronze.circuits;
CREATE TABLE bronze.circuits (
    circuitId       NVARCHAR(500),
    circuitRef      NVARCHAR(500),
    name            NVARCHAR(500),
    location        NVARCHAR(500),
    country         NVARCHAR(500),
    lat             NVARCHAR(500),
    lng             NVARCHAR(500),
    alt             NVARCHAR(500),
    url             NVARCHAR(500),
);
GO

DROP TABLE IF EXISTS bronze.constructors;
CREATE TABLE bronze.constructors (
    constructorId   NVARCHAR(500),
    constructorRef  NVARCHAR(500),
    name            NVARCHAR(500),
    nationality     NVARCHAR(500),
    url             NVARCHAR(500),
);
GO


DROP TABLE IF EXISTS bronze.drivers;
CREATE TABLE bronze.drivers (
    driverId        NVARCHAR(500),
    driverRef       NVARCHAR(500),
    number          NVARCHAR(500),   
    code            NVARCHAR(500),   
    forename        NVARCHAR(500),
    surname         NVARCHAR(500),
    dob             NVARCHAR(500), 
    nationality     NVARCHAR(500),
    url             NVARCHAR(500),
);
GO

DROP TABLE IF EXISTS bronze.status;
CREATE TABLE bronze.status (
    statusId        NVARCHAR(500),
    status          NVARCHAR(500),
);
GO

DROP TABLE IF EXISTS bronze.seasons;
CREATE TABLE bronze.seasons (
    year            NVARCHAR(500),
    url             NVARCHAR(500),
);
GO

DROP TABLE IF EXISTS bronze.races;
CREATE TABLE bronze.races (
    raceId          NVARCHAR(500),
    year            NVARCHAR(500),
    round           NVARCHAR(500),
    circuitId       NVARCHAR(500),
    name            NVARCHAR(500),
    date            NVARCHAR(500),
    time            NVARCHAR(500),   
    url             NVARCHAR(500),
    fp1_date        NVARCHAR(500),  
    fp1_time        NVARCHAR(500),  
    fp2_date        NVARCHAR(500),   
    fp2_time        NVARCHAR(500),   
    fp3_date        NVARCHAR(500),   
    fp3_time        NVARCHAR(500),   
    quali_date      NVARCHAR(500),   
    quali_time      NVARCHAR(500),   
    sprint_date     NVARCHAR(500),   
    sprint_time     NVARCHAR(500),   
);
GO

DROP TABLE IF EXISTS bronze.results;
CREATE TABLE bronze.results (
    resultId          NVARCHAR(500),
    raceId            NVARCHAR(500),
    driverId          NVARCHAR(500),
    constructorId     NVARCHAR(500),
    number            NVARCHAR(500),   
    grid              NVARCHAR(500),
    position          NVARCHAR(500),   
    positionText      NVARCHAR(500),   
    positionOrder     NVARCHAR(500),
    points            NVARCHAR(500),
    laps              NVARCHAR(500),
    time              NVARCHAR(500),   
    milliseconds      NVARCHAR(500),  
    fastestLap        NVARCHAR(500),   
    rank              NVARCHAR(500),  
    fastestLapTime    NVARCHAR(500),  
    fastestLapSpeed   NVARCHAR(500),  
    statusId          NVARCHAR(500),
);
GO

DROP TABLE IF EXISTS bronze.brz_sprint_results;
CREATE TABLE bronze.brz_sprint_results (
    resultId          NVARCHAR(500),
    raceId            NVARCHAR(500),
    driverId          NVARCHAR(500),
    constructorId     NVARCHAR(500),
    number            NVARCHAR(500),
    grid              NVARCHAR(500),
    position          NVARCHAR(500),   
    positionText      NVARCHAR(500),
    positionOrder     NVARCHAR(500),
    points            NVARCHAR(500),
    laps              NVARCHAR(500),
    time              NVARCHAR(500),   
    milliseconds      NVARCHAR(500),   
    fastestLap        NVARCHAR(500),   
    fastestLapTime    NVARCHAR(500),   
    statusId          NVARCHAR(500),
);
GO

DROP TABLE IF EXISTS bronze.brz_qualifying;
CREATE TABLE bronze.brz_qualifying (
    qualifyId       NVARCHAR(500),
    raceId          NVARCHAR(500),
    driverId        NVARCHAR(500),
    constructorId   NVARCHAR(500),
    number          NVARCHAR(500),
    position        NVARCHAR(500),
    q1              NVARCHAR(500),   
    q2              NVARCHAR(500), 
    q3              NVARCHAR(500),  
);
GO

DROP TABLE IF EXISTS bronze.pit_stops;
CREATE TABLE bronze.pit_stops (
    raceId          NVARCHAR(500),
    driverId        NVARCHAR(500),
    stop            NVARCHAR(500),   
    lap             NVARCHAR(500),
    time            NVARCHAR(500),   
    duration        NVARCHAR(500),   
    milliseconds    NVARCHAR(500),  
   
);
GO

DROP TABLE IF EXISTS bronze.lap_times;
CREATE TABLE bronze.lap_times (
    raceId          NVARCHAR(500),
    driverId        NVARCHAR(500),
    lap             NVARCHAR(500),
    position        NVARCHAR(500),   
    time            NVARCHAR(500), 
    milliseconds    NVARCHAR(500),   
);
GO
 
DROP TABLE IF EXISTS bronze.driver_standings;
CREATE TABLE bronze.driver_standings (
    driverStandingsId   NVARCHAR(500),
    raceId              NVARCHAR(500),
    driverId            NVARCHAR(500),
    points              NVARCHAR(500),
    position            NVARCHAR(500),
    positionText        NVARCHAR(500),
    wins                NVARCHAR(500),
    );
GO

DROP TABLE IF EXISTS bronze.constructor_standings;
CREATE TABLE bronze.constructor_standings (
    constructorStandingsId  NVARCHAR(500),
    raceId                  NVARCHAR(500),
    constructorId           NVARCHAR(500),
    points                  NVARCHAR(500),
    position                NVARCHAR(500),
    positionText            NVARCHAR(500),
    wins                    NVARCHAR(500),
);
GO

DROP TABLE IF EXISTS bronze.constructor_results;
CREATE TABLE bronze.constructor_results (
    constructorResultsId    NVARCHAR(500),
    raceId                  NVARCHAR(500),
    constructorId           NVARCHAR(500),
    points                  NVARCHAR(500),
    status                  NVARCHAR(500), 
);
GO
