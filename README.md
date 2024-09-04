# Bellabeat Capstone Project: Analyzing Smart Device Data to Inform Marketing Strategy

Bellabeat is a high-tech manufacturer of health-focused smart products for women. Their app connects to their smart wellness products, like Leaf, Time, and Spring, helping users track health data related to activity, sleep, stress, menstrual cycles, and mindfulness habits.

## The Business Task
The business task is to uncover insights into how consumers use their smart devices and develop recommendations to inform the marketing strategy for the company.

## Stakeholders:

Urška Sršen: Bellabeat’s co-founder and Chief Creative Officer.
Sando Mur: Mathematician, co-founder, and key member of the Bellabeat executive team.
Bellabeat marketing analytics team: Data analysts responsible for guiding Bellabeat’s marketing strategy.
The Data Life Cycle
I followed the six phases of the data life cycle proposed by Google for this analysis:

Ask
Prepare
Process
Analyze
Share
Act
### 1. Ask
Business Task: Uncover insights into consumer behavior using smart devices and develop marketing recommendations.

### 2. Prepare
Data Sources: The datasets used for this analysis are from Kaggle, licensed under the CCO Public Domain. The data was collected between 03-12-2016 and 05-12-2016 via Amazon Mechanical Turk. The focus is on the Fitabase Data 4.12.16-5.12 folder, containing 18 CSV files.

### 3. Process
I focused on six tables for analysis:

dailyactivity_merged
hourlycalories_merged
hourlyintensities_merged
hourlysteps_merged
sleepday_merged
weightLogInfo_merged
Using MySQL for analysis and Tableau Public for visualization, I automated the data upload process with a Python script.

### 4. Analyze
Descriptive Statistics:

Active Users: 14 users (42.4%) had an average of more than 8000 steps daily.
Sedentary Users: 19 users (57.6%) averaged less than 8000 steps daily.
Day of the Week: Saturday had the highest average total steps, while Sunday had the lowest.
Time of Day: Most steps were taken at noon, while the morning had the least.
Calories Burned: Tuesday had the most calories burned on average, with noon being the peak time.
### 5. Share
Key Insights:
On average, 14 out of 33 users (42.4%) recorded more than 8,000 steps daily, while 19 users (57.6%) averaged fewer than 8,000 steps.
We also observed that only five users were categorized as active (including the very active category), while eight were classified as sedentary. Approximately 79% of the users (26 out of 33) were either sedentary, lowly active, or somewhat active.
Interestingly, Saturday, rather than Monday or Friday, had the highest average number of total steps, with Tuesday following closely. The highest average step count was recorded between noon and 4 PM. On the other hand, Sunday and Thursday saw the lowest average step counts, with the morning hours having the fewest steps.
Tuesday also recorded the highest average number of calories burned, followed by Saturday, though the difference between these days was minimal. The fewest calories were burned on Thursday and Sunday, with noon being the time of day when the most calories were burned, and morning the least.
Saturday had the most active minutes on average, followed by Friday and Tuesday. In contrast, Monday and Tuesday had the highest average sedentary minutes, with Thursday and Saturday having the lowest.
The scatter plot analysis revealed no significant relationships between the variables. It’s important to note that these insights may not be fully representative, as the sample size is quite limited.

### 6. Act
* To improve activity levels, targeted reminders could be sent to users with low activity, encouraging them to actively use their Bellabeat devices throughout their daily routines. Gathering feedback on why users might not be wearing their devices could also be insightful.
* Providing educational materials on ideal activity targets would be beneficial, with devices automatically aligning with these standards. However, users should still have the flexibility to set personalized targets.
* Special notifications should be sent out on weekends—particularly Sundays, which have the lowest step counts—as well as in the evenings, especially when users are close to but not meeting 80% of their daily step goals.
* Given that Bellabeat is a female-centric company, targeted advertising campaigns aimed at women could help onboard new users.

The link to a more detailed article can be found [here](https://medium.com/@oboboebuka/bella-beat-capstone-analysis-project-7cad3c5c9e1c)
The link to the completed story on tableau can also be found [here](https://public.tableau.com/app/profile/ebuka.obobo/viz/FITBEAT/Story1)
