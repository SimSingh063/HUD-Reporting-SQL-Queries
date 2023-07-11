/* 
Title - All Staff Details
Author - Simranjeet Singh
Date - 15/06/2023
Description - Details of all active staff members within the organisation (This also includes people who are either 
on parental leave, internal/external secondment, leave without pay, etc)
*/

WITH Position AS (
SELECT 
    Pos.Position_Code, 
    Pos.Name, 
	Pos.Position_ID, 
	Pos.full_part_time, 
	Pos.attribute6 AS Position_Type, 
	Pos.attribute4 AS Leadership_Role, 
	Pos.attribute5 AS Leadership_tier,
	Pos.attribute8 AS Team_Group,
	pd.name AS Department, 
	loc.location_name AS Location, 
	job.name AS Job 
FROM 
    HR_ALL_POSITIONS_F_VL pos
	LEFT JOIN PER_DEPARTMENTS pd ON pd.organization_id = pos.organization_id
	LEFT JOIN HR_LOCATIONS_ALL_F_VL loc ON loc.location_id = pos.location_id
	INNER JOIN PER_JOBS job ON job.job_id = pos.job_id
WHERE 
    :data_as_off BETWEEN Pos.effective_start_date AND pos.effective_end_date
	AND :data_as_off BETWEEN pd.effective_start_date AND pd.effective_end_date
	AND pos.active_status = 'A' /*Filter all positions with an active status*/
), 

Person AS (
SELECT 
    a.*, 
	p.Full_Name,
	ppl.person_number,  
	gr.grade_code AS Band,  
	TO_CHAR(pps.date_start, 'DD/MM/YYYY') AS Start_date
FROM  
	(SELECT  
	    aa.person_id,
		aa.assignment_number,
		aa.assignment_id,
		aa.position_id, 
		aa.primary_flag, 
		aa.assignment_status_type AS Employment_Type,
		aa.grade_id, 
		aa.ass_attribute5 AS Employment_Agreement, 
        aa.ass_attribute2 AS Grandparenting, 
        aa.ass_attribute1 AS Personal_Union, 
        TO_CHAR(aa.Projected_assignment_end,'DD/MM/YYYY') AS Projected_End_Date,
        TO_CHAR(aa.ass_attribute_date1,'DD/MM/YYYY') AS Leave_return_date		
	FROM 
	     PER_ALL_ASSIGNMENTS_M aa
	WHERE 
		 aa.assignment_type in('E','C') 
		 AND :data_as_off BETWEEN aa.effective_start_date AND aa.effective_end_date 
		 AND aa.effective_latest_change = 'Y'
		 AND aa.assignment_status_type in ('ACTIVE','SUSPENDED') /*Only looking for assignments that have an Active or Suspended Status*/
	) a
 	INNER JOIN PER_PERSON_NAMES_F p ON p.person_id = a.person_id 
	INNER JOIN PER_PEOPLE_F ppl ON ppl.person_id = a.person_id
	LEFT JOIN PER_GRADES_F_VL gr ON gr.grade_id = a.grade_id
	INNER JOIN PER_PERIODS_OF_SERVICE pps ON pps.person_id = a.person_id 
WHERE 
    p.name_type = 'GLOBAL'
    AND :data_as_off BETWEEN p.effective_start_date AND p.effective_end_date
	AND :data_as_off BETWEEN ppl.effective_start_date AND ppl.effective_end_date
    AND (
	     (:data_as_off BETWEEN pps.date_start AND pps.actual_termination_date) 
		 OR 
		 (date_start <= :data_as_off AND pps.actual_termination_date IS NULL)
		)
	AND pps.Period_type IN ('E', 'C')
)

SELECT 
    Position.Position_Code, 
	Position.position_id,
	Position.Name, 
	CASE 
	   WHEN Position.full_part_time = 'FULL_TIME' THEN 'Full Time'
	   WHEN Position.full_part_time = 'PART_TIME' THEN 'Part Time'
	   ELSE Position.full_part_time
	END full_part_time, 
	Position.Position_Type,  
	Position.Leadership_Role, 
	Position.Leadership_tier,
	Position.Location, 
	Position.Department,
    Position.Team_Group, 
    Position.Job, 	
	Person.person_number,
	Person.Full_Name, 
	Person.person_id, 
	Person.assignment_number, 
	Person.Employment_Type, 
	Person.primary_flag, 
	Person.Band,
	Step.Step,
	Person.Employment_Agreement, 
	Person.Grandparenting, 
	Person.Personal_Union, 
	Person.Start_Date, 
	Person.Leave_return_date, 
	Person.Projected_End_Date, 
	pft.Assignment_Category,
	fte.FTE, 
	mgr.Manager_Name,
	mgr.Manager_Number, 
	mgr.Position_code AS Manager_position_code,
	mgr.Name AS Manager_position_Name, 
	sal.Annual_Ft_Salary,
	Salary_Amount
