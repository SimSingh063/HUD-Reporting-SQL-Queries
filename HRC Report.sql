SELECT
    hrc.person_id,
    hrc.Full_Name,
    hrc.person_number,
    hrc.start_date,
    hrc.Termination_date,
    hrc.action_reason,
    hrc.TerminationReason,
    hrc.assignment_number,
    hrc.assignment_id,
    hrc.assignment_name,
    hrc.position_id,
    hrc.JobTitle,
    hrc.ANZSCO_Code,
    hrc.employment_category,
    hrc.grade_id,
    hrc.assignment_status_type,
    hrc.Band,
    hrc.Gender,
    hrc.date_of_birth,
    hrc.region,
    hrc.BusinessUnit,
    hrc.BusinessUnit2,
    hrc.salary_amount,
    hrc.annual_FT_salary,
    hrc.minimum,
    hrc.mid_value,
    hrc.maximum,
    hrc.fte,
    CASE 
        WHEN hrc.Ethnicity1 >= 90000 AND hrc.Ethnicity2 IS NOT NULL THEN hrc.Ethnicity2
        ELSE hrc.Ethnicity1
    END AS Ethnicity1,
    CASE
        WHEN hrc.Ethnicity1 = hrc.Ethnicity2 THEN NULL
        WHEN hrc.Ethnicity1 >= 90000 THEN NULL
        ELSE hrc.Ethnicity2
    END AS Ethnicity2,
    CASE
        WHEN hrc.Ethnicity2 = hrc.Ethnicity3 THEN NULL
        WHEN hrc.Ethnicity1 = hrc.Ethnicity3 THEN NULL
        WHEN hrc.Ethnicity1 >= 90000 THEN NULL
        ELSE hrc.Ethnicity3
    END AS Ethnicity3,
    hrc.status,
    hrc.ContractTerm,
    hrc.Manager_Number,
    hrc.ManagementProfile
