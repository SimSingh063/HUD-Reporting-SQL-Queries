/* 
Title - All Position Details
Author - Simranjeet Singh
Date - 26/05/2023
Description - Details of all active and open positions within the organisation. 
*/

WITH Position AS (
SELECT 
    Pos.Position_Code, 
    Pos.Name, 
	Pos.Position_ID, 
	Pos.active_status, 
	Pos.attribute6 AS Employment_Type, 
	Pos.attribute2 AS ANZCO_Code, 
	Pos.attribute1 AS Occupational_Category, 
	Pos.attribute4 AS Leadership_Role, 
	Pos.attribute5 AS Leadership_tier,
	Pos.attribute7 AS Position_Under_Collective_Coverage_Flag,
	Pos.attribute8 AS Team_Group,
	pd.name AS Department, 
	loc.location_name AS Location, 
	job.name AS Job, 
	fs.value AS Cost_Center, 
	posp.parent_position_id, 
	posp.Parent_Position_Name
FROM 
    HR_ALL_POSITIONS_F_VL pos
	LEFT JOIN PER_DEPARTMENTS pd ON pd.organization_id = pos.organization_id
	LEFT JOIN HR_LOCATIONS_ALL_F_VL loc ON loc.location_id = pos.location_id
	INNER JOIN PER_JOBS job ON job.job_id = pos.job_id
	LEFT JOIN FND_VS_VALUES_B fs ON fs.value_id = pos.cost_center
	LEFT JOIN (SELECT  
                   DISTINCT pph.parent_position_id, 
				   pph.position_id, 
				   ppos.Parent_Position_Name
			   FROM 
			       PER_POSITION_HIERARCHY_F pph   
				   INNER JOIN (SELECT 
				                   DISTINCT apos.position_id, 
								   apos.name AS Parent_Position_Name
							   FROM 
                                   HR_ALL_POSITIONS_F_VL apos 
							   WHERE 
							       :data_as_off BETWEEN apos.effective_start_date AND apos.effective_end_date
                               )ppos ON ppos.position_id = pph.parent_position_id 
				WHERE 
				    :data_as_off BETWEEN pph.effective_start_date AND pph.effective_end_date
			   ) posp ON posp.position_id = pos.position_id
WHERE 
    :data_as_off BETWEEN Pos.effective_start_date AND pos.effective_end_date
	AND :data_as_off BETWEEN pd.effective_start_date AND pd.effective_end_date
	AND pos.active_status = 'A'
), 

Person AS (
SELECT 
    a.*,  
	p.Full_Name,
	ppl.person_number,
	gr.grade_code AS Band
FROM  
	(SELECT  
	    aa.person_id,
		aa.assignment_number,
		aa.assignment_id,
		aa.assignment_name,
		aa.position_id, 
		aa.primary_flag, 
		aa.grade_id, 
		aa.assignment_status_type AS Employment_Type2
	FROM 
	     PER_ALL_ASSIGNMENTS_M aa
	WHERE 
		 aa.assignment_type in('E','C') 
		 AND :data_as_off BETWEEN aa.effective_start_date AND aa.effective_end_date 
		 AND aa.effective_latest_change = 'Y'
		 AND aa.assignment_status_type in ('ACTIVE','SUSPENDED')
	) a
 	INNER JOIN PER_PERSON_NAMES_F p ON p.person_id = a.person_id 
	INNER JOIN PER_PEOPLE_F ppl ON ppl.person_id = p.person_id
	LEFT JOIN PER_GRADES_F_VL gr ON gr.grade_id = a.grade_id
WHERE 
    p.name_type = 'GLOBAL'
    AND :data_as_off BETWEEN p.effective_start_date AND p.effective_end_date
	AND :data_as_off BETWEEN ppl.effective_start_date AND ppl.effective_end_date
)

SELECT 
    Position.Position_Code, 
	Position.position_id,
	Position.Name, 
	Position.Employment_Type, 
	Position.ANZCO_Code, 
	Position.Occupational_Category, 
	Position.Leadership_Role, 
	Position.Leadership_tier,
	Position.Position_Under_Collective_Coverage_Flag, 
	Position.Location, 
	Position.Department,
    Position.Job, 	
	Position.Team_Group, 
	Position.Parent_Position_Name, 
	Position.cost_center, 
	Person.person_number,
	Person.Full_Name, 
	Person.person_id, 
	Person.Band, 
	Person.Employment_Type2, 
	pft.Assignment_Category,
    CASE
        WHEN Position.position_code IS NOT NULL AND Person.Full_Name IS NULL THEN 'Vacant'
        ELSE 'Occupied'
    END Position_status	
FROM 
    Position
	LEFT JOIN Person ON Person.position_id = Position.position_id
	LEFT JOIN (SELECT 
		           pa.person_id, 
				   pa.position_id, 
				   pa.assignment_id,
				   pa.Employment_Category,
				   hcm.meaning AS Assignment_Category
			   FROM 
				   PER_ALL_ASSIGNMENTS_M pa 
				   INNER JOIN HCM_LOOKUPS hcm ON hcm.lookup_code = pa.Employment_Category
			   WHERE 
				   hcm.lookup_type = 'EMP_CAT'
				   AND pa.assignment_type in('E','C')
				   AND pa.effective_latest_change = 'Y'
				   AND pa.assignment_status_type in ('ACTIVE','SUSPENDED')
				   AND :data_as_off BETWEEN pa.effective_start_date AND pa.effective_end_date 
			   )pft ON pft.person_id = person.person_id AND pft.position_id = position.position_id AND pft.position_id = person.position_id AND pft.assignment_id = person.assignment_id
ORDER BY 
    Position.Position_Code