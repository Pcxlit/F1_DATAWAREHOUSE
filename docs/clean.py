# ============================================================
# clean_problem_files.py
#
# circuits.csv and drivers.csv have commas inside URL values:
#   Long_Beach,_California
#   Nelson_Piquet,_Jr.
#   Kurt_Ahrens,_Jr.
#
# This script replaces ",_" with "_" inside URLs only,
# then saves clean versions that BULK INSERT can handle.
#
# HOW TO RUN:
#   1. Put this script in the same folder as your CSV files
#      (C:\Users\deepak\OneDrive\Desktop\F1 PROJECT\f1\)
#   2. Open terminal in that folder
#   3. Run:  python clean_problem_files.py
#   4. Two new files will appear:
#        circuits_clean.csv
#        drivers_clean.csv
#   5. Add those two files to the stored procedure (shown below)
# ============================================================

import csv
import os

# Update this to your CSV folder path
CSV_FOLDER = r'C:\Users\deepak\OneDrive\Desktop\F1 PROJECT\f1'


def clean_file(input_filename, output_filename, url_col_index):
    """
    Reads a CSV, fixes the URL column by removing commas
    that appear inside URL values, writes a clean CSV.

    The fix: replace ',_' with '_' inside the URL field only.
    This targets exactly the Wikipedia URL pattern causing the issue:
        Long_Beach,_California  →  Long_Beach_California
        Nelson_Piquet,_Jr.      →  Nelson_Piquet_Jr.
        Kurt_Ahrens,_Jr.        →  Kurt_Ahrens_Jr.
    The URL still works — Wikipedia redirects either form.
    """
    input_path  = os.path.join(CSV_FOLDER, input_filename)
    output_path = os.path.join(CSV_FOLDER, output_filename)

    rows_fixed = 0
    rows_total = 0

    with open(input_path,  encoding='utf-8', newline='') as infile, \
         open(output_path, encoding='utf-8', newline='', mode='w') as outfile:

        reader = csv.reader(infile)
        writer = csv.writer(outfile, lineterminator='\n')  # Unix line endings to match originals

        # Write header unchanged
        header = next(reader)
        writer.writerow(header)

        for row in reader:
            rows_total += 1

            # Fix the URL column — replace ,_ with _ inside the URL only
            original_url = row[url_col_index]
            fixed_url    = original_url.replace(',_', '_')

            if fixed_url != original_url:
                row[url_col_index] = fixed_url
                rows_fixed += 1
                print(f'  Fixed: {repr(original_url)}')
                print(f'      → {repr(fixed_url)}')

            writer.writerow(row)

    print(f'\n{input_filename} → {output_filename}')
    print(f'  Total rows : {rows_total}')
    print(f'  Rows fixed : {rows_fixed}')
    print(f'  Saved to   : {output_path}')



print('=' * 50)
print('Cleaning circuits.csv...')
print('=' * 50)
clean_file(
    input_filename  = 'circuits.csv',
    output_filename = 'circuits_clean.csv',
    url_col_index   = 8
)


print()
print('=' * 50)
print('Cleaning drivers.csv...')
print('=' * 50)
clean_file(
    input_filename  = 'drivers.csv',
    output_filename = 'drivers_clean.csv',
    url_col_index   = 8
)

print()
print('=' * 50)
print('ALL DONE')
print('Now add these two BULK INSERTs to your stored procedure:')
print("""
        TRUNCATE TABLE bronze.brz_circuits;
        SET @starttime = GETDATE();
        BULK INSERT bronze.brz_circuits
        FROM 'C:\\Users\\deepak\\OneDrive\\Desktop\\F1 PROJECT\\f1\\circuits_clean.csv'
        WITH (
            FIRSTROW        = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR   = '0x0a',
            TABLOCK
        );
        SET @endtime = GETDATE();
        PRINT 'brz_circuits loaded in ' + CAST(DATEDIFF(SECOND, @starttime, @endtime) AS VARCHAR) + 's';
        SELECT 'brz_circuits' AS table_name, COUNT(*) AS row_count FROM bronze.brz_circuits;

        TRUNCATE TABLE bronze.brz_drivers;
        SET @starttime = GETDATE();
        BULK INSERT bronze.brz_drivers
        FROM 'C:\\Users\\deepak\\OneDrive\\Desktop\\F1 PROJECT\\f1\\drivers_clean.csv'
        WITH (
            FIRSTROW        = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR   = '0x0a',
            TABLOCK
        );
        SET @endtime = GETDATE();
        PRINT 'brz_drivers loaded in ' + CAST(DATEDIFF(SECOND, @starttime, @endtime) AS VARCHAR) + 's';
        SELECT 'brz_drivers' AS table_name, COUNT(*) AS row_count FROM bronze.brz_drivers;
""")
print('Expected: brz_circuits = 77 rows, brz_drivers = 861 rows')