FROM
    (
        SELECT
            assign.person_id,
            p.Full_Name,
            ppl.person_number,
            TO_CHAR(pps.date_start, 'dd/MM/yyyy') AS Start_date,
            NULL AS Termination_date,
            NULL AS action_reason,
            NULL AS TerminationReason,
            assign.assignment_number,
            assign.assignment_id,
            assign.assignment_name,
            assign.position_id,
            hrp.name AS JobTitle,
            hrp.attribute2 AS ANZSCO_Code,
            assign.employment_category,
            assign.grade_id,
            assign.assignment_status_type,
            CASE
                WHEN INSTR(gr.grade_code, 'Band_') = 1 THEN TO_CHAR(
                    TO_NUMBER(
                        SUBSTR(gr.grade_code, INSTR(gr.grade_code, 'Band_') + 5)
                    )
                )
                ELSE gr.grade_code
            END AS Band,
            (
                SELECT
                    CASE
                        WHEN ppl.sex = 'ORA_HRX_GENDER_DIVERSE' THEN 'A'
                        WHEN ppl.sex IS NULL THEN 'U'
                        ELSE ppl.sex
                    END AS sex
                FROM
                    per_people_legislative_f ppl
                WHERE
                    ppl.person_id = assign.person_id
                    AND TRUNC(SYSDATE) BETWEEN ppl.effective_start_date
                    AND ppl.effective_end_date
            ) Gender,
            (
                SELECT
                    TO_CHAR(pp.date_of_birth, 'dd/MM/yyyy') AS dob
                FROM
                    per_persons pp
                WHERE
                    pp.person_id = assign.person_id
            ) date_of_birth,
            CASE
                WHEN hla.internal_location_code IN ('WLG_L7', 'WLG_L8', 'WLG_L6', 'WLG_L9', 'PARLMT') THEN 9
                WHEN hla.internal_location_code IN ('AKL_L7', 'AKL_APO') THEN 2
                ELSE NULL
            END AS Region,
            hrp.attribute8 AS BusinessUnit,
            pd.name AS BusinessUnit2,
            sal.salary_amount,
            sal.annual_FT_salary,
            TRUNC(sal.minimum) AS minimum,
            TRUNC(sal.mid_value) AS mid_value,
            TRUNC(sal.maximum) AS maximum,
            (
                SELECT
                    Fteval.value
                FROM
                    per_assign_work_measures_F Fteval
                WHERE
                    Fteval.unit = 'FTE'
                    AND fteval.assignment_id = assign.assignment_id
                    AND TRUNC(SYSDATE) BETWEEN fteval.effective_start_date
                    AND fteval.effective_end_date
            ) Fte,
            COALESCE(
                (
                    SELECT
                        CASE
                            WHEN hl.meaning = 'African' THEN 53100
                            WHEN hl.meaning = 'Any Other' THEN 61199
                            WHEN hl.meaning = 'Asian' THEN 40000
                            WHEN hl.meaning = 'Chinese' THEN 42100
                            WHEN hl.meaning = 'Cook Islands Māori' THEN 32100
                            WHEN hl.meaning = 'European' THEN 10000
                            WHEN hl.meaning = 'Fijian' THEN 36111
                            WHEN hl.meaning = 'Indian' THEN 43100
                            WHEN hl.meaning = 'Latin American' THEN 52100
                            WHEN hl.meaning = 'Middle Eastern' THEN 51100
                            WHEN hl.meaning = 'Māori' THEN 21111
                            WHEN hl.meaning = 'New Zealand European' THEN 11111
                            WHEN hl.meaning = 'Niuean' THEN 34111
                            WHEN hl.meaning IS NULL
                            OR hl.meaning = 'Not Stated' THEN 99999
                            WHEN hl.meaning = 'Pacific Peoples' THEN 30000
                            WHEN hl.meaning = 'Samoan' THEN 31111
                            WHEN hl.meaning = 'South East Asian' THEN 41499
                            WHEN hl.meaning = 'Tokelauan' THEN 35111
                            WHEN hl.meaning = 'Tongan' THEN 33111
                        END AS Ethn
                    FROM
                        per_ethnicities pe
                        INNER JOIN hcm_lookups hl ON hl.lookup_code = pe.ethnicity
                        AND hl.lookup_type = 'PER_ETHNICITY'
                    WHERE
                        pe.person_id = assign.person_id
                ),
                99999
            ) Ethnicity1,
            COALESCE(
                (
                    SELECT
                        CASE
                            WHEN hl.meaning = 'African' THEN 53100
                            WHEN hl.meaning = 'Any Other' THEN 61199
                            WHEN hl.meaning = 'Asian' THEN 40000
                            WHEN hl.meaning = 'Chinese' THEN 42100
                            WHEN hl.meaning = 'Cook Islands Māori' THEN 32100
                            WHEN hl.meaning = 'European' THEN 10000
                            WHEN hl.meaning = 'Fijian' THEN 36111
                            WHEN hl.meaning = 'Indian' THEN 43100
                            WHEN hl.meaning = 'Latin American' THEN 52100
                            WHEN hl.meaning = 'Middle Eastern' THEN 51100
                            WHEN hl.meaning = 'Māori' THEN 21111
                            WHEN hl.meaning = 'New Zealand European' THEN 11111
                            WHEN hl.meaning = 'Niuean' THEN 34111
                            WHEN hl.meaning IS NULL
                            OR hl.meaning = 'Not Stated' THEN 99999
                            WHEN hl.meaning = 'Pacific Peoples' THEN 30000
                            WHEN hl.meaning = 'Samoan' THEN 31111
                            WHEN hl.meaning = 'South East Asian' THEN 41499
                            WHEN hl.meaning = 'Tokelauan' THEN 35111
                            WHEN hl.meaning = 'Tongan' THEN 33111
                        END AS Ethn
                    FROM
                        per_ethnicities pe
                        INNER JOIN hcm_lookups hl ON hl.lookup_code = pe.attribute1
                        AND hl.lookup_type = 'PER_ETHNICITY'
                    WHERE
                        pe.person_id = assign.person_id
                ),
                NULL
            ) Ethnicity2,
            COALESCE(
                (
                    SELECT
                        CASE
                            WHEN hl.meaning = 'African' THEN 53100
                            WHEN hl.meaning = 'Any Other' THEN 61199
                            WHEN hl.meaning = 'Asian' THEN 40000
                            WHEN hl.meaning = 'Chinese' THEN 42100
                            WHEN hl.meaning = 'Cook Islands Māori' THEN 32100
                            WHEN hl.meaning = 'European' THEN 10000
                            WHEN hl.meaning = 'Fijian' THEN 36111
                            WHEN hl.meaning = 'Indian' THEN 43100
                            WHEN hl.meaning = 'Latin American' THEN 52100
                            WHEN hl.meaning = 'Middle Eastern' THEN 51100
                            WHEN hl.meaning = 'Māori' THEN 21111
                            WHEN hl.meaning = 'New Zealand European' THEN 11111
                            WHEN hl.meaning = 'Niuean' THEN 34111
                            WHEN hl.meaning IS NULL
                            OR hl.meaning = 'Not Stated' THEN 99999
                            WHEN hl.meaning = 'Pacific Peoples' THEN 30000
                            WHEN hl.meaning = 'Samoan' THEN 31111
                            WHEN hl.meaning = 'South East Asian' THEN 41499
                            WHEN hl.meaning = 'Tokelauan' THEN 35111
                            WHEN hl.meaning = 'Tongan' THEN 33111
                        END AS Ethn
                    FROM
                        per_ethnicities pe
                        INNER JOIN hcm_lookups hl ON hl.lookup_code = pe.attribute2
                        AND hl.lookup_type = 'PER_ETHNICITY'
                    WHERE
                        pe.person_id = assign.person_id
                ),
                NULL
            ) Ethnicity3,
            CASE
                WHEN as_cat.assignment_Category = 'Substantive Position'
                OR as_cat.assignment_Category = 'Fixed Term' THEN 1
                WHEN as_cat.assignment_Category = 'Internal Secondment' THEN 2
                WHEN as_cat.assignment_Category = 'External Secondment' THEN 3
                WHEN as_cat.assignment_Category = 'Parental Leave' THEN 4
                WHEN as_cat.assignment_Category = 'Leave without Pay' THEN 5
            END AS Status,
            CASE
                WHEN assign.employment_category = 'HUD_FIX_TERM' THEN 1
                ELSE 2
            END AS ContractTerm,
            (
                SELECT
                    ppf.person_number
                FROM
                    per_people_f ppf
                WHERE
                    ppf.person_id = assign.manager_id
                    AND TRUNC(SYSDATE) BETWEEN ppf.effective_start_date
                    AND ppf.effective_end_date
            ) Manager_Number,
            (
                SELECT
                    CASE
                        WHEN hap.name LIKE 'Chief Executive%'
                        AND hrp.attribute4 = 'Y' THEN 2
                        WHEN hap.name LIKE 'Deputy Chief Executive%'
                        AND hap.attribute4 = 'Y'
                        AND hrp.attribute4 = 'Y' THEN 3
                        ELSE NULL
                    END AS MgtProfile
                FROM
                    per_all_assignments_m paa
                    INNER JOIN hr_all_positions_f_vl hap ON hap.position_id = paa.position_id
                WHERE
                    paa.assignment_id = assign.manager_assignment_id
                    AND paa.assignment_type IN ('E')
                    AND TRUNC(SYSDATE) BETWEEN hap.effective_start_date
                    AND hap.effective_end_date
                    AND TRUNC(SYSDATE) BETWEEN paa.effective_start_date
                    AND paa.effective_end_date
            ) ManagementProfile
        FROM
            (
                WITH assignment AS (
                    SELECT
                        aa.person_id,
                        aa.assignment_number,
                        aa.assignment_id,
                        aa.assignment_name,
                        aa.employment_category,
                        aa.primary_flag,
                        aa.position_id,
                        aa.assignment_status_type,
                        aa.grade_id,
                        aa.effective_start_date,
                        aa.effective_end_date,
                        pas.manager_id,
                        pas.manager_assignment_id
                    FROM
                        per_all_assignments_m aa
                        INNER JOIN per_assignment_supervisors_f_v pas ON pas.assignment_id = aa.assignment_id
                    WHERE
                        aa.assignment_type = 'E'
                        AND aa.effective_latest_change = 'Y'
                        AND aa.assignment_status_type <> 'INACTIVE'
                        AND (
                            aa.effective_start_date >= :DATE_FROM
                            OR :DATE_FROM BETWEEN aa.effective_start_date
                            AND aa.effective_end_date
                        )
                        AND aa.effective_end_date >= :DATE_FROM
                        AND (
                            aa.effective_start_date <= (
                                CASE
                                    WHEN :DATE_TO IS NOT NULL THEN :DATE_TO
                                END
                            )
                            OR aa.effective_start_date <= (
                                CASE
                                    WHEN :DATE_TO IS NULL THEN SYSDATE
                                END
                            )
                        )
                        AND TRUNC(SYSDATE) BETWEEN pas.effective_start_date
                        AND pas.effective_end_date --AND aa.person_id = 100000003277074
                ),
                latest_assignment AS (
                    SELECT
                        MAX(asi.effective_end_date) AS effective_end_date,
                        asi.person_id,
                        asi.assignment_id
                    FROM
                        assignment asi
                    GROUP BY
                        asi.person_id,
                        asi.assignment_id
                ),
                assignment_count AS (
                    SELECT
                        lass.person_id,
                        COUNT(lass.assignment_id) AS Assig_Count
                    FROM
                        latest_assignment lass
                    GROUP BY
                        lass.person_id
                )
                SELECT
                    DISTINCT asg.*
                FROM
                    assignment asg
                    INNER JOIN latest_assignment la ON la.person_id = asg.person_id
                    AND la.person_id = asg.person_id
                    AND la.effective_end_date = asg.effective_end_date
                    INNER JOIN assignment_count ac ON ac.person_id = asg.person_id
                WHERE
                    (
                        ac.Assig_Count = 1
                        AND asg.primary_flag = 'Y'
                        AND asg.assignment_status_type = 'ACTIVE'
                    )
                    OR(
                        ac.Assig_Count = 1
                        AND asg.primary_flag = 'Y'
                        AND asg.assignment_status_type = 'SUSPENDED'
                        AND (
                            asg.employment_category = 'HUD_LEAVE_WO_PAY'
                            OR asg.employment_category = 'HUD_PARENTAL_LEAVE'
                        )
                    )
                    OR (
                        ac.Assig_Count = 2
                        AND asg.primary_flag = 'N'
                        AND asg.assignment_status_type = 'SUSPENDED'
                    )
            ) Assign
            INNER JOIN per_person_names_f p ON p.person_id = assign.person_id
            INNER JOIN per_people_f ppl ON ppl.person_id = assign.person_id
            LEFT JOIN per_grades_f_vl gr ON gr.grade_id = assign.grade_id
            INNER JOIN per_periods_of_service pps ON pps.person_id = assign.person_id
            INNER JOIN hr_all_positions_f_vl hrp ON hrp.position_id = assign.position_id
            LEFT JOIN hr_locations_all_f_vl hla ON hla.location_id = hrp.location_id
            LEFT JOIN per_departments pd ON pd.organization_id = hrp.organization_id
            LEFT JOIN (
                SELECT
                    csa.salary_amount,
                    csa.Annual_Ft_Salary,
                    csa.person_id,
                    csa.assignment_id,
                    csa.FTE_Value,
                    csb.salary_basis_id,
                    asg.grade_id,
                    prv.minimum,
                    prv.maximum,
                    prv.mid_value
                FROM
                    cmp_salary csa
                    INNER JOIN per_all_assignments_m asg ON asg.assignment_id = csa.assignment_id
                    INNER JOIN cmp_salary_bases_vl csb ON csb.salary_basis_id = csa.salary_basis_id
                    INNER JOIN per_rate_values_f prv ON asg.grade_id = prv.rate_object_id
                    AND csb.grade_rate_id = prv.rate_id
                WHERE
                    asg.effective_latest_change = 'Y'
                    AND asg.assignment_type = 'E'
                    /*Only looking for Salary for Permanent or Fixed Term Employees. Contractors and Consultants dont have a salary*/
                    AND csa.date_from BETWEEN asg.effective_start_date
                    AND asg.effective_end_date
                    AND TRUNC(SYSDATE) BETWEEN csa.date_from
                    AND csa.date_to
            ) Sal ON sal.person_id = assign.person_id
            AND sal.assignment_id = assign.assignment_id
            AND sal.grade_id = assign.grade_id
            LEFT JOIN (
                SELECT
                    DISTINCT pa.person_id,
                    pa.position_id,
                    pa.assignment_id,
                    pa.Employment_Category,
                    hcm.meaning AS Assignment_Category
                FROM
                    per_all_assignments_m pa
                    INNER JOIN hcm_lookups hcm ON hcm.lookup_code = pa.Employment_Category
                WHERE
                    hcm.lookup_type = 'EMP_CAT'
                    AND pa.assignment_status_type in ('ACTIVE', 'SUSPENDED')
                    AND pa.assignment_type in('E')
                    AND TRUNC(SYSDATE) BETWEEN pa.effective_start_date
                    AND pa.effective_end_date
            ) as_cat ON as_cat.person_id = assign.person_id
            AND as_cat.position_id = assign.position_id
            AND as_cat.assignment_id = assign.assignment_id
        WHERE
            p.name_type = 'GLOBAL'
            AND TRUNC(SYSDATE) BETWEEN p.effective_start_date
            AND p.effective_end_date
            AND TRUNC(SYSDATE) BETWEEN ppl.effective_start_date
            AND ppl.effective_end_date
            AND (
                (
                    TRUNC(SYSDATE) BETWEEN pps.date_start
                    AND pps.actual_termination_date
                )
                OR (
                    pps.date_start <= TRUNC(SYSDATE)
                    AND pps.actual_termination_date IS NULL
                )
            )
            AND pps.Period_type = 'E'
            AND TRUNC(SYSDATE) BETWEEN hrp.effective_start_date
            AND hrp.effective_end_date
            AND TRUNC(SYSDATE) BETWEEN pd.effective_start_date
            AND pd.effective_end_date
        
        UNION ALL
        
        SELECT
            p.person_id,
            p.Full_Name,
            ppl.person_number,
            TO_CHAR(pps.date_start, 'dd/MM/yyyy') AS Start_date,
            TO_CHAR(pps.actual_termination_date, 'dd/MM/yyyy') AS Termination_date,
            par.action_reason,
            CASE
                WHEN action_reason = '10 Resignation – destination unknown' THEN 10
                WHEN action_reason = '11 Resignation to Public Service department' THEN 11
                WHEN action_reason = '12 Resignation other than to a Public Service department' THEN 12
                WHEN action_reason = '30 End of fixed term contract / agreement' THEN 30
                WHEN action_reason = '40 Restructuring' THEN 40
                WHEN action_reason = '41 Redeployment to an other organisation' THEN 41
                WHEN action_reason = '42 Severance' THEN 42
                WHEN action_reason = '43 Retraining' THEN 43
                WHEN action_reason = '44 Enhanced early retirement' THEN 44
                WHEN action_reason = '50 Dismissal' THEN 50
                WHEN action_reason = '60 Retirement' THEN 60
                WHEN action_reason = '70 Death' THEN 70
                WHEN action_reason = '99 Unknown'
                OR action_reason IS NULL THEN 99
            END AS TerminationReason,
            aa.assignment_number,
            aa.assignment_id,
            aa.assignment_name,
            aa.position_id,
            hrp.name AS JobTitle,
            hrp.attribute2 AS ANZCO_Code,
            aa.Employment_Category,
            aa.grade_id,
            aa.assignment_status_type,
            CASE
                WHEN INSTR(gr.grade_code, 'Band_') = 1 THEN TO_CHAR(
                    TO_NUMBER(
                        SUBSTR(gr.grade_code, INSTR(gr.grade_code, 'Band_') + 5)
                    )
                )
                ELSE gr.grade_code
            END AS Band,
            (
                SELECT
                    CASE
                        WHEN ppl.sex = 'ORA_HRX_GENDER_DIVERSE' THEN 'A'
                        WHEN ppl.sex IS NULL THEN 'U'
                        ELSE ppl.sex
                    END AS sex
                FROM
                    per_people_legislative_f ppl
                WHERE
                    ppl.person_id = aa.person_id
                    AND pps.actual_termination_date BETWEEN ppl.effective_start_date
                    AND ppl.effective_end_date
            ) Gender,
            (
                SELECT
                    TO_CHAR(pp.date_of_birth, 'dd/MM/yyyy') AS dob
                FROM
                    per_persons pp
                WHERE
                    pp.person_id = aa.person_id
            ) date_of_birth,
            CASE
                WHEN hla.internal_location_code IN ('WLG_L7', 'WLG_L8', 'WLG_L6', 'WLG_L9', 'PARLMT') THEN 9
                WHEN hla.internal_location_code IN ('AKL_L7', 'AKL_APO') THEN 2
                ELSE NULL
            END AS Region,
            hrp.attribute8 AS BusinessUnit,
            pd.name AS BusinessUnit2,
            sal.salary_amount,
            sal.annual_FT_salary,
            TRUNC(sal.minimum) AS minimum,
            TRUNC(sal.mid_value) AS mid_value,
            TRUNC(sal.maximum) AS maximum,
            (
                SELECT
                    Fteval.value
                FROM
                    per_assign_work_measures_F Fteval
                WHERE
                    Fteval.unit = 'FTE'
                    AND fteval.assignment_id = aa.assignment_id
                    AND pps.actual_termination_date BETWEEN fteval.effective_start_date
                    AND fteval.effective_end_date
            ) Fte,
            COALESCE(
                (
                    SELECT
                        CASE
                            WHEN hl.meaning = 'African' THEN 53100
                            WHEN hl.meaning = 'Any Other' THEN 61199
                            WHEN hl.meaning = 'Asian' THEN 40000
                            WHEN hl.meaning = 'Chinese' THEN 42100
                            WHEN hl.meaning = 'Cook Islands Māori' THEN 32100
                            WHEN hl.meaning = 'European' THEN 10000
                            WHEN hl.meaning = 'Fijian' THEN 36111
                            WHEN hl.meaning = 'Indian' THEN 43100
                            WHEN hl.meaning = 'Latin American' THEN 52100
                            WHEN hl.meaning = 'Middle Eastern' THEN 51100
                            WHEN hl.meaning = 'Māori' THEN 21111
                            WHEN hl.meaning = 'New Zealand European' THEN 11111
                            WHEN hl.meaning = 'Niuean' THEN 34111
                            WHEN hl.meaning IS NULL
                            OR hl.meaning = 'Not Stated' THEN 99999
                            WHEN hl.meaning = 'Pacific Peoples' THEN 30000
                            WHEN hl.meaning = 'Samoan' THEN 31111
                            WHEN hl.meaning = 'South East Asian' THEN 41499
                            WHEN hl.meaning = 'Tokelauan' THEN 35111
                            WHEN hl.meaning = 'Tongan' THEN 33111
                        END AS Ethn
                    FROM
                        per_ethnicities pe
                        INNER JOIN hcm_lookups hl ON hl.lookup_code = pe.ethnicity
                        AND hl.lookup_type = 'PER_ETHNICITY'
                    WHERE
                        pe.person_id = aa.person_id
                ),
                99999
            ) Ethnicity1,
            COALESCE(
                (
                    SELECT
                        CASE
                            WHEN hl.meaning = 'African' THEN 53100
                            WHEN hl.meaning = 'Any Other' THEN 61199
                            WHEN hl.meaning = 'Asian' THEN 40000
                            WHEN hl.meaning = 'Chinese' THEN 42100
                            WHEN hl.meaning = 'Cook Islands Māori' THEN 32100
                            WHEN hl.meaning = 'European' THEN 10000
                            WHEN hl.meaning = 'Fijian' THEN 36111
                            WHEN hl.meaning = 'Indian' THEN 43100
                            WHEN hl.meaning = 'Latin American' THEN 52100
                            WHEN hl.meaning = 'Middle Eastern' THEN 51100
                            WHEN hl.meaning = 'Māori' THEN 21111
                            WHEN hl.meaning = 'New Zealand European' THEN 11111
                            WHEN hl.meaning = 'Niuean' THEN 34111
                            WHEN hl.meaning IS NULL
                            OR hl.meaning = 'Not Stated' THEN 99999
                            WHEN hl.meaning = 'Pacific Peoples' THEN 30000
                            WHEN hl.meaning = 'Samoan' THEN 31111
                            WHEN hl.meaning = 'South East Asian' THEN 41499
                            WHEN hl.meaning = 'Tokelauan' THEN 35111
                            WHEN hl.meaning = 'Tongan' THEN 33111
                        END AS Ethn
                    FROM
                        per_ethnicities pe
                        INNER JOIN hcm_lookups hl ON hl.lookup_code = pe.attribute1
                        AND hl.lookup_type = 'PER_ETHNICITY'
                    WHERE
                        pe.person_id = aa.person_id
                ),
                NULL
            ) Ethnicity2,
            COALESCE(
                (
                    SELECT
                        CASE
                            WHEN hl.meaning = 'African' THEN 53100
                            WHEN hl.meaning = 'Any Other' THEN 61199
                            WHEN hl.meaning = 'Asian' THEN 40000
                            WHEN hl.meaning = 'Chinese' THEN 42100
                            WHEN hl.meaning = 'Cook Islands Māori' THEN 32100
                            WHEN hl.meaning = 'European' THEN 10000
                            WHEN hl.meaning = 'Fijian' THEN 36111
                            WHEN hl.meaning = 'Indian' THEN 43100
                            WHEN hl.meaning = 'Latin American' THEN 52100
                            WHEN hl.meaning = 'Middle Eastern' THEN 51100
                            WHEN hl.meaning = 'Māori' THEN 21111
                            WHEN hl.meaning = 'New Zealand European' THEN 11111
                            WHEN hl.meaning = 'Niuean' THEN 34111
                            WHEN hl.meaning IS NULL
                            OR hl.meaning = 'Not Stated' THEN 99999
                            WHEN hl.meaning = 'Pacific Peoples' THEN 30000
                            WHEN hl.meaning = 'Samoan' THEN 31111
                            WHEN hl.meaning = 'South East Asian' THEN 41499
                            WHEN hl.meaning = 'Tokelauan' THEN 35111
                            WHEN hl.meaning = 'Tongan' THEN 33111
                        END AS Ethn
                    FROM
                        per_ethnicities pe
                        INNER JOIN hcm_lookups hl ON hl.lookup_code = pe.attribute2
                        AND hl.lookup_type = 'PER_ETHNICITY'
                    WHERE
                        pe.person_id = aa.person_id
                ),
                NULL
            ) Ethnicity3,
            6 AS Status,
            CASE
                WHEN aa.employment_category = 'HUD_FIX_TERM' THEN 1
                ELSE 2
            END AS ContractTerm,
            (
                SELECT
                    ppf.person_number
                FROM
                    per_people_f ppf
                WHERE
                    ppf.person_id = pas.manager_id
                    AND pps.actual_termination_date BETWEEN ppf.effective_start_date
                    AND ppf.effective_end_date
            ) Manager_Number,
            (
                SELECT
                    CASE
                        WHEN hap.name LIKE 'Chief Executive%'
                        AND hrp.attribute4 = 'Y' THEN 2
                        WHEN hap.name LIKE 'Deputy Chief Executive%'
                        AND hap.attribute4 = 'Y'
                        AND hrp.attribute4 = 'Y' THEN 3
                        ELSE NULL
                    END AS MgtProfile
                FROM
                    per_all_assignments_m paa
                    INNER JOIN hr_all_positions_f_vl hap ON hap.position_id = paa.position_id
                WHERE
                    paa.assignment_id = pas.manager_assignment_id
                    AND paa.assignment_type IN ('E')
                    AND pps.actual_termination_date BETWEEN hap.effective_start_date
                    AND hap.effective_end_date
                    AND pps.actual_termination_date BETWEEN paa.effective_start_date
                    AND paa.effective_end_date
            ) ManagementProfile
        FROM
            per_person_names_f p
            INNER JOIN per_people_f ppl ON ppl.person_id = p.person_id
            INNER JOIN per_periods_of_service pps ON pps.person_id = p.person_id
            INNER JOIN per_action_occurrences pao ON pps.action_occurrence_id = pao.action_occurrence_id
            LEFT JOIN per_action_reasons_vl par ON pao.action_reason_id = par.action_reason_id
            INNER JOIN per_all_assignments_m aa ON aa.person_id = p.person_id
            LEFT JOIN per_grades_f_vl gr ON gr.grade_id = aa.grade_id
            INNER JOIN hr_all_positions_f_vl hrp ON hrp.position_id = aa.position_id
            LEFT JOIN hr_locations_all_f_vl hla ON hla.location_id = hrp.location_id
            LEFT JOIN per_departments pd ON pd.organization_id = hrp.organization_id
            INNER JOIN per_assignment_supervisors_f_v pas ON pas.assignment_id = aa.assignment_id
            LEFT JOIN (
                SELECT
                    csa.salary_amount,
                    csa.Annual_Ft_Salary,
                    csa.person_id,
                    csa.assignment_id,
                    csa.FTE_Value,
                    csb.salary_basis_id,
                    csa.date_from,
                    csa.date_to,
                    asg.grade_id,
                    prv.minimum,
                    prv.maximum,
                    prv.mid_value
                FROM
                    cmp_salary csa
                    INNER JOIN per_all_assignments_m asg ON asg.assignment_id = csa.assignment_id
                    INNER JOIN cmp_salary_bases_vl csb ON csb.salary_basis_id = csa.salary_basis_id
                    INNER JOIN per_rate_values_f prv ON asg.grade_id = prv.rate_object_id
                    AND csb.grade_rate_id = prv.rate_id
                WHERE
                    asg.effective_latest_change = 'Y'
                    AND asg.assignment_type = 'E'
                    AND csa.date_from BETWEEN asg.effective_start_date
                    AND asg.effective_end_date
            ) Sal ON sal.person_id = aa.person_id
            AND sal.assignment_id = aa.assignment_id
            AND sal.grade_id = aa.grade_id
        WHERE
            p.name_type = 'GLOBAL'
            AND aa.assignment_type = 'E'
            AND (
                aa.action_code = 'TERMINATION'
                AND aa.assignment_status_type = 'INACTIVE'
            )
            AND aa.primary_flag = 'Y'
            AND pps.actual_termination_date < TRUNC(SYSDATE)
            AND pps.period_of_service_id = (
                SELECT
                    MAX(period_of_service_id)
                FROM
                    per_periods_of_service ppof
                WHERE
                    ppof.person_id = p.person_id
            )
            AND TRUNC(SYSDATE) BETWEEN ppl.effective_start_date
            AND ppl.effective_end_date
            AND TRUNC(SYSDATE) BETWEEN p.effective_start_date
            AND p.effective_end_date
            AND pps.actual_termination_date BETWEEN hrp.effective_start_date
            AND hrp.effective_end_date
            AND pps.actual_termination_date BETWEEN pd.effective_start_date
            AND pd.effective_end_date
            AND pps.actual_termination_date BETWEEN pas.effective_start_date
            AND pas.effective_end_date
            AND (
                pps.actual_termination_date BETWEEN sal.date_from
                AND sal.date_to
                OR sal.date_from IS NULL
                OR sal.date_to IS NULL
            )
            AND pps.actual_termination_date BETWEEN NVL (:DATE_FROM, TO_DATE('01/01/1900', 'dd/MM/yyyy'))
            AND NVL (:DATE_TO, TO_DATE('01/01/2100', 'dd/MM/yyyy'))
    ) hrc
ORDER BY
    hrc.person_number