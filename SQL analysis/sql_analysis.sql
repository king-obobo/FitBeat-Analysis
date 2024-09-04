-- Setting the database to use
USE fitbeat;

-- Checking how many tables in total was uploaded into the schema
 SELECT 
    COUNT(DISTINCT table_name) AS no_of_tables
FROM
    information_schema.columns
WHERE
    TABLE_SCHEMA = 'fitbeat'; -- There are 6 tables (uploaded as .csv files) in the SCHEMA

-- Table name and the number of columns it has
SELECT 
    table_name, COUNT(column_name) as no_of_cols
FROM
    information_schema.columns
WHERE
    TABLE_SCHEMA = 'fitbeat'
GROUP BY table_name
ORDER BY no_of_cols DESC; 

/* dailyactivity_emerged has the highest amount of columns (15) while hourlycalories_merged and hourlysteps_merged both have the lowest amount of columns  */
-- We are looking out for common columns to potentially perform merges. 
 SELECT 
    table_name,
    SUM(CASE
        WHEN column_name = "Id" THEN 1
        ELSE 0
    END) AS has_id_column
FROM
    information_schema.columns
WHERE TABLE_SCHEMA = "fitbeat"
GROUP BY table_name; -- All table has the Id column

SELECT table_name, SUM(CASE WHEN DATA_TYPE = lower('DATETIME') THEN 1 ELSE 0 END) AS has_date_time
FROM information_schema.columns
WHERE TABLE_SCHEMA = "fitbeat"
GROUP BY table_name; -- All the tables has aleast one column with the datetime type  

-- Trying to merge the hourly tables into one for a start
SELECT * FROM hourlycalories_merged;
SELECT COUNT(DISTINCT id) FROM hourlycalories_merged; 
/* I am getting a distinct count of 33, wheras the description of the data says, "30 eligible Fitbit users consented" 
Lets check if this is a constant through the remaining tables */

-- Using a stored proceedure to perform this on the table

DELIMITER //

CREATE PROCEDURE CountDistinctVals(IN tableName VARCHAR(64))
BEGIN
	SET @sql = CONCAT('SELECT COUNT(DISTINCT Id) AS distict_count FROM ', tableName);
    PREPARE smt FROM @sql;
    EXECUTE smt;
    DEALLOCATE PREPARE smt;
END //
DELIMITER ;

CALL CountDistinctVals('fitbeat.dailyactivity_merged'); -- 33 distinct ids
CALL CountDistinctVals('fitbeat.hourlyintensities_merged'); -- 33 distinct ids
CALL CountDistinctVals('fitbeat.hourlysteps_merged'); -- 33 distinct ids
CALL CountDistinctVals('fitbeat.hourlycalories_merged'); -- 33 distinct ids
CALL CountDistinctVals('fitbeat.sleepday_merged'); -- 24 distinct values
CALL CountDistinctVals('fitbeat.weightloginfo_merged'); -- 8 distinct values.

/* I can easily conclude then that the sleepday_merged and the weightloginfo_merged does not contain data from all of the participants
To fix this, I may have to check back with the source and see. I can't though, as this was the entirety of the file made available online
*/
-- I want to merge the hourly tables into one so I can work with just one table instead of 3. But first some checks.
-- Lets be sure they all contain the same ids.

WITH distinct_ids_cals AS (
	SELECT DISTINCT Id FROM hourlycalories_merged
),
distinct_ids_intens AS (
	SELECT DISTINCT Id FROM hourlyintensities_merged
),
distinct_ids_steps AS (
	SELECT DISTINCT Id FROM hourlysteps_merged
)
SELECT COUNT(*) AS count_absent_ids 
FROM distinct_ids_cals 
WHERE 
	Id NOT IN (
		SELECT * FROM distinct_ids_intens) AND 
    Id NOT IN (
		SELECT * FROM distinct_ids_steps); -- The count is zero
        
SELECT * FROM hourlysteps_merged; -- 22,099 rows
SELECT * FROM hourlycalories_merged; -- 22,099 rows
SELECT * FROM hourlyintensities_merged; -- 22,099 rows

