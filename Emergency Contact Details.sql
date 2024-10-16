WITH Person AS (
    SELECT
        a.*,
        p.Full_Name,
        ppl.person_number,
        pas.manager_id
    FROM
        (
            SELECT
                aa.person_id,
                aa.assignment_number,
                aa.assignment_id,
                aa.assignment_name,
                aa.position_id,
                aa.primary_flag,
                aa.assignment_status_type AS Assignment_status
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
        INNER JOIN per_all_people_f ppl ON ppl.person_id = p.person_id
        INNER JOIN per_assignment_supervisors_f_v pas ON pas.person_id = p.person_id
        AND pas.assignment_id = a.assignment_id
    WHERE
        p.name_type = 'GLOBAL'
        AND :data_as_off BETWEEN p.effective_start_date
        AND p.effective_end_date
        AND :data_as_off BETWEEN ppl.effective_start_date
        AND ppl.effective_end_date
        AND :data_as_off BETWEEN pas.effective_start_date
        AND pas.effective_end_date --AND p.person_id = 300000013233385 -- 300000009316735
),
Contact_relationship AS (
    SELECT
        pcr.person_id,
        pcr.contact_person_id
    FROM
        per_contact_relationships pcr
    WHERE
        EXISTS (
            SELECT
                DISTINCT person_id
            FROM
                person
            WHERE
                person.person_id = pcr.person_id
        )
        AND pcr.emergency_contact_flag = 'Y'
),
Emergency_Contact AS (
    SELECT
        pc.person_id,
        pc.contact_person_id,
        pc.contact_type,
        p.full_name AS Emergency_Contact_name,
        pp.phone_number AS Emergency_contact_phn_no
    FROM
        per_contact_relationships pc
        INNER JOIN per_person_names_f p ON p.person_id = pc.contact_person_id
        LEFT JOIN per_phones pp ON pp.person_id = pc.contact_person_id
    WHERE
        pc.contact_person_id IN (
            SELECT
                DISTINCT contact_person_id
            FROM
                Contact_relationship
        )
        AND p.name_type = 'GLOBAL'
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
Position AS (
    SELECT
        Pos.Position_Code,
        Pos.Name,
        Pos.Position_ID,
        Pos.attribute8 AS Group_Team,
        pd.name AS Department,
        CASE
            WHEN loc.internal_location_code IN ('WLG_L7', 'WLG_L8', 'WLG_L6', 'WLG_L9') THEN 'Wellington'
            WHEN loc.internal_location_code IN ('AKL_L7', 'AKL_APO') THEN 'Auckland'
            ELSE loc.Location_name
        END AS Location
    FROM
        hr_all_positions_f_vl pos
        LEFT JOIN per_departments pd ON pd.organization_id = pos.organization_id
        LEFT JOIN hr_locations_all_f_vl loc ON loc.location_id = pos.location_id
    WHERE
        :data_as_off BETWEEN Pos.effective_start_date
        AND pos.effective_end_date
        AND :data_as_off BETWEEN pd.effective_start_date
        AND pd.effective_end_date
        AND pos.active_status = 'A'
),
Manager AS (
    SELECT
        ppn.person_id,
        ppn.full_name AS Manager_Name,
        ppf.person_number AS Manager_Number
    FROM
        per_person_names_f ppn
        INNER JOIN per_all_people_f ppf ON ppf.person_id = ppn.person_id
    WHERE
        ppn.person_id IN (
            SELECT
                DISTINCT manager_id
            FROM
                Person
        )
        AND ppn.name_type = 'GLOBAL'
        AND :data_as_off BETWEEN ppn.effective_start_date
        AND ppn.effective_end_date
        AND :data_as_off BETWEEN ppf.effective_start_date
        AND ppf.effective_end_date
),
ranked_person AS (
    SELECT
        Person.*,
        ac.Assignment_Category,
        ac.Assignment_Rank,
        mgr.Manager_Name,
        mgr.Manager_Number,
        p.Group_Team,
        p.Department,
        p.location,
        ROW_NUMBER() OVER (
            PARTITION BY Person.person_id
            ORDER BY
                ac.Assignment_Rank
        ) AS row_num
    FROM
        Person
        LEFT JOIN Assignment_Category ac ON ac.person_id = person.person_id
        AND ac.position_id = person.position_id
        AND ac.assignment_id = person.assignment_id
        LEFT JOIN Manager mgr ON mgr.person_id = person.manager_id
        INNER JOIN position p ON p.position_id = person.position_id
),
pivoted_person AS (
    SELECT
        rp.person_id,
        rp.full_name,
        rp.person_number,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.assignment_number
            END
        ) AS primary_assignment_number,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.Assignment_Category
            END
        ) AS Primary_assignment_category,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.primary_flag
            END
        ) AS primary_flag,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.Assignment_status
            END
        ) AS Primary_Assignment_status,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.Department
            END
        ) AS Primary_Department,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.Group_Team
            END
        ) AS Primary_Group,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.location
            END
        ) AS Primary_location,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.Manager_Name
            END
        ) AS Primary_Manager_Name,
        MAX(
            CASE
                WHEN rp.row_num = 1 THEN rp.Manager_Number
            END
        ) AS Primary_Manager_Number,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.assignment_number
            END
        ) AS Secondary_Assignment_number,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.Assignment_Category
            END
        ) AS Secondary_Assignment_Category,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.Assignment_name
            END
        ) AS Secondary_Assignment_Name,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.primary_flag
            END
        ) AS Secondary_flag,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.Assignment_status
            END
        ) AS Secondary_Assignment_status,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.Department
            END
        ) AS Secondary_department,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.Group_Team
            END
        ) AS Secondary_Group,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.location
            END
        ) AS Secondary_location,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.Manager_Name
            END
        ) AS Secondary_manager_name,
        MAX(
            CASE
                WHEN rp.row_num IN (2, 3, 4, 5, 6, 7, 8) THEN rp.Manager_Number
            END
        ) AS Secondary_manager_number
    FROM
        ranked_person rp
    GROUP BY
        rp.person_id,
        rp.full_name,
        rp.person_number
),
ranked_contact_relationship AS (
    SELECT
        ec.*,
        mail.email_address,
        pp.phone_number,
        adrs.address_line_1,
        adrs.Suburb,
        adrs.City,
        adrs.postal_code,
        adrs.country,
        adrs.address_id,
        ROW_NUMBER() OVER (
            PARTITION BY ec.person_id
            ORDER BY
                ec.contact_person_id
        ) AS contact_row_num
    FROM
        Contact_relationship cr
        INNER JOIN Emergency_Contact ec ON ec.contact_person_id = cr.contact_person_id
        LEFT JOIN (
            SELECT
                addr.person_id,
                ppu.address_id,
                CASE
                    WHEN paf.address_line_2 IS NULL THEN paf.address_line_1
                    ELSE paf.address_line_1 || ',' || paf.address_line_2
                END AS address_line_1,
                paf.address_line_3 AS Suburb,
                paf.town_or_city AS City,
                paf.postal_code,
                paf.country
            FROM
                (
                    SELECT
                        ppd.person_id,
                        MAX(ppd.effective_start_date) AS effective_start_date
                    FROM
                        per_person_addr_usages_f ppd
                    where
                        :data_as_off BETWEEN ppd.effective_start_date
                        AND ppd.effective_end_date
                        AND ppd.address_type = 'HOME'
                    GROUP BY
                        ppd.person_id
                ) addr
                INNER JOIN per_person_addr_usages_f ppu ON ppu.person_id = addr.person_id
                AND ppu.effective_start_date = addr.effective_start_date
                INNER JOIN per_addresses_f paf ON paf.address_id = ppu.address_id
            WHERE
                :data_as_off BETWEEN paf.effective_start_date
                AND paf.effective_end_date
        ) adrs ON adrs.person_id = ec.person_id
        LEFT JOIN per_phones pp ON pp.person_id = ec.person_id
        LEFT JOIN (
            SELECT
                ea.person_id,
                pe.email_address
            FROM
                (
                    SELECT
                        em_ad.person_id,
                        MAX(em_ad.date_from) AS date_from
                    FROM
                        (
                            SELECT
                                pea.email_address,
                                pea.email_address_id,
                                pea.date_from,
                                pea.person_id
                            FROM
                                per_email_addresses pea
                            WHERE
                                pea.email_type = 'H1'
                        ) em_ad
                    GROUP BY
                        em_ad.person_id
                ) ea
                INNER JOIN per_email_addresses pe ON pe.person_id = ea.person_id
                AND pe.date_from = ea.date_from
        ) mail ON mail.person_id = ec.person_id
    WHERE
        pp.phone_type = 'HM'
),
pivoted_ranked_relationship AS (
    SELECT
        rcr.person_id,
        rcr.phone_number,
        rcr.email_address,
        rcr.address_line_1,
        rcr.Suburb,
        rcr.City,
        rcr.postal_code,
        rcr.country,
        MAX(
            CASE
                WHEN rcr.contact_row_num = 1 THEN rcr.Emergency_Contact_name
            END
        ) AS Emergency_Contact_name1,
        MAX(
            CASE
                WHEN rcr.contact_row_num = 1 THEN rcr.contact_type
            END
        ) AS contact_type1,
        MAX(
            CASE
                WHEN rcr.contact_row_num = 1 THEN rcr.Emergency_contact_phn_no
            END
        ) AS Emergency_contact_phn_no1,
        MAX(
            CASE
                WHEN rcr.contact_row_num = 2 THEN rcr.Emergency_Contact_name
            END
        ) AS Emergency_Contact_name2,
        MAX(
            CASE
                WHEN rcr.contact_row_num = 2 THEN rcr.contact_type
            END
        ) AS contact_type2,
        MAX(
            CASE
                WHEN rcr.contact_row_num = 2 THEN rcr.Emergency_contact_phn_no
            END
        ) AS Emergency_contact_phn_no2
    FROM
        ranked_contact_relationship rcr
    GROUP BY
        rcr.person_id,
        rcr.phone_number,
        rcr.email_address,
        rcr.address_line_1,
        rcr.Suburb,
        rcr.City,
        rcr.postal_code,
        rcr.country
)
SELECT
    pip.*,
    prr.phone_number,
    prr.email_address,
    prr.address_line_1,
    prr.Suburb,
    prr.City,
    prr.postal_code,
    prr.country,
    prr.Emergency_Contact_name1,
    prr.contact_type1,
    prr.Emergency_contact_phn_no1,
    prr.Emergency_Contact_name2,
    prr.contact_type2,
    prr.Emergency_contact_phn_no2
FROM
    pivoted_person pip
    LEFT JOIN pivoted_ranked_relationship prr ON prr.person_id = pip.person_id
ORDER BY
    pip.person_number