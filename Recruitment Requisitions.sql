WITH Position AS (
SELECT 
    Pos.Position_Code, 
    Pos.Name, 
	Pos.Position_ID, 
    Pos.attribute8 AS Group_Team, 
    Pos.attribute6 AS Position_Type
FROM 
    HR_ALL_POSITIONS_F_VL pos 
WHERE 
    TRUNC(SYSDATE) BETWEEN pos.effective_start_date AND pos.effective_end_date
    AND pos.active_status = 'A' /* Filtering out only Active Positions */
), 

Assignment AS (
SELECT 
    paa.assignment_id, 
    paa.assignment_name,
    paa.position_id
FROM 
    PER_ALL_ASSIGNMENTS_M paa
WHERE 
    position_id IN (
                    SELECT 
                        DISTINCT position_id 
                    FROM 
                        position
                    )
    AND paa.assignment_type in('E','C') /* Only looking for people that have an assignment type E (Employee) OR C (Contactor or Consultant)*/ 
	AND paa.effective_latest_change = 'Y'
	AND paa.assignment_status_type in ('ACTIVE','SUSPENDED')
    AND TRUNC(SYSDATE) BETWEEN paa.effective_start_date AND paa.effective_end_date
), 

Rec_requisiton AS (
SELECT 
    irb.requisition_id, 
    irb.requisition_number, 
    TO_CHAR(irb.filled_date, 'dd-MM-yyyy') AS filled_date,
    TO_CHAR(irb.open_date, 'dd-MM-yyyy') AS Open_date, 
    ipv.name AS Requisition_Phase, 
    isv.name AS Requisition_State,
    req_sub.Submission_Phase AS Candidate_Phase,
    req_sub.Submission_State AS Candidate_State, 
    req_sub.last_update_date,  
    irb.hiring_manager_id, 
    irb.manager_assignment_id,  
    irb.worker_type_code,
    CASE 
        WHEN irb.full_part_time = 'FULL_TIME' THEN 'Full Time'
        WHEN irb.full_part_time = 'PART_TIME' THEN 'Part Time'
    END AS full_part_time,
    irb.job_id, 
    loc.location_name AS Location, 
    gr.grade_code AS Band, 
    pd.name AS Department,
    irb.position_id
FROM 
    irc_requisitions_b irb
    INNER JOIN irc_phases_vl ipv ON ipv.phase_id = irb.current_phase_id 
    INNER JOIN irc_states_vl isv ON isv.state_id = irb.current_state_id 
    LEFT JOIN PER_DEPARTMENTS pd ON pd.organization_id = irb.department_id
    LEFT JOIN HR_LOCATIONS_ALL_F_VL loc ON loc.location_id = irb.location_id
    LEFT JOIN PER_GRADES_F_VL gr ON gr.grade_id = irb.grade_id
    LEFT JOIN (
            SELECT 
                Sub_status.requisition_id,
                TO_CHAR(Sub_Status.last_update_date, 'dd-MM-yyyy') AS last_update_date, 
                irc.current_phase_id, 
                ipl.name AS Submission_Phase, 
                irc.current_state_id, 
                isl.name AS Submission_State 
            FROM(
                SELECT 
                    MAX(irs.last_update_date) AS last_update_date, 
                    irs.requisition_id
                FROM 
                    irc_submissions irs 
                GROUP BY 
                    irs.requisition_id 
                ) Sub_Status
                INNER JOIN irc_submissions irc ON irc.requisition_id = Sub_Status.requisition_id AND irc.last_update_date = Sub_Status.last_update_date
                INNER JOIN irc_phases_vl ipl ON ipl.phase_id = irc.current_phase_id 
                INNER JOIN irc_states_vl isl ON isl.state_id = irc.current_state_id 
            ) req_sub ON req_sub.requisition_id = irb.requisition_id
WHERE 
    isv.name NOT IN ('Canceled', 'Filled', 'Deleted')
    AND isv.type_code = 'REQUISITION'
    AND TRUNC(SYSDATE) BETWEEN pd.effective_start_date AND pd.effective_end_date
)