WITH distinct_hours_cals AS (
	SELECT DISTINCT ActivityHour FROM hourlycalories_merged
),
distinct_hours_intens AS (
	SELECT DISTINCT ActivityHour FROM hourlyintensities_merged
),
distinct_hours_steps AS (
	SELECT DISTINCT ActivityHour FROM hourlysteps_merged
)
SELECT COUNT(*) AS count_absent_dates
FROM distinct_hours_cals 
WHERE 
	ActivityHour NOT IN (
		SELECT * FROM distinct_hours_intens) AND 
    ActivityHour NOT IN (
		SELECT * FROM distinct_hours_intens); -- The count is zero
        
SELECT 
    cals.Id,
    cals.ActivityHour,
    cals.Calories,
    intens.TotalIntensity,
    intens.AverageIntensity,
    steps.StepTotal
FROM
    hourlycalories_merged cals
        LEFT JOIN
    hourlyintensities_merged intens ON cals.Id = intens.Id
        AND cals.ActivityHour = intens.ActivityHour
        LEFT JOIN
    hourlysteps_merged steps ON intens.Id = steps.Id
        AND intens.ActivityHour = steps.ActivityHour; -- 22,099 rows returned.

-- Let me create a new table and insert the values of the result into the table.
DROP TABLE hourlyactivity_merged;
CREATE TABLE IF NOT EXISTS hourlyactivity_merged (
	Id BIGINT,
    ActivityHour DATETIME,
    Calories INT,
    TotalIntensity INT,
    Averageintensity DOUBLE,
    StepTotal INT
);

INSERT INTO hourlyactivity_merged 
SELECT 
    cals.Id,
    cals.ActivityHour,
    cals.Calories,
    intens.TotalIntensity,
    intens.AverageIntensity,
    steps.StepTotal
FROM
    hourlycalories_merged cals
        LEFT JOIN
    hourlyintensities_merged intens ON cals.Id = intens.Id
        AND cals.ActivityHour = intens.ActivityHour
        LEFT JOIN
    hourlysteps_merged steps ON intens.Id = steps.Id
        AND intens.ActivityHour = steps.ActivityHour;

SELECT * FROM hourlyactivity_merged; -- 22,099 rows present.
SELECT * FROM hourlycalories_merged;
SELECT * FROM hourlyintensities_merged;

-- Shifting my focus (temporarily) on just two tables, dailyactivity_merged and hourlyactivity_merged
/* Simple data cleaning goals on the two tables
1. Check for duplicates
2. Check for Nulls
3. Standardize columns if needed
*/

SELECT * FROM dailyactivity_merged;
-- Dulplicates
WITH duplicate_table AS (
SELECT *, ROW_NUMBER() OVER(PARTITION BY Id, ActivityDate) AS row_num FROM dailyactivity_merged)
SELECT * FROM duplicate_table HAVING row_num > 1; -- No duplicate values in the dailyactivity_merged table

WITH duplicate_table AS (
SELECT *, ROW_NUMBER() OVER(PARTITION BY Id, ActivityHour) AS row_num FROM hourlyactivity_merged) -- No duplicates either
SELECT * FROM duplicate_table HAVING row_num > 1;

-- BASIC EDA
CALL CountDistinctVals('fitbeat.dailyactivity_merged');
CALL CountDistinctVals('fitbeat.hourlyactivity_merged');
/* We already know that there are 33 distinct Ids in the tables of focus instead of the 30 initially said by the task
*/
SELECT MIN(ActivityDate) start_month, MAX(ActivityDate) as end_month FROM dailyactivity_merged; -- Records are from 12th of April 2016 to 12th of May 2016.
SELECT MIN(ActivityHour) start_month, MAX(ActivityHour) as end_month FROM hourlyactivity_merged; -- This verifies it.

SELECT * FROM dailyactivity_merged;

-- Lets do some EDA and tidying up the data
/*
First we create a staging table to start our work
*/
DROP TABLE IF EXISTS staging_dailyactivity_merged;
CREATE TABLE staging_dailyactivity_merged LIKE dailyactivity_merged;
INSERT INTO staging_dailyactivity_merged 
SELECT * FROM dailyactivity_merged;

SELECT * FROM staging_dailyactivity_merged;