FROM 
    Position
	INNER JOIN Person ON Person.position_id = Position.position_id
	LEFT JOIN (SELECT DISTINCT
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
				   AND pa.assignment_status_type in ('ACTIVE','SUSPENDED')
				   AND pa.assignment_type in('E','C')
				   AND :data_as_off BETWEEN pa.effective_start_date AND pa.effective_end_date 
			   )pft ON pft.person_id = person.person_id AND pft.position_id = position.position_id AND pft.position_id = person.position_id AND pft.assignment_id = person.assignment_id
	LEFT JOIN (SELECT 
                   mgrd.person_id, 
				   mgrd.assignment_id, 
				   mgrd.manager_id, 
				   mgrn.person_number AS Manager_number, 
				   mgrn.full_name AS Manager_Name, 
				   mgrd.manager_assignment_id, 
				   mas.position_id,
				   mpos.position_code, 
				   mpos.Name 
               FROM
				   PER_ASSIGNMENT_SUPERVISORS_F_V mgrd 
				   INNER JOIN (SELECT
				                   DISTINCT pe.person_id, 
								   pe.full_name, 
								   pe.person_number
							   FROM 
							       Person pe 
							  )Mgrn ON mgrd.manager_id = mgrn.person_id   
				   INNER JOIN PER_ALL_ASSIGNMENTS_M mas ON mas.assignment_id = mgrd.manager_assignment_id AND mas.person_id = mgrd.manager_id 
				   INNER JOIN position mpos ON mpos.position_id = mas.position_id
			   WHERE	      
				   :data_as_off BETWEEN mgrd.effective_start_date AND mgrd.effective_end_date
				   AND :data_as_off BETWEEN mas.effective_start_date AND mas.effective_end_date
			  )mgr ON mgr.person_id = Person.person_id AND mgr.assignment_id = Person.assignment_id 
	LEFT JOIN (SELECT 
	               assigrd.*, 
				   grstp.name AS Step, 
				   grstp.grade_id
               FROM(			   
	                SELECT 
	                    asgrd.assignment_id, 
                        asgrd.grade_step_id				   
			        FROM 
			            PER_ASSIGN_GRADE_STEPS_F asgrd
			        WHERE 
			            :data_as_off BETWEEN asgrd.effective_start_date AND asgrd.effective_end_date
			       ) assigrd /* Managers do not follow a step model. Using this to get step information for Employees only */
				   LEFT JOIN PER_GRADE_STEPS_F_VL grstp ON grstp.grade_step_id = assigrd.grade_step_id
				WHERE 
				    :data_as_off BETWEEN grstp.effective_start_date AND grstp.effective_end_date    
			  )Step ON Step.assignment_id = person.assignment_id AND Step.grade_id = Person.grade_id
	LEFT JOIN (SELECT 
	                Fteval.value AS FTE, 
					Fteval.assignment_id
			   FROM 
				    PER_ASSIGN_WORK_MEASURES_F Fteval 
			   WHERE 
				    Fteval.unit = 'FTE'
					AND :data_as_off BETWEEN fteval.effective_start_date AND fteval.effective_end_date 
              ) Fte ON fte.assignment_id = person.assignment_id	
	LEFT JOIN (SELECT 
	               DISTINCT Person_ID, 
	               Assignment_ID,
                   Annual_Ft_Salary, 
	               FTE_Value, 
	               Grade_ID, 
	               Salary_Amount
               FROM 
                   cmp_salary cs
               WHERE 
                   assignment_type = 'E' /*Only looking for Salary for Permanent or Fixed Term Employees. Contractors and Consultants dont have a salary*/
	               AND :data_as_off BETWEEN cs.date_from AND cs.date_to
			   ) Sal ON Sal.person_id = Person.person_id AND Sal.Assignment_ID = Person.Assignment_ID AND Sal.Grade_ID = Person.Grade_ID