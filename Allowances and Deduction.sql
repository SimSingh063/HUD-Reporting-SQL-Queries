/* 
Title - Allowances and Deduction Report
Author - Simranjeet Singh
Date - 22/04/2024
Description - Details of all the allowances and deductions for staff members excluding HUD PSA Union Membership 
*/

WITH AllowanceDedution AS (
SELECT   
    *  
FROM (  
    SELECT   
        petf.base_element_name AS Element_Name,   
        TO_CHAR(peev.effective_start_date, 'dd-MM-yyyy') AS element_start_date,   
        TO_CHAR(peev.effective_end_date, 'dd-MM-yyyy') AS element_end_date,   
        peev.screen_entry_value,   
        pivf.base_name, 
        prgd.assignment_id, 
        flv.description
    FROM   
        pay_element_entries_f peef  
        INNER JOIN pay_element_types_f petf ON peef.element_type_id = petf.element_type_id  
        INNER JOIN pay_element_entry_values_f peev ON peef.element_entry_id = peev.element_entry_id  
        INNER JOIN pay_input_values_f pivf ON peef.element_type_id = pivf.element_type_id AND peev.input_value_id = pivf.input_value_id  
        LEFT JOIN fnd_lookup_values flv ON petf.base_element_name = flv.meaning   
        LEFT JOIN pay_entry_usages peu ON peef.element_entry_id = peu.element_entry_id  
        LEFT JOIN pay_rel_groups_dn prgd ON peu.payroll_relationship_id = prgd.payroll_relationship_id AND peu.payroll_assignment_id = prgd.relationship_group_id  
    WHERE   
        flv.lookup_type = 'HUD_ALLOWANCE_LIST'  
        AND flv.language = 'US'  
        AND petf.base_element_name <> 'HUD PSA Union Membership'
        AND (COALESCE(NULL, :Description_Type) IS NULL OR flv.description IN (:Description_Type))
        AND (COALESCE(NULL, :ElementName) IS NULL OR petf.base_element_name IN (:ElementName))
        AND (peev.effective_start_date >= :date_from OR :date_from BETWEEN peev.effective_start_date AND peev.effective_end_date)
        AND peev.effective_end_date >= :date_from
        AND (peev.effective_start_date <= (CASE 
                                            WHEN :date_to IS NOT NULL THEN :date_to 
                                           END
                                          )
        OR peev.effective_start_date <= (CASE
                                        WHEN :date_to IS NULL THEN SYSDATE 
                                        END
                                        )
        )
)  
PIVOT   
(  
    MAX(screen_entry_value)  
    FOR base_name   
    IN ('Amount' AS "Amount", 'Periodicity' AS "Periodicity")  
)  
), 