-- Turning off sql safe updates so I can alter the table.
SET SQL_SAFE_UPDATES = 0;
/* 
TIME TO CREATE NEW COLUMNS AND REMOVE SOME ONES
TotalDistance = TrackerDistance = LoggedActivitiesDistance + VeryActiveDistance + ModeratelyActiveDistance + LightActiveDistance + SedentaryActiveDistance.
Hence, I am leaving only the TotalDistance column and leaving out the rest. 
*/
-- to confirm
SELECT 
    TotalDistance,
    TrackerDistance,
    (LoggedActivitiesDistance + VeryActiveDistance + ModeratelyActiveDistance + LightActiveDistance + SedentaryActiveDistance) AS CalculatedDistance
FROM
    staging_dailyactivity_merged;
    
ALTER TABLE staging_dailyactivity_merged
DROP TrackerDistance,
DROP LoggedActivitiesDistance, 
DROP VeryActiveDistance, 
DROP ModeratelyActiveDistance,
DROP LightActiveDistance, 
DROP SedentaryActiveDistance;

/* 
I would also simply create one column called ActiveMinutes which would be the sum of VeryActiveMinute, FairlyActiveMinute and LightlyActiveMinutes. I would then delete those columns
*/
ALTER TABLE staging_dailyactivity_merged
ADD COLUMN ActiveMinutes INT;

UPDATE staging_dailyactivity_merged
SET ActiveMinutes = VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes;

ALTER TABLE staging_dailyactivity_merged
DROP VeryActiveMinutes,
DROP FairlyActiveMinutes,
DROP LightlyActiveMinutes;

SELECT * FROM staging_dailyactivity_merged;

-- Adding another column 'TotalLoggedMinutes' as SedentaryMinutes + ActiveMinutes
ALTER TABLE staging_dailyactivity_merged
ADD COLUMN TotalLoggedMinutes INT;

UPDATE staging_dailyactivity_merged
SET TotalLoggedMinutes = SedentaryMinutes + ActiveMinutes;

-- Setting 'TotalDistance' to two decimal places
UPDATE staging_dailyactivity_merged
SET TotalDistance = ROUND(TotalDistance, 2);

SELECT * FROM staging_dailyactivity_merged;
-- Now to the EDA proper. We start by checking how often each ID was logged in/how often they wore their Fitbit watches
SELECT 
    Id, COUNT(*) AS times_logged_in
FROM
    dailyactivity_merged
GROUP BY id
ORDER BY times_logged_in DESC;
/* We see that the range of times_logged_in is from 31 to 4.
Let us try to categorize this. From 31 to 21 logins would be classified as Higly engaged,
20 to 11 would be classified as moderately engaged less than 10 would be classified as low engagement.
*/

SELECT 
    Id, COUNT(Id) AS id_Count,
    CASE
        WHEN COUNT(Id) BETWEEN 21 AND 31 THEN 'Active User'
        WHEN COUNT(Id) BETWEEN 11 AND 20 THEN 'Moderate User'
        ELSE 'Low user'
    END as user_type
FROM
    staging_dailyactivity_merged
GROUP BY Id
ORDER BY id_Count DESC; -- Just 3 out of the 33 Ids were Moderate users and just 1 person was a low user.
-- Maybe send recommendations or alerts to the not so active persons as reminders to wear their watches

SELECT * FROM staging_dailyactivity_merged;
    
-- Next, let us add a day index to the date column.
ALTER TABLE staging_dailyactivity_merged
ADD COLUMN indexOfWeek INT;

ALTER TABLE staging_dailyactivity_merged
ADD COLUMN dayNames VARCHAR(64);

UPDATE staging_dailyactivity_merged
SET indexOfWeek = DAYOFWEEK(ActivityDate),
	dayNames = DAYNAME(ActivityDate);
    
SELECT * FROM staging_dailyactivity_merged;
-- Next, the steps column
-- Lets a summary of the descriptive statistics per user
SELECT 
    Id,
    ROUND(AVG(TotalSteps), 2) AS averageSteps,
    MIN(TotalSteps) AS minSteps,
    MAX(TotalSteps) AS maxSteps,
    ROUND(AVG(TotalDistance), 2) AS averageDistance,
    MIN(TotalDistance) AS minDistance,
    MAX(TotalDistance) AS maxDistance,
    ROUND(AVG(SedentaryMinutes), 2) AS averageSedentaryMins,
    MIN(SedentaryMinutes) AS minSedentaryMins,
    MAX(SedentaryMinutes) AS maxSedentaryMins,
    ROUND(AVG(ActiveMinutes), 2) AS averageActiveMins,
    MIN(ActiveMinutes) AS minActiveMins,
    MAX(ActiveMinutes) AS maxActiveMins,
    ROUND(AVG(Calories), 2) AS averageCalories,
    MIN(Calories) AS minCalories,
    MAX(Calories) AS maxCalories
