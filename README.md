# F1_DATAWAREHOUSE
# F1 Stats Site

A Formula 1 statistics website built on top of a local SQL Server data warehouse containing historical race data from 1950 to 2024. The project was built without any live data feed or external API — everything is powered by a static dataset that has been ingested, cleaned, and modelled using a medallion architecture before being served to the frontend.

The site allows users to explore 75 seasons worth of F1 history. You can look up race results for any Grand Prix, track driver career stats and championship progressions, compare constructor performances across seasons, analyse qualifying gaps, and dig into pit stop strategies and lap time data. The goal was to treat the dataset as a proper data warehouse rather than just a folder of CSVs, and build the site on top of well-structured, query-optimised gold layer tables.

## Frontend

The frontend is built with React and styled using Tailwind CSS. It queries the gold layer tables directly and is focused on being fast, clean, and easy to navigate across both desktop and mobile. All data displayed on the site is static and sourced entirely from the warehouse with no real-time updates.

## Architecture

The warehouse is built on SQL Server and follows a three-layer medallion architecture — bronze, silver, and gold. Each layer has a clear and distinct responsibility, and data only moves forward through the layers as it is progressively cleaned, enriched, and shaped for consumption.

### Bronze Layer

The bronze layer is the raw ingestion layer and serves as the single source of truth for the original data. All 14 CSV files are loaded into SQL Server tables exactly as they are, with no transformations applied. Column names, data types, and values are preserved as-is, including the \N strings used by the Ergast export to represent null or missing values. The purpose of this layer is not to make the data useful — it is simply to make it available and auditable. If anything goes wrong in a downstream layer, bronze is the starting point for reprocessing.

### Silver Layer

The silver layer is the cleaning and standardisation layer. Raw data from bronze is transformed here into something reliable and consistent. \N values are replaced with proper SQL nulls, columns are cast to their correct data types (dates become DATE, lap times become integers in milliseconds, positions become INT where applicable), and string fields are trimmed and normalised. Referential integrity between tables is also checked at this stage — for example, ensuring every raceId in results.csv corresponds to a valid entry in races.csv. No aggregation or business logic is applied here. The silver layer is purely about producing clean, accurate, row-level data that downstream consumers can trust.

### Gold Layer

The gold layer is the serving layer and is what the frontend queries directly. It contains pre-aggregated views and tables built specifically around the features of the site. Examples include season standings snapshots after each race, driver career summaries with total wins, podiums, and points, constructor championship progression by year, head-to-head qualifying comparisons, and circuit win records. Rather than running expensive joins and aggregations at query time, the heavy lifting is done once in the gold layer so the site can retrieve results quickly with simple queries.

## Data

The warehouse is built on 14 source tables loaded from the Ergast Motor Racing historical dataset export. In total the dataset contains over 700,000 rows covering every aspect of Formula 1 from the first world championship season in 1950 through to the end of the 2024 season.

The races table contains 1,125 races with details on the circuit, season, round number, date, and session times including practice, qualifying, and sprint weekends. The results table has 26,759 entries covering finishing positions, points scored, laps completed, total race time, fastest lap, and finish status for every driver in every race. The lap_times table is the largest in the warehouse with 589,081 individual lap records. The driver_standings table has 34,863 rows tracking how the championship standings looked after each race, and constructor_standings has 13,391 rows doing the same for the constructors championship.

Supporting tables include drivers (861 entries with nationality, date of birth, and driver code), circuits (77 entries with country, location, and GPS coordinates), constructors (212 teams), qualifying (10,494 rows of Q1, Q2, and Q3 times), pit_stops (11,371 records with lap number and duration), sprint_results (360 entries), constructor_results (12,625 rows of per-race constructor points), and a status table with 139 codes covering every possible finish or retirement reason.

## Data Source

Based on the Ergast Motor Racing Developer API historical dataset export.
