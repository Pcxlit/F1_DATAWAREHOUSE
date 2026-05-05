# F1_ANALYTICS_DATAWAREHOUSE 


# **F1 Stats Site**

A Formula 1 statistics website built on top of a local **SQL Server data warehouse** containing historical race data from 1950 to 2024. The project was built without any live data feed or external API — everything is powered by a static dataset that has been ingested, cleaned, and modelled using a medallion architecture before being served to the frontend.

The site allows users to explore 75 seasons worth of F1 history. You can look up race results for any Grand Prix, track driver career stats and championship progressions, compare constructor performances across seasons, analyse qualifying gaps, and dig into pit stop strategies and lap time data. The goal was to treat the dataset as a proper data warehouse rather than just a folder of CSVs, and build the site on top of well-structured, query-optimised gold layer tables.

---

## **Frontend**
Built with **HTML, CSS, and vanilla JavaScript**, the frontend uses the **Fetch API** to retrieve JSON from the Flask backend and **efficiently render data** to display race results, driver profiles, and analytical charts. By avoiding heavy frameworks, the site remains lightweight and responsive, sourcing all data directly from the local warehouse.

---

## **Backend**
Built with **Python and Flask**, the backend serves as a RESTful API bridging the SQL Server warehouse and the UI. It executes parameterized **T-SQL** queries against the Gold layer, processes data using **Pandas**, and returns serialized JSON. This decoupled design offloads heavy processing to the server, keeping the frontend fast and lightweight.

---

## **Architecture**
The warehouse is built on SQL Server and follows a three-layer **medallion architecture** — bronze, silver, and gold. Each layer has a clear and distinct responsibility, and data only moves forward through the layers as it is progressively cleaned, enriched, and shaped for consumption.

**Bronze Layer**
The bronze layer is the **raw ingestion layer** and serves as the single source of truth for the original data. All 14 CSV files are loaded into SQL Server tables exactly as they are, with no transformations applied. Column names, data types, and values are preserved as-is, including the \N strings used by the Ergast export to represent null or missing values. The purpose of this layer is not to make the data useful — it is simply to make it available and auditable. If anything goes wrong in a downstream layer, bronze is the starting point for reprocessing.

**Silver Layer**
The silver layer is the **cleaning and standardisation layer**. Raw data from bronze is transformed here into something reliable and consistent. \N values are replaced with proper SQL nulls, columns are cast to their correct data types (dates become DATE, lap times become integers in milliseconds, positions become INT where applicable), and string fields are trimmed and normalised. Referential integrity between tables is also checked at this stage — for example, ensuring every raceId in results.csv corresponds to a valid entry in races.csv. No aggregation or business logic is applied here. The silver layer is purely about producing clean, accurate, row-level data that downstream consumers can trust.

**Gold Layer**
The gold layer is the **serving layer** and is what the frontend queries directly. It contains pre-aggregated views and tables built specifically around the features of the site. Examples include season standings snapshots after each race, driver career summaries with total wins, podiums, and points, constructor championship progression by year, head-to-head qualifying comparisons, and circuit win records. Rather than running expensive joins and aggregations at query time, the heavy lifting is done once in the gold layer so the site can retrieve results quickly with simple queries.

---

## **Data**
The warehouse is built on 14 source tables loaded from the Ergast Motor Racing historical dataset export. In total the dataset contains over **700,000 rows** covering every aspect of Formula 1 from the first world championship season in 1950 through to the end of the 2024 season.

* **Races and Results:** 1,125 races and 26,759 individual race result entries.
* **Lap Data:** 589,081 individual lap records, representing the largest table in the warehouse.
* **Standings:** 34,863 driver standing rows and 13,391 constructor standing rows tracking championship evolution.
* **Supporting Entities:** 861 drivers, 212 constructors, and 77 unique circuits.
* **Technical Data:** 10,494 qualifying rows (Q1, Q2, and Q3 times) and 11,371 recorded pit stops.
* **Additional Records:** 360 sprint results, 12,625 constructor results, and 139 status codes covering all finish and retirement reasons.

---

## **Data Source**
Based on the **Ergast Motor Racing Developer API** historical dataset export.
