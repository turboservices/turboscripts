SELECT * FROM (
  (SELECT 'Cluster'
         ,'Name'
         ,'Mem Allocated (GB)'
         ,'VCPUs Allocated'
         ,'Storage (MB)')

  UNION

  (SELECT substring_index(vc.display_name,'\\', -1) as 'Cluster'
          ,e.display_name AS 'Name'
          ,ROUND(mem_cap/1024/1024,2) as 'Mem Allocated (GB)'
          ,ROUND(cpu_cap) as 'VCPUs Allocated'
          ,cur.st AS 'Storage (MB)'
  FROM (SELECT uuid
              ,MAX(IF(property_type = 'MemProvisioned' and property_subtype = 'used', avg_value, NULL)) as mem_cap
              ,MAX(IF(property_type = 'NumVCPUs', avg_value, NULL)) as cpu_cap
              ,SUM(IF(property_type = 'StorageAmount' and property_subtype = 'used', avg_value, 0)) AS st
          FROM vm_stats_by_day
         WHERE property_type IN ('VCPU', 'VMEM', 'StorageAmount', 'MemProvisioned', 'NumVCPUs')
           AND property_subtype in ('used', 'NumVCPUs')
           AND snapshot_time = SUBDATE(CURDATE(), 1)
         GROUP BY 1
        HAVING MAX(IF(property_type = 'VCPU', avg_value, 0)) = 0
           AND MAX(IF(property_type = 'VMem', avg_value, 0)) = 0
       ) cur
  JOIN entities e ON e.uuid = cur.uuid
  JOIN entity_assns_members_entities eame ON eame.entity_dest_id = e.id
  JOIN entity_assns eas ON eas.id = eame.entity_assn_src_id
  JOIN entities vc ON vc.id = eas.entity_entity_id
  JOIN (SELECT uuid
              ,COUNT(snapshot_time) AS dur
              ,MAX(sa)
          FROM (SELECT uuid
                      ,snapshot_time
                      ,MAX(IF(property_type = 'StorageAmount', avg_value, 0)) AS sa
                      ,MAX(IF(property_type = 'VMem', avg_value, 0)) AS vm
                      ,MAX(IF(property_type = 'VCPU', avg_value, 0)) AS vc
                  FROM vm_stats_by_day
                 WHERE property_type IN ('VCPU', 'VMEM', 'StorageAmount')
                 AND snapshot_time >= date_sub(CURDATE(),interval 60 day)
                 GROUP BY 1, 2
               ) t
         WHERE sa > 0
           AND vm = 0
           AND vc = 0
         GROUP BY 1
       ) dur ON dur.uuid = cur.uuid
  WHERE vc.name like 'GROUP-VMsByCluster\_%'
  AND eas.name = 'consistsOf'
  AND dur.dur = '60'
  ORDER BY Name DESC, Cluster ASC)
  ) as csv_alias
INTO OUTFILE '/tmp/powered_off_vms_60_days.csv'
     FIELDS TERMINATED BY ','
     ENCLOSED BY '"'
     ESCAPED BY '\\'
     LINES TERMINATED BY '\n'