FROM
    staging_dailyactivity_merged
GROUP BY Id
ORDER BY maxCalories DESC;

SELECT * FROM staging_dailyactivity_merged;
SELECT * FROM hourlyactivity_merged;

-- Continuing EDA
-- On the average, how many users met the minimum steps of 8,000 steps per day ?
SELECT 
    Id, ROUND(AVG(TotalSteps), 2) AS AverageTotalSteps
FROM
    staging_dailyactivity_merged
GROUP BY Id
HAVING AverageTotalSteps >= 8000
ORDER BY AverageTotalSteps DESC; 
-- 14 out of 33 users (42.4%) had an average of more than 8,000 steps. 
-- While 19 of the 33 users (57.6%) had and average of less than 8,000 steps.

/* Classify each user as 
	sedentary lifestyle - average of < 5,000 steps, 
    Low - 5,000 - 5,000–7,499, 
    Somewhat active - 7,500–9,999,
    Active - 10,000 - 12,499 and
    Very active - > 12,500
and check how many users fall into each category
*/
WITH activityLevelTable AS (
SELECT 
    Id,
    CASE
        WHEN ROUND(AVG(TotalSteps)) < 5000 THEN 'sedentary'
        WHEN ROUND(AVG(TotalSteps)) < 7499 THEN 'low'
        WHEN ROUND(AVG(TotalSteps)) < 9999 THEN 'somewhat active'
        WHEN ROUND(AVG(TotalSteps)) < 12499 THEN 'active'
        ELSE 'very active'
    END AS 'activityLevel'
FROM
    staging_dailyactivity_merged
GROUP BY Id)
SELECT activityLevel, COUNT(Id) AS activityLevel_count 
FROM activityLevelTable 
GROUP BY activityLevel 
ORDER BY activityLevel_count DESC;
-- Of the 33 users present, on the average, only 2 users were active
-- The query below checks for the two users that falls within the very active and active category.
WITH activityLevelTable AS (
SELECT 
    Id,
    CASE
        WHEN ROUND(AVG(TotalSteps)) < 5000 THEN 'sedentary'
        WHEN ROUND(AVG(TotalSteps)) < 7499 THEN 'low'
        WHEN ROUND(AVG(TotalSteps)) < 9999 THEN 'somewhat active'
        WHEN ROUND(AVG(TotalSteps)) < 12499 THEN 'active'
        ELSE 'very active'
    END AS 'activityLevel'
FROM
    staging_dailyactivity_merged
GROUP BY Id)
SELECT Id, activityLevel
FROM activityLevelTable WHERE activityLevel = 'very active' OR activityLevel = 'active';
-- '8053475328' and '8877689391' were the very active Ids
-- '1503960366', '2022484408', '3977333714', '4388161847' and '7007744171' were active
-- RECOMMENDATIONS BASED ON THIS (Targetted ads)

-- What DAY had the highest average total steps ?
SELECT 
    dayNames, ROUND(AVG(TotalSteps), 2) AS avgTotalSteps
FROM
    staging_dailyactivity_merged
GROUP BY dayNames
ORDER BY avgTotalSteps DESC;
-- interestingly, Saturday had the highest average total steps when compared to other days, while Sunday had the lowest average total steps.

-- Digging further. Which HOUR of the day had the highest average total steps ?
SELECT * FROM hourlyactivity_merged;

SELECT 
    CASE 
		WHEN HOUR(ActivityHour) BETWEEN 0 AND 11 THEN 'morning'
        WHEN HOUR(ActivityHour) BETWEEN 12 AND 16 THEN 'noon'
        WHEN HOUR(ActivityHour) BETWEEN 17 AND 23 THEN 'evening'
	END AS timeOfDay,
    ROUND(AVG(StepTotal), 2) AS avgStepTotal
FROM
    hourlyactivity_merged
GROUP BY timeOfDay
ORDER BY avgStepTotal DESC; -- Average Highest amount of steps were taken in the noon (12pm - 4pm) while the least was in the morning

