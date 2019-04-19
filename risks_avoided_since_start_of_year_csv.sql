SELECT * FROM (
  (SELECT 'Risks Avoided'
          ,'Count')

UNION
(SELECT IF(name like '%Q%VCPU%', 'ReadyQueue Congestion', substring_index(n.name, '::', -1)) as 'Risk Avoided'
       ,count(a.notification_id) 'Count'
  FROM
       (SELECT DISTINCT notification_id
          FROM actions 
         WHERE action_state = '4'
           AND action_type not in ('10','16')         # no resize or reconfigure actions
           AND (create_time BETWEEN '2019-1-1' AND NOW()
                OR update_time BETWEEN '2019-1-1' AND NOW())
       ) as a
  JOIN notifications n
    ON a.notification_id = n.id
   AND n.category in ('MarketProblem/Performance Assurance', 'MarketProblem/Compliance')
 GROUP BY 1)
  ) as csv_alias
INTO OUTFILE '/tmp/risks_avoided_since_start_of_year.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'