Assignment AS (
SELECT 
    assig.*, 
	ppn.Full_Name,
	ppf.person_number
FROM (
    SELECT 
        paa.assignment_id, 
        paa.assignment_name,
        paa.position_id, 
        paa.person_id, 
        pas.manager_id, 
        pas.manager_assignment_id
    FROM 
        per_all_assignments_m paa
        INNER JOIN per_assignment_supervisors_f_v pas ON pas.person_id = paa.person_id AND pas.assignment_id = paa.assignment_id
    WHERE 
        paa.assignment_id IN (
                            SELECT 
                                DISTINCT assignment_id 
                            FROM 
                                AllowanceDedution
                            )
        AND paa.assignment_type = 'E' 
	    AND paa.effective_latest_change = 'Y'
	    AND paa.assignment_status_type in ('ACTIVE','SUSPENDED')
        AND TRUNC(SYSDATE) BETWEEN paa.effective_start_date AND paa.effective_end_date
        AND TRUNC(SYSDATE) BETWEEN pas.effective_start_date AND pas.effective_end_date
    ) assig
    INNER JOIN per_person_names_f ppn ON ppn.person_id = assig.person_id 
	INNER JOIN per_people_f ppf ON ppf.person_id = assig.person_id
WHERE 
    ppn.name_type = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN ppn.effective_start_date AND ppn.effective_end_date
	AND TRUNC(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
), 

Position AS (
SELECT 
    Pos.Position_Code, 
    Pos.Name, 
	Pos.Position_id, 
    Pos.attribute8 AS Group_Team, 
    pdr.name AS Department
FROM 
    hr_all_positions_f_vl pos 
    LEFT JOIN per_departments pdr ON pdr.organization_id = pos.organization_id
WHERE 
    pos.position_id IN (SELECT 
                            DISTINCT position_id 
                        FROM 
                            Assignment
                        )
    AND TRUNC(SYSDATE) BETWEEN pos.effective_start_date AND pos.effective_end_date
    AND TRUNC(SYSDATE) BETWEEN pdr.effective_start_date AND pdr.effective_end_date
    AND pos.active_status = 'A' /* Filtering out only Active Positions */
), 

Fte AS (
    SELECT 
	    Fteval.value AS FTE, 
		Fteval.assignment_id
	FROM 
		per_assign_work_measures_f Fteval 
	WHERE
        fteval.assignment_id IN (
                                SELECT 
                                    DISTINCT assignment_id
                                FROM 
                                    Assignment
                                )
        AND Fteval.unit = 'FTE'
		AND TRUNC(SYSDATE) BETWEEN fteval.effective_start_date AND fteval.effective_end_date 
),

Salary AS (
SELECT
    csa.salary_amount AS Fte_salary_amount,
    csa.Annual_Ft_Salary AS Annual_Salary,
	csa.person_id, 
	csa.assignment_id,
	asg.grade_id 
FROM
	cmp_salary csa
	INNER JOIN per_all_assignments_m asg ON asg.assignment_id = csa.assignment_id
WHERE 
    csa.assignment_id IN (
                        SELECT 
                            DISTINCT assignment_id
                        FROM 
                            Assignment
                        )
    AND asg.effective_latest_change = 'Y'
	AND asg.assignment_type = 'E'
    AND csa.date_from BETWEEN asg.effective_start_date AND asg.effective_end_date
	AND TRUNC(SYSDATE) BETWEEN csa.date_from AND csa.date_to
)

SELECT 
    ad.*, 
    a.full_name,
    a.person_number, 
    a.person_id, 
    p.position_id, 
    p.position_code, 
    p.name AS position_name, 
    p.Group_Team, 
    p.Department, 
    f.FTE, 
    s.Fte_salary_amount, 
    s.Annual_Salary, 
    Mgr.Manager_Name, 
    Mgr.Manager_Number, 
    Mgr_pos.Manager_position_code,
    Mgr_Pos.Manager_position_Name
FROM 
    AllowanceDedution ad 
    INNER JOIN Assignment a ON a.assignment_id = ad.assignment_id
    INNER JOIN Position p ON p.position_id = a.position_id
    LEFT JOIN fte f ON f.assignment_id = ad.assignment_id AND f.assignment_id = a.assignment_id
    LEFT JOIN salary s ON s.assignment_id = ad.assignment_id AND s.assignment_id = a.assignment_id AND s.person_id = a.person_id
    INNER JOIN (SELECT
                    ppnf.person_id,
                    ppnf.full_name AS Manager_Name, 
                    pp.person_number AS Manager_Number
                FROM 
                    per_person_names_f ppnf
	                INNER JOIN per_people_f pp ON pp.person_id = ppnf.person_id 
                WHERE 
                    ppnf.person_id IN (
                                    SELECT 
                                        DISTINCT manager_id
                                    FROM 
                                        Assignment
                                     )
                    AND ppnf.name_type = 'GLOBAL'
                    AND TRUNC(SYSDATE) BETWEEN ppnf.effective_start_date AND ppnf.effective_end_date
                    AND TRUNC(SYSDATE) BETWEEN pp.effective_start_date AND pp.effective_end_date
                ) Mgr ON mgr.person_id = a.manager_id 
    INNER JOIN (SELECT 
                    paam.person_id,
                    paam.assignment_id, 
                    paam.position_id, 
                    hap.position_code AS Manager_position_code, 
                    hap.name AS Manager_position_Name
                FROM 
                    per_all_assignments_m paam
                    INNER JOIN hr_all_positions_f_vl hap ON hap.position_id = paam.position_id
                 WHERE
                    paam.assignment_id IN (
                                        SELECT 
                                            DISTINCT manager_assignment_id
                                        FROM 
                                            Assignment
                                         )
                    AND paam.assignment_type IN ('E','C')
                    AND TRUNC(SYSDATE) BETWEEN paam.effective_start_date AND paam.effective_end_date
                    AND TRUNC(SYSDATE) BETWEEN hap.effective_start_date AND hap.effective_end_date
                ) Mgr_Pos ON Mgr_pos.assignment_id = a.manager_assignment_id
ORDER BY 
    TO_DATE(ad.element_start_date, 'dd-MM-yyyy') DESC