-- Which WEEKDAY type had the highest average total steps ?
WITH weekType as (
SELECT Id, 
	CASE 
		WHEN indexOfWeek IN (1,7) THEN 'weekend' 
        ELSE 'weekday' 
	END AS weekType,
    TotalSteps
FROM staging_dailyactivity_merged)
SELECT 
	weekType
    , ROUND(AVG(TotalSteps), 2) AS avgTotalSteps 
FROM weekType GROUP BY weekType; -- Not suprising, more steps were taken on the average on workdays than on weekends.

-- What was the average calories burnt per user ?
SELECT * FROM staging_dailyactivity_merged;
SELECT 
	Id
    , ROUND(AVG(Calories), 2) AS avgCalories 
FROM staging_dailyactivity_merged 
GROUP BY Id
ORDER BY avgCalories DESC;

-- What was the average calories burnt per DAY ?
SELECT * FROM staging_dailyactivity_merged;
SELECT 
	dayNames
    , ROUND(AVG(Calories), 2) AS avgCalories 
FROM staging_dailyactivity_merged 
GROUP BY dayNames
ORDER BY avgCalories DESC; -- Tuesdays had the most burnt averagve calories folowed by saturday and Friday

-- In what time of the day was the average calories most burnt ?
SELECT * FROM hourlyactivity_merged;
SELECT 
    CASE 
		WHEN HOUR(ActivityHour) BETWEEN 0 AND 11 THEN 'morning'
        WHEN HOUR(ActivityHour) BETWEEN 12 AND 16 THEN 'noon'
        WHEN HOUR(ActivityHour) BETWEEN 17 AND 23 THEN 'evening'
	END AS timeOfDay,
    ROUND(AVG(Calories), 2) AS avgCalories
FROM
    hourlyactivity_merged
GROUP BY timeOfDay
ORDER BY avgCalories DESC; -- The most calories were burnt at noon while the least was in the morning.
-- RECOMMENDATIONS

-- What was the average active minutes per user vs average sedentaery minutes per DAY of week ?
SELECT * FROM staging_dailyactivity_merged;
SELECT 
	dayNames
    , ROUND(AVG(ActiveMinutes), 2) AS avgActiveMins
    , ROUND(AVG(SedentaryMinutes), 2) AS avgSedentaryMins
FROM staging_dailyactivity_merged 
GROUP BY dayNames
ORDER BY avgActiveMins DESC; 
-- On average, there were more active minutes on saturday, followed by friday and tuesday.
-- On average, there were more sedentary minutes on Monday and Tuesday 
-- With the least sedentary minutes on Thursday followed by Saturday.

-- What was the average active minutes per user vs average sedentaery minutes per USER ?
SELECT * FROM staging_dailyactivity_merged;
SELECT 
	Id
    , ROUND(AVG(ActiveMinutes), 2) AS avgActiveMins
    , ROUND(AVG(SedentaryMinutes), 2) AS avgSedentaryMins
FROM staging_dailyactivity_merged 
GROUP BY Id
-- HAVING avgActiveMins > 300 
ORDER BY avgActiveMins DESC; 

-- Which users met the cap of atleast 150 active mins per user ?
SELECT * FROM staging_dailyactivity_merged;
SELECT 
	Id
    , ROUND(AVG(ActiveMinutes), 2) AS avgActiveMins
    , ROUND(AVG(SedentaryMinutes), 2) AS avgSedentaryMins
FROM staging_dailyactivity_merged 
GROUP BY Id
HAVING avgActiveMins >= 150
ORDER BY avgActiveMins DESC; -- 27 users of 33 users. Recommendations ?

-- Average of all activity by  day of week
SELECT * FROM staging_dailyactivity_merged;

SELECT 
	dayNames
	, ROUND(AVG(TotalSteps),2) AS avgTotalSteps
    , ROUND(AVG(TotalDistance),2) AS avgTotalDistance
    , ROUND(AVG(ActiveMinutes),2) AS avgActiveMins
    , ROUND(AVG(SedentaryMinutes),2) AS avgSedentaryMins
    , ROUND(AVG(Calories),2) AS avgCalories
FROM staging_dailyactivity_merged
GROUP BY dayNames;

-- Explain these and state how there a direct relationship between some variableas and calories .

SELECT * FROM staging_dailyactivity_merged;
SELECT * FROM hourlyactivity_merged;