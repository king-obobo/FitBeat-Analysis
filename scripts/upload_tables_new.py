import mysql.connector
import os
import pandas as pd
from sqlalchemy import create_engine, exc
from sqlalchemy.types import Date, DateTime

# MySQL Connection Details
mysql_user = "enterYourUserName"
mysql_password = "enterYourPassword"
mysql_host = "EnterHost"
mysql_port = "EnterPort"
schema_name = "fitbeat"

# Step 1: Connect to MySQL without specifying the database
mydb = mysql.connector.connect(
    host=mysql_host,
    user=mysql_user,
    password=mysql_password
)

# Step 2: Create a cursor and create the database
mycursor = mydb.cursor()
mycursor.execute(f"DROP DATABASE IF EXISTS {schema_name}")
mycursor.execute(f"CREATE DATABASE IF NOT EXISTS {schema_name}")
mycursor.close()

# Step 3: Reconnect to MySQL with the newly created database
mydb.database = schema_name

# Step 4: Use SQLAlchemy to upload CSV files
engine = create_engine(f"mysql+mysqlconnector://{mysql_user}:{mysql_password}@{mysql_host}:{mysql_port}/{schema_name}")

csv_dir = "./Data/"

date_time_cols = ["ActivityDate", "ActivityHour", "SleepDay", "Date"]

for filename in os.listdir(csv_dir):
    if filename.endswith("csv"):
        file_path = os.path.join(csv_dir, filename)
        table_name = os.path.splitext(filename)[0].lower()
        
        try:
            # Read CSV file into DataFrame
            df = pd.read_csv(file_path)

            for col in date_time_cols:
                if col in df.columns:
                    df[col] = pd.to_datetime(df[col])

            # Define the SQL data types for the columns
            dtype_mapping = {
                'ActivityDate': Date(),
                'ActivityHour': DateTime(),
                'SleepDay': Date(),
                'Date': Date(),
            }
            
            # Start a transaction
            with engine.begin() as connection:
                # Insert data into the table, if transaction fails, it will rollback
                df.to_sql(name=table_name, con=connection, if_exists='replace', index=False)
            
            print(f"Uploaded {filename} to table {table_name}")
        
        except exc.SQLAlchemyError as e:
            print(f"An error occurred: {e}")
        
        finally:
            # Dispose of the connection after each file upload
            engine.dispose()

print(f"All csv files have been uploaded to MySQL")