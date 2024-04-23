USE gameanalysis;
DESCRIBE player_details;
DESCRIBE level_details2;

-- Join the tables using an inner join
SELECT l.MyUnknownColumn, l.P_ID, p.PName, l.Stages_crossed, l.Level, l.Difficulty, l.Kill_Count, l.Headshots_Count, l.Score, l.Lives_Earned, l.Dev_ID, l.TimeStamp
FROM level_details2 l
INNER JOIN player_details p
ON l.P_ID = p.P_ID
LIMIT 0, 1000;

-- 1. Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0.
SELECT l.P_ID, l.Dev_ID, p.PName, l.Difficulty AS Difficulty_level
FROM level_details2 l
INNER JOIN player_details p
ON l.P_ID = p.P_ID
WHERE l.Level = 0;

-- 2. Find `Level1_code`wise average `Kill_Count` where `lives_earned` is 2, and at least 3 stages are crossed.
select p.l1_code, l.kill_count
from player_details as p
join level_details as l
on p.p_id = l.p_id
where l.lives_earned = 2 and l.stages_crossed = 3;

-- 3 Find the total number of stages crossed at each difficulty level for Level 2 with players sing `zm_series` devices. Arrange the result in decreasing order of the total number ofstages crossed. 
select difficulty as difficulty_level, count(stages_crossed) as total_no_of_stages
from level_details
where level = 2 and dev_id like 'zm_%'
group by difficulty, stages_crossed
order by stages_crossed desc;

-- 4. Find the total number of stages crossed at each difficulty level for Level 2 with players using `zm_series` devices. Arrange the result in decreasing order of the total number of stages crossed.
select p_id, count(distinct date(timestamp)) AS total_unique_dates
from level_details
group by p_id
having count(distinct date(timestamp)) > 1;

-- 5. Extract `P_ID` and the total number of unique dates for those players who have played games on multiple days.
select p_id, count(distinct date(timestamp)) AS total_unique_dates
from level_details
group by p_id
having count(distinct date(timestamp)) > 1;


-- 6. Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the average kill count for Medium difficulty.
select p_id, level, sum(kill_count) as total_kills
from level_details
where difficulty = 'medium'
group by p_id, level
having sum(kill_count) > (
    select avg(kill_count)
    from level_details
    where difficulty = 'medium'
)
order by p_id, level;

-- 7. Find `Level` and its corresponding `Level_code`wise sum of lives earned, excluding Level Arrange in ascending order of level.
select l.level, p.l1_code, p.l2_code, sum(lives_earned) as sum_of_lives_earned
from level_details2 as l
join player_details as p on p.p_id = l.p_id
where l.level > 0
group by l.level, p.l1_code, p.l2_code
order by l.level;

-- 8. Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well.
select * from (
    select dev_id, score, difficulty, row_number() over (partition by dev_id order by score desc) as rank
    from level_details2
) as subquery
where rank <= 3
order by dev_id, rank;

-- 9. Find the `first_login` datetime for each device ID.
select dev_id, min(timestamp) as first_login
from level_details2
group by dev_id;

-- 10. Find the top 5 scores based on each difficulty level and rank them in increasing order using `Rank`. Display `Dev_ID` as well.
select * from (
	select difficulty as difficulty_level, score, dev_id, rank() over (partition by difficulty order by score desc) as rank
	from level_details
) as subquery
where rank <= 5
order by difficulty_level, rank;

-- 11. Find the device ID that is first logged in (based on `start_datetime`) for each player(`P_ID`). Output should contain player ID, device ID, and first login datetime.
select p.p_id, l.dev_id, p.first_login_datetime
from (
    select p_id, min(timestamp) as first_login_datetime
    from level_details
    group by p_id
) as p
join level_details as l on p.p_id = l.p_id and p.first_login_datetime = l.timestamp
order by p.p_id;

-- 12. 11. For each player and date, determine how many `kill_counts` were played by the player
so far.
a) Using window functions
select p_id, timestamp, sum(kill_count) over (partition by p_id order by timestamp rows between unbounded preceding and current row) as cumulative_kill_count
from level_details2;

b) Without window functions
select l1.p_id, l1.timestamp, sum(l2.kill_count) as cumulative_kill_count
from level_details2 l1
join level_details2 l2 on l1.p_id = l2.p_id and l2.timestamp <= l1.timestamp
group by l1.p_id, l1.timestamp
order by l1.p_id, l1.timestamp;

-- 13. Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, excluding the most recent `start_datetime`.
select p_id, timestamp, sum(stages_crossed) over (partition by p_id order by timestamp rows between unbounded preceding and 1 preceding) as cumulative_stages_crossed
from level_details2
order by p_id, timestamp;

-- 14. Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`.
select dev_id, p_id, sum_of_scores
from (
    select dev_id, p_id, sum(score) as sum_of_scores, row_number() over (partition by dev_id order by sum(score) desc) as rank
    from level_details2
    group by dev_id, p_id
) as subquery
where rank <= 3
order by dev_id, rank;

-- 15. Find players who scored more than 50% of the average score, scored by the sum of scores for each `P_ID`. 
select p_id, sum(score) as sum_of_scores
from level_details2
group by p_id
having sum(score) > (
    select 0.5 * avg(sum_of_scores)
    from (
        select p_id, sum(score) as sum_of_scores
        from level_details2
        group by p_id
    ) as subquery
)
order by p_id;

-- 15.  Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well

-- First simply displaying top 10
select * from(
	select dev_id, headshots_count, difficulty, row_number() over (partition by dev_id order by headshots_count desc) as rank
	from level_details2
) as subquery
where rank <= 10
order by dev_id, rank;


-- Now creating a stored function to get top n
CREATE OR REPLACE FUNCTION get_top_headshots(n integer)
RETURNS TABLE (dev_id text, headshots_count bigint, difficulty text, rank bigint) AS $$
BEGIN
    RETURN QUERY 
    SELECT * FROM (
        SELECT l.dev_id, l.headshots_count, l.difficulty, ROW_NUMBER() OVER (PARTITION BY l.dev_id ORDER BY l.headshots_count DESC) as rank
        FROM level_details2 AS l
    ) AS subquery
    WHERE subquery.rank <= n
    ORDER BY dev_id, subquery.rank;
END; $$
LANGUAGE plpgsql;

-- Display the result by passing n headshots_count within the '()'
SELECT * FROM get_top_headshots(2);