SELECT 
    position.Position_code,
    position.Name, 
    position.Group_Team, 
    position.position_type,
    assignment.assignment_id,
    assignment.assignment_name, 
    CASE 
        WHEN assignment.assignment_id IS NULL AND rr.requisition_id IS NOT NULL THEN 'Active-Recruitment'
        WHEN assignment.assignment_id IS NULL THEN 'Vacant'
        ELSE 'Occupied'
    END AS Pos_Status, 
    rr.*, 
    mgr.Hiring_manager_Name, 
    mgr.Hiring_manager_Number, 
    Mgr_Pos.Hiring_Manager_position_code, 
    Mgr_Pos.Hiring_Manager_position_Name
FROM
    position
    LEFT JOIN assignment ON assignment.position_id = position.position_id 
    LEFT JOIN Rec_requisiton rr ON rr.position_id = position.position_id 
    LEFT JOIN (
            SELECT
                ppn.person_id, 
                ppn.full_name AS Hiring_manager_Name, 
                ppf.person_number AS Hiring_manager_Number
            FROM 
                PER_PERSON_NAMES_F ppn
	            INNER JOIN PER_PEOPLE_F ppf ON ppf.person_id = ppn.person_id 
            WHERE 
                ppn.person_id IN (
                                SELECT 
                                    DISTINCT hiring_manager_id
                                FROM 
                                    Rec_requisiton
                                )
                AND ppn.name_type = 'GLOBAL'
                AND TRUNC(SYSDATE) BETWEEN ppn.effective_start_date AND ppn.effective_end_date
                AND TRUNC(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
            ) Mgr ON Mgr.person_id = rr.hiring_manager_id    
    LEFT JOIN (
            SELECT 
                paa.assignment_id, 
                paa.position_id, 
                hap.position_code AS Hiring_Manager_position_code, 
                hap.name AS Hiring_Manager_position_Name
            FROM 
                PER_ALL_ASSIGNMENTS_M paa 
                INNER JOIN HR_ALL_POSITIONS_F_VL hap ON hap.position_id = paa.position_id
            WHERE 
                paa.assignment_id IN (
                                    SELECT 
                                        DISTINCT manager_assignment_id
                                    FROM 
                                        Rec_requisiton
                                    )
                AND paa.assignment_type IN ('E','C')
                AND TRUNC(SYSDATE) BETWEEN paa.effective_start_date AND paa.effective_end_date
                AND TRUNC(SYSDATE) BETWEEN hap.effective_start_date AND hap.effective_end_date
           ) Mgr_Pos ON Mgr_pos.assignment_id = rr.manager_assignment_id
WHERE 
    CASE 
        WHEN assignment.assignment_id IS NULL AND rr.requisition_id IS NOT NULL THEN 'Active-Recruitment'
        WHEN assignment.assignment_id IS NULL THEN 'Vacant'
        ELSE 'Occupied'
    END IN ('Active-Recruitment', 'Vacant')
    AND (COALESCE(NULL, :Position_Status) IS NULL OR 
        CASE 
            WHEN assignment.assignment_id IS NULL AND rr.requisition_id IS NOT NULL THEN 'Active-Recruitment'
            WHEN assignment.assignment_id IS NULL THEN 'Vacant'
            ELSE 'Occupied'
        END
    IN (:Position_Status))  
    AND (COALESCE(NULL, :Team_Group) IS NULL OR position.Group_Team IN (:Team_Group))
    AND (COALESCE(NULL, :Req_Phase) IS NULL OR rr.Requisition_Phase IN (:Req_Phase))
    AND (COALESCE(NULL, :Can_Phase) IS NULL OR rr.Candidate_Phase IN (:Can_Phase))
ORDER BY 
    position.position_code