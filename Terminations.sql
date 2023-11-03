WITH Person AS (
SELECT
	p.person_id,
    p.Full_Name,
	ppl.person_number,   
    pps.date_start,      
    pps.actual_termination_date,
    par.action_reason, 
    aa.assignment_number,
	aa.assignment_id,
	aa.assignment_name,
	aa.position_id, 
	aa.primary_flag,
    aa.Employment_Category, 
	aa.grade_id, 
	aa.assignment_status_type, 
    aa.action_code, 
    pas.manager_id, 
    pas.manager_assignment_id
FROM
    PER_PERSON_NAMES_F p
	INNER JOIN PER_PEOPLE_F ppl ON ppl.person_id = p.person_id
	INNER JOIN PER_PERIODS_OF_SERVICE pps ON pps.person_id = p.person_id 
    INNER JOIN PER_ACTION_OCCURRENCES pao ON pps.action_occurrence_id = pao.action_occurrence_id
    LEFT JOIN PER_ACTION_REASONS_VL par ON pao.action_reason_id = par.action_reason_id
    INNER JOIN PER_ALL_ASSIGNMENTS_M aa ON aa.person_id = p.person_id 
    INNER JOIN PER_ASSIGNMENT_SUPERVISORS_F_V pas ON pas.person_id = p.person_id AND pas.assignment_id = aa.assignment_id
WHERE
    p.name_type = 'GLOBAL'
    AND pps.period_of_service_id = (
                                    SELECT 
                                        MAX(period_of_service_id)
                                    FROM 
                                        per_periods_of_service ppof
                                    WHERE 
                                        ppof.person_id = p.person_id
                                    )
    AND pps.actual_termination_date < TRUNC(SYSDATE)
    AND TRUNC(SYSDATE) BETWEEN ppl.effective_start_date AND ppl.effective_end_date
    AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date
    AND aa.assignment_type IN ('E','C') 
    AND (aa.action_code = 'TERMINATION' AND aa.assignment_status_type = 'INACTIVE')  
    AND pps.actual_termination_date BETWEEN pas.effective_start_date AND pas.effective_end_date
    AND pps.actual_termination_date BETWEEN NVL (:DATE_FROM, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AND NVL (:DATE_TO, TO_DATE('01/01/2100', 'DD/MM/YYYY'))
), 

Position AS (
SELECT 
    Pos.Position_Code, 
    Pos.Name, 
	Pos.Position_ID, 
	Pos.full_part_time, 
	Pos.attribute6 AS Position_Type, 
    Pos.attribute2 AS ANZCO_Code, 
	Pos.attribute1 AS Occupational_Category,
	Pos.attribute4 AS Leadership_Role, 
	Pos.attribute5 AS Leadership_tier,
	Pos.attribute8 AS Team_Group,
    pos.effective_start_date AS pos_start_date,
    pos.effective_end_date AS pos_end_date,
    pd.effective_start_date AS dp_start_date,
    pd.effective_end_date AS dp_end_date,
    pd.name AS Department, 
    CASE
	    WHEN loc.internal_location_code IN ('WLG_L7', 'WLG_L8','WLG_L6', 'WLG_L9') THEN 'Wellington' 
		WHEN loc.internal_location_code IN ('AKL_L7', 'AKL_APO') THEN 'Auckland' 
		ELSE loc.Location_name
	END AS LOCATION,
	job.name AS Job 
FROM 
    HR_ALL_POSITIONS_F_VL pos
	LEFT JOIN PER_DEPARTMENTS pd ON pd.organization_id = pos.organization_id
	LEFT JOIN HR_LOCATIONS_ALL_F_VL loc ON loc.location_id = pos.location_id
	INNER JOIN PER_JOBS job ON job.job_id = pos.job_id   
), 

AssignmentCategory AS (
SELECT 
    pr.person_id, 
    pr.assignment_id, 
    pr.position_id, 
    hcm.meaning AS Assignment_Category
FROM 
    Person pr
    INNER JOIN HCM_LOOKUPS hcm ON hcm.lookup_code = pr.Employment_Category
WHERE 
    hcm.lookup_type = 'EMP_CAT'
)

SELECT 
    Person.person_id, 
    Person.Full_Name,
    Person.person_number,  
    TO_CHAR(Person.date_start, 'dd-MM-yyyy') AS Start_date, 
    TO_CHAR(Person.actual_termination_date, 'dd-MM-yyyy') AS Termination_Date, 
    Person.action_reason AS Termination_Reason,
    Person.assignment_id, 
    Person.assignment_number, 
    Person.assignment_name, 
    Person.position_id, 
    Person.grade_id, 
    Person.primary_flag, 
    Person.assignment_status_type, 
    Person.action_code, 
    Position.position_code, 
    Position.name, 
    Position.full_part_time, 
    Position.ANZCO_Code,
    Position.Occupational_Category, 
    Position.Leadership_Role, 
    Position.Leadership_tier, 
    Position.Team_Group, 
    Position.Department, 
    Position.Location, 
    Position.job,
    Mgr.Manager_Name, 
    Mgr.Manager_Number, 
    Mgr_pos.Manager_position_code,
    Mgr_Pos.Manager_position_Name, 
    ac.Assignment_Category
FROM 
    Person 
    INNER JOIN Position ON Person.position_id = Position.position_id
    INNER JOIN AssignmentCategory ac ON ac.person_id = person.person_id AND ac.assignment_id = person.assignment_id AND ac.position_id = position.position_id
    INNER JOIN (SELECT
                    ppn.person_id, 
                    ppn.full_name AS Manager_Name, 
                    ppf.person_number AS Manager_Number, 
                    ppn.effective_start_date AS name_start_date, 
                    ppn.effective_end_date AS name_end_date, 
                    ppf.effective_start_date AS per_start_date, 
                    ppf.effective_end_date AS per_end_date
                FROM 
                    PER_PERSON_NAMES_F ppn
	                INNER JOIN PER_PEOPLE_F ppf ON ppf.person_id = ppn.person_id 
                WHERE 
                    ppn.person_id IN (
                                    SELECT 
                                        DISTINCT person.manager_id
                                    FROM 
                                        Person
                                     )
                    AND ppn.name_type = 'GLOBAL'
                ) Mgr ON mgr.person_id = person.manager_id 
    INNER JOIN (SELECT 
                    paa.person_id,
                    paa.assignment_id, 
                    paa.position_id, 
                    paa.effective_start_date AS assignment_start_date, 
                    paa.effective_end_date AS assignment_end_date,
                    hap.position_code AS Manager_position_code, 
                    hap.name AS Manager_position_Name, 
                    hap.effective_start_date AS pos_start_date, 
                    hap.effective_end_date AS pos_end_date
                FROM 
                    PER_ALL_ASSIGNMENTS_M paa 
                    INNER JOIN HR_ALL_POSITIONS_F_VL hap ON hap.position_id = paa.position_id
                 WHERE
                    paa.assignment_id IN (
                                        SELECT 
                                            DISTINCT person.manager_assignment_id
                                        FROM 
                                            Person
                                         )
                    AND paa.assignment_type IN ('E','C')
                ) Mgr_Pos ON Mgr_pos.assignment_id = person.manager_assignment_id
WHERE 
    person.actual_termination_date BETWEEN position.pos_start_date AND position.pos_end_date
    AND person.actual_termination_date BETWEEN position.dp_start_date AND position.dp_end_date
    AND person.actual_termination_date BETWEEN Mgr.name_start_date AND Mgr.name_end_date
    AND person.actual_termination_date BETWEEN Mgr.per_start_date AND Mgr.per_end_date
    AND person.actual_termination_date BETWEEN Mgr_pos.assignment_start_date AND Mgr_pos.assignment_end_date
    AND person.actual_termination_date BETWEEN Mgr_pos.pos_start_date AND Mgr_pos.pos_end_date
ORDER BY 
    person.actual_termination_date