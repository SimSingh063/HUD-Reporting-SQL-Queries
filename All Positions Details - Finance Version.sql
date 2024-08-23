

 /* 
 Title - All Position Details (Finance Version)
 Author - Simranjeet Singh
 Date - 26/05/2023
 Description - Details of all occupied, vacant and position (excluding Finance positions incumbent salaries) in active recritment within the organisation.    
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
		Pos.attribute8 AS Group_Team,
		pd.name AS Department,
		grd.grade_code AS Band,
		prv.mid_value,
		CASE
			WHEN loc.internal_location_code IN ('WLG_L7', 'WLG_L8', 'WLG_L6', 'WLG_L9') THEN 'Wellington'
			WHEN loc.internal_location_code IN ('AKL_L7', 'AKL_APO') THEN 'Auckland'
			ELSE loc.Location_name
		END AS Location,
		job.name AS Job,
		fs.value AS Cost_Center,
		posp.parent_position_id,
		posp.Parent_Position_Name
	FROM
		hr_all_positions_f_vl pos
		LEFT JOIN per_departments pd ON pd.organization_id = pos.organization_id
		LEFT JOIN hr_locations_all_f_vl loc ON loc.location_id = pos.location_id
		INNER JOIN per_jobs job ON job.job_id = pos.job_id
		LEFT JOIN fnd_vs_values_b fs ON fs.value_id = pos.cost_center
		LEFT JOIN per_grades_f_vl grd ON grd.grade_id = pos.entry_grade_id
		LEFT JOIN per_rate_values_f prv ON pos.entry_grade_id = prv.rate_object_id
		LEFT JOIN (
			SELECT
				DISTINCT pph.parent_position_id,
				pph.position_id,
				ppos.Parent_Position_Name
			FROM
				per_position_hierarchy_f pph
				INNER JOIN (
					SELECT
						DISTINCT apos.position_id,
						apos.name AS Parent_Position_Name
					FROM
						hr_all_positions_f_vl apos
					WHERE
						:data_as_off BETWEEN apos.effective_start_date
						AND apos.effective_end_date
				) ppos ON ppos.position_id = pph.parent_position_id
			WHERE
				:data_as_off BETWEEN pph.effective_start_date
				AND pph.effective_end_date
		) posp ON posp.position_id = pos.position_id
	WHERE
		:data_as_off BETWEEN Pos.effective_start_date
		AND pos.effective_end_date
		AND :data_as_off BETWEEN pd.effective_start_date
		AND pd.effective_end_date
		AND pos.active_status = 'A'
		AND (
			:data_as_off BETWEEN prv.effective_start_Date
			AND prv.effective_end_date
			OR prv.effective_start_Date IS NULL
			OR prv.effective_end_date IS NULL
		)
),
Person AS (
	SELECT
		a.*,
		p.Full_Name,
		ppl.person_number
	FROM
		(
			SELECT
				aa.person_id,
				aa.assignment_number,
				aa.assignment_id,
				aa.assignment_name,
				aa.position_id,
				aa.primary_flag,
				aa.grade_id,
				aa.assignment_status_type AS Employment_Type2,
				TO_CHAR(aa.Projected_assignment_end, 'DD/MM/YYYY') AS Projected_End_Date
			FROM
				per_all_assignments_m aa
			WHERE
				aa.assignment_type in('E', 'C')
				AND :data_as_off BETWEEN aa.effective_start_date
				AND aa.effective_end_date
				AND aa.effective_latest_change = 'Y'
				AND aa.assignment_status_type in ('ACTIVE', 'SUSPENDED')
		) a
		INNER JOIN per_person_names_f p ON p.person_id = a.person_id
		INNER JOIN per_people_f ppl ON ppl.person_id = p.person_id --LEFT JOIN per_grades_f_vl gr ON gr.grade_id = a.grade_id
	WHERE
		p.name_type = 'GLOBAL'
		AND :data_as_off BETWEEN p.effective_start_date
		AND p.effective_end_date
		AND :data_as_off BETWEEN ppl.effective_start_date
		AND ppl.effective_end_date
),
Assignment_Category AS (
	SELECT
		pa.person_id,
		pa.position_id,
		pa.assignment_id,
		pa.Employment_Category,
		hcm.meaning AS Assignment_Category,
		(
			DENSE_RANK() OVER (
				ORDER BY
					hcm.meaning DESC
			)
		) AS Assignment_Rank
	FROM
		per_all_assignments_m pa
		INNER JOIN hcm_lookups hcm ON hcm.lookup_code = pa.Employment_Category
	WHERE
		pa.assignment_id IN (
			SELECT
				DISTINCT assignment_id
			FROM
				person
		)
		AND hcm.lookup_type = 'EMP_CAT'
		AND pa.assignment_type in('E', 'C')
		AND pa.effective_latest_change = 'Y'
		AND pa.assignment_status_type in ('ACTIVE', 'SUSPENDED')
		AND :data_as_off BETWEEN pa.effective_start_date
		AND pa.effective_end_date
),
Salary AS (
	SELECT
		csa.salary_amount,
		csa.Annual_Ft_Salary,
		csa.person_id,
		csa.assignment_id,
		csa.FTE_Value,
		asg.grade_id
	FROM
		cmp_salary csa
		INNER JOIN per_all_assignments_m asg ON asg.assignment_id = csa.assignment_id
	WHERE
		asg.assignment_id IN (
			SELECT
				DISTINCT assignment_id
			FROM
				person
		)
		AND asg.effective_latest_change = 'Y'
		AND asg.assignment_type = 'E'
		AND csa.date_from BETWEEN asg.effective_start_date
		AND asg.effective_end_date
		AND :data_as_off BETWEEN csa.date_from
		AND csa.date_to
),
Rec_requisiton AS (
	SELECT
		irb.requisition_id,
		irb.requisition_number,
		TO_CHAR(irb.filled_date, 'dd-MM-yyyy') AS filled_date,
		TO_CHAR(irb.open_date, 'dd-MM-yyyy') AS Open_date,
		ipv.name AS Requisition_Phase,
		isv.name AS Requisition_State,
		irb.worker_type_code,
		irb.job_id,
		gr.grade_code AS Band,
		irb.position_id
	FROM
		irc_requisitions_b irb
		INNER JOIN irc_phases_vl ipv ON ipv.phase_id = irb.current_phase_id
		INNER JOIN irc_states_vl isv ON isv.state_id = irb.current_state_id
		LEFT JOIN PER_GRADES_F_VL gr ON gr.grade_id = irb.grade_id
	WHERE
		isv.name NOT IN ('Canceled', 'Filled', 'Deleted')
		AND isv.type_code = 'REQUISITION'
		AND ipv.type_code = 'REQUISITION'
),
ranked_person AS (
	SELECT
		Person.*,
		ac.Assignment_Category,
		ac.Assignment_Rank,
		sal.salary_amount,
		sal.annual_FT_salary,
		sal.FTE_Value,
		ROW_NUMBER() OVER (
			PARTITION BY Person.position_id
			ORDER BY
				ac.Assignment_Rank
		) AS row_num
	FROM
		Person
		LEFT JOIN Assignment_Category ac ON ac.person_id = person.person_id
		AND ac.position_id = person.position_id
		AND ac.assignment_id = person.assignment_id
		LEFT JOIN Salary sal ON Sal.person_id = Person.person_id
		AND Sal.Assignment_ID = Person.Assignment_ID
		AND Sal.Grade_ID = Person.Grade_ID
),
cost_center_hierarchy AS (
	SELECT
		a.*,
		ffv3.description AS cc_group_desc
	FROM
		(
			SELECT
				DISTINCT dce.pk1_start_value AS DCE_Group,
				ffv.description AS dec_group_desc,
				CASE
					WHEN gm.depth = 1 THEN gm.pk1_start_value
					ELSE NULL
				END AS GM_Group,
				CASE
					WHEN gm.depth = 1 THEN ffv2.description
					ELSE NULL
				END AS gm_group_desc,
				CASE
					WHEN gm.depth = 2 THEN gm.pk1_start_value
					ELSE cc.pk1_start_value
				END AS cost_center
			FROM
				fnd_tree_node dce
				LEFT JOIN fnd_tree_node gm ON dce.tree_node_id = gm.parent_tree_node_id
				AND dce.tree_version_id = gm.tree_version_id
				AND dce.depth < gm.depth
				LEFT JOIN fnd_tree_node cc ON gm.tree_node_id = cc.parent_tree_node_id
				AND gm.tree_version_id = cc.tree_version_id
				AND gm.depth < cc.depth
				LEFT JOIN fnd_flex_values_vl ffv ON dce.pk1_start_value = ffv.flex_value
				LEFT JOIN fnd_flex_values_vl ffv2 ON gm.pk1_start_value = ffv2.flex_value
			WHERE
				dce.tree_structure_code = 'GL_ACCT_FLEX'
				AND dce.tree_code = 'HUD COST CENTER'
				AND dce.parent_tree_node_id IS NULL
				AND ffv.value_category = 'HUD_COST_CENTER'
				AND ffv2.value_category = 'HUD_COST_CENTER'
				AND dce.tree_version_id IN (
					SELECT
						ftv.tree_version_id
					FROM
						fnd_tree_version_vl ftv
					WHERE
						ftv.tree_structure_code = 'GL_ACCT_FLEX'
						AND ftv.tree_code = 'HUD COST CENTER'
						AND ftv.status = 'ACTIVE'
						AND TRUNC(SYSDATE) BETWEEN ftv.effective_start_date
						AND ftv.effective_end_date
				)
				AND ffv.description NOT IN 'Historical Cost Centres'
		) a
		LEFT JOIN fnd_flex_values_vl ffv3 ON a.cost_center = ffv3.flex_value
	WHERE
		ffv3.value_category = 'HUD_COST_CENTER'
),
pivoted_person AS (
	SELECT
		position_id,
		MAX(
			CASE
				WHEN row_num = 1 THEN person_number
			END
		) AS person_number,
		MAX(
			CASE
				WHEN row_num = 1 THEN Full_Name
			END
		) AS Full_Name,
		MAX(
			CASE
				WHEN row_num = 1 THEN person_id
			END
		) AS person_id,
		MAX(
			CASE
				WHEN row_num = 1 THEN Employment_Type2
			END
		) AS Employment_Type2,
		MAX(
			CASE
				WHEN row_num = 1 THEN Assignment_Category
			END
		) AS Assignment_Category,
		MAX(
			CASE
				WHEN row_num = 1 THEN Assignment_Rank
			END
		) AS Assignment_Rank,
		MAX(
			CASE
				WHEN row_num = 1 THEN Assignment_id
			END
		) AS Assignment_id,
		MAX(
			CASE
				WHEN row_num = 1 THEN Projected_End_Date
			END
		) AS Projected_End_Date,
		MAX(
			CASE
				WHEN row_num = 1 THEN Annual_Ft_Salary
			END
		) AS Annual_Ft_Salary,
		MAX(
			CASE
				WHEN row_num = 1 THEN salary_amount
			END
		) AS salary_amount,
		MAX(
			CASE
				WHEN row_num = 1 THEN FTE_Value
			END
		) AS FTE_Value,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN person_number
			END
		) AS Secondary_Person_Number,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN Full_Name
			END
		) AS Secondary_Full_Name,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN person_id
			END
		) AS Secondary_Person_Id,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN Employment_Type2
			END
		) AS Secondary_Employment_Type2,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN Assignment_Category
			END
		) AS Secondary_Assignment_Category,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN Assignment_Rank
			END
		) AS Secondary_Assignment_Rank,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN Assignment_id
			END
		) AS Secondary_Assignment_id,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN Projected_End_Date
			END
		) AS Secondary_Projected_End_Date,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN Annual_Ft_Salary
			END
		) AS Secondary_Annual_FT_salary,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN salary_amount
			END
		) AS Secondary_salary_amount,
		MAX(
			CASE
				WHEN row_num IN (2, 3, 4, 5, 6, 7, 8) THEN FTE_Value
			END
		) AS Secondary_FTE_Value
	FROM
		ranked_person
	GROUP BY
		position_id
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
	Position.Group_Team,
	Position.Parent_Position_Name,
	Position.cost_center,
	cch.DCE_Group, 
	cch.dec_group_desc, 
	cch.GM_Group, 
	cch.gm_group_desc,
	cch.cc_group_desc,
	Position.Band,
	Position.mid_value,
	1 AS Position_FTE,
	pp.person_number,
	pp.Full_Name,
	pp.person_id,
	pp.Employment_Type2,
	pp.Assignment_Category,
	pp.Assignment_Rank,
	pp.Projected_End_Date,
	CASE 
	    WHEN Position.Department IN ('Finance Reporting and Control', 'Financial Performance and Planning', 'Finance') THEN NULL
		ELSE pp.annual_FT_salary
	END AS annual_FT_salary,
	CASE 
	    WHEN Position.Department IN ('Finance Reporting and Control', 'Financial Performance and Planning', 'Finance') THEN NULL
		ELSE pp.salary_amount
	END AS salary_amount,
	pp.FTE_Value,
	pp.Secondary_Person_Number,
	pp.Secondary_Full_Name,
	pp.secondary_person_id,
	pp.secondary_Employment_Type2,
	pp.secondary_Assignment_Category,
	pp.secondary_Assignment_Rank,
	pp.Secondary_Projected_End_Date,
	CASE 
	    WHEN Position.Department IN ('Finance Reporting and Control', 'Financial Performance and Planning', 'Finance') THEN NULL
		ELSE pp.secondary_annual_FT_salary
	END AS secondary_annual_FT_salary,
	CASE 
	    WHEN Position.Department IN ('Finance Reporting and Control', 'Financial Performance and Planning', 'Finance') THEN NULL
		ELSE pp.secondary_salary_amount
	END AS secondary_salary_amount,
	pp.secondary_FTE_Value,
	CASE
		WHEN pp.Employment_Type2 = 'ACTIVE'
		AND pp.Secondary_Employment_Type2 IS NULL THEN 'Position Occupied'
		WHEN pp.Employment_Type2 = 'ACTIVE'
		AND pp.Secondary_Employment_Type2 = 'ACTIVE' THEN 'Position Occupied'
		WHEN pp.Employment_Type2 = 'SUSPENDED'
		AND pp.Secondary_Employment_Type2 IS NULL THEN 'Position Suspended'
		WHEN pp.Employment_Type2 = 'SUSPENDED'
		AND pp.Secondary_Employment_Type2 = 'ACTIVE' THEN 'Position Backfilled'
		WHEN pp.Employment_Type2 = 'ACTIVE'
		AND pp.Secondary_Employment_Type2 = 'SUSPENDED' THEN 'Position Backfilled'
		WHEN pp.assignment_id IS NULL
		AND position.position_id IS NOT NULL
		AND rr.requisition_id IS NOT NULL THEN 'Position in Active-Recruitment'
		WHEN pp.assignment_id IS NULL
		AND position.position_id IS NOT NULL
		AND rr.requisition_id IS NULL THEN 'Position Vacant'
		ELSE NULL
	END AS Position_status
FROM
	Position
	LEFT JOIN pivoted_person pp ON pp.position_id = Position.position_id
	LEFT JOIN Rec_requisiton rr ON rr.position_id = position.position_id
	LEFT JOIN cost_center_hierarchy cch ON cch.cost_center = Position.cost_center
WHERE
	(
		COALESCE(NULL, :Team_Group) IS NULL
		OR position.Group_Team IN (:Team_Group)
	)
	AND (
		COALESCE(NULL, :Dpmt) IS NULL
		OR position.Department IN (:Dpmt)
	)
	AND (
		COALESCE(NULL, :Salary_Band) IS NULL
		OR position.Band IN (:Salary_Band)
	)
	AND (
		COALESCE(NULL, :Position_Type) IS NULL
		OR Position.Employment_Type IN (:Position_Type)
	)
ORDER BY
	Position.Position_Code



/*------------------------------------------FILTERS------------------------------------------------------*/

--Position Type 
SELECT 
    DISTINCT attribute6
FROM 
    hr_all_positions_f_vl
ORDER BY 
    attribute6

--Salary Band 
SELECT 
    DISTINCT grade_code
FROM
    hr_all_positions_f_vl pos
    LEFT JOIN per_grades_f_vl grd ON grd.grade_id = pos.entry_grade_id
ORDER BY 
    grade_code

--Department 
SELECT 
    DISTINCT pd.name 
FROM
    hr_all_positions_f_vl pos
    INNER JOIN per_departments pd ON pd.organization_id = pos.organization_id
WHERE 
    pos.active_status = 'A'
    AND pos.attribute8 IN (:Team_Group)
ORDER BY 
    pd.name
