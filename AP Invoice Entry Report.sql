/* 
 Title - AP Invoice Entry Report
 Author - Simranjeet Singh
 Date - 27/02/2024   
 Department - Finance 
 Description - Report showcasing details about who created and approved the invoices alongside their respective Purchase Orders, if any. 
 */
WITH invoices AS (
    SELECT
        DISTINCT aia.invoice_id,
        /* Using Distinct as an invoice can be split across multiple PO Lines which can cause duplicate records. We are only showing PO Number not PO lines */
        aia.invoice_num,
        aia.invoice_amount,
        TO_CHAR(aia.invoice_date, 'dd-MM-yyyy') AS invoice_date,
        CASE
            WHEN EXTRACT(
                MONTH
                FROM
                    aia.gl_date
            ) >= 7 THEN TO_CHAR(aia.gl_date, 'YYYY') || '-' || TO_CHAR(
                EXTRACT(
                    YEAR
                    FROM
                        aia.gl_date
                ) + 1
            )
            ELSE TO_CHAR(
                EXTRACT(
                    YEAR
                    FROM
                        aia.gl_date
                ) - 1
            ) || '-' || TO_CHAR(aia.gl_date, 'YYYY')
        END AS FY,
        CASE
            WHEN aia.created_by = 'Batch.Scheduler' THEN 'Batch Scheduler'
            ELSE UPPER(
                SUBSTR(
                    SUBSTR(
                        aia.created_by,
                        1,
                        INSTR(aia.created_by, '.') - 1
                    ),
                    1,
                    1
                )
            ) || LOWER(
                SUBSTR(
                    SUBSTR(
                        aia.created_by,
                        1,
                        INSTR(aia.created_by, '.') - 1
                    ),
                    2
                )
            ) || ' ' || UPPER(
                SUBSTR(
                    SUBSTR(
                        aia.created_by,
                        INSTR(aia.created_by, '.') + 1,
                        INSTR(aia.created_by, '@') - INSTR(aia.created_by, '.') - 1
                    ),
                    1,
                    1
                )
            ) || LOWER(
                SUBSTR(
                    SUBSTR(
                        aia.created_by,
                        INSTR(aia.created_by, '.') + 1,
                        INSTR(aia.created_by, '@') - INSTR(aia.created_by, '.') - 1
                    ),
                    2
                )
            )
        END AS created_by,
        TO_CHAR(aia.creation_date, 'dd-MM-yyyy') AS invoice_creation_date,
        TO_CHAR(aia.gl_date, 'dd-MM-yyyy') AS gl_date,
        aia.description AS invoice_desc,
        aia.payment_status_flag,
        hp.party_name AS Supplier_Name,
        pz.segment1 AS Supplier_num,
        CASE
            WHEN ia.approver_1 IS NULL THEN 'Not Required'
            ELSE ia.approver_1
        END AS approver_1,
        ia.approver_2,
        ia.approver_3,
        hou.name AS Business_Unit,
        gc.segment2 AS Cost_Centre
    FROM
        ap_invoices_all aia
        INNER JOIN ap_invoice_lines_all aila ON aia.invoice_id = aila.invoice_id
        INNER JOIN ap_invoice_distributions_all aida ON aida.invoice_id = aia.invoice_id
        AND aila.line_number = aida.invoice_line_number
        INNER JOIN poz_suppliers pz ON aia.vendor_id = pz.vendor_id
        INNER JOIN hz_parties hp ON pz.party_id = hp.party_id
        INNER JOIN hr_organization_units_f_tl hou ON hou.organization_id = aia.org_id
        LEFT JOIN (
            SELECT
                invoice_id,
                MAX(
                    CASE
                        WHEN approver_num = 1 THEN approved_by
                    END
                ) AS approver_1,
                MAX(
                    CASE
                        WHEN approver_num = 2 THEN approved_by
                    END
                ) AS approver_2,
                MAX(
                    CASE
                        WHEN approver_num = 3 THEN approved_by
                    END
                ) AS approver_3
            FROM
                (
                    SELECT
                        num_approvers.invoice_id,
                        num_approvers.action_date,
                        num_approvers.approved_by,
                        ROW_NUMBER() OVER (
                            PARTITION BY num_approvers.invoice_id
                            ORDER BY
                                num_approvers.action_date
                        ) AS approver_num
                    FROM
                        (
                            SELECT
                                DISTINCT aprvl.invoice_id,
                                MAX(aprvl.action_date) AS action_date,
                                CASE
                                    WHEN aprvl.response = 'ORA_AUTO APPROVED' THEN 'Auto Approved'
                                    WHEN aprvl.approver_id = 'Batch.Scheduler' THEN 'Batch Scheduler'
                                    WHEN aprvl.approver_id = 'ORA_WORKFLOW SYSTEM' THEN 'Workflow System'
                                    ELSE UPPER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                1,
                                                INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            1,
                                            1
                                        )
                                    ) || LOWER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                1,
                                                INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            2
                                        )
                                    ) || ' ' || UPPER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                INSTR(aprvl.approver_id, '.') + 1,
                                                INSTR(aprvl.approver_id, '@') - INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            1,
                                            1
                                        )
                                    ) || LOWER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                INSTR(aprvl.approver_id, '.') + 1,
                                                INSTR(aprvl.approver_id, '@') - INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            2
                                        )
                                    )
                                END AS approved_by
                            FROM
                                (
                                    SELECT
                                        a.invoice_id,
                                        TO_CHAR(a.action_date, 'dd-MM-yyyy') AS action_date,
                                        a.approver_id,
                                        a.response
                                    FROM
                                        ap_inv_aprvl_hist_all a
                                    WHERE
                                        a.history_type = 'DOCUMENTAPPROVAL'
                                        AND a.response IN (
                                            'MANUALLY APPROVED',
                                            'APPROVED',
                                            'ORA_AUTO APPROVED'
                                        )
                                    ORDER BY
                                        a.action_date
                                ) aprvl
                            GROUP BY
                                aprvl.invoice_id,
                                CASE
                                    WHEN aprvl.response = 'ORA_AUTO APPROVED' THEN 'Auto Approved'
                                    WHEN aprvl.approver_id = 'Batch.Scheduler' THEN 'Batch Scheduler'
                                    WHEN aprvl.approver_id = 'ORA_WORKFLOW SYSTEM' THEN 'Workflow System'
                                    ELSE UPPER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                1,
                                                INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            1,
                                            1
                                        )
                                    ) || LOWER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                1,
                                                INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            2
                                        )
                                    ) || ' ' || UPPER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                INSTR(aprvl.approver_id, '.') + 1,
                                                INSTR(aprvl.approver_id, '@') - INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            1,
                                            1
                                        )
                                    ) || LOWER(
                                        SUBSTR(
                                            SUBSTR(
                                                aprvl.approver_id,
                                                INSTR(aprvl.approver_id, '.') + 1,
                                                INSTR(aprvl.approver_id, '@') - INSTR(aprvl.approver_id, '.') - 1
                                            ),
                                            2
                                        )
                                    )
                                END
                        ) num_approvers
                ) approver
            WHERE
                approver.approver_num <= 3
            GROUP BY
                approver.invoice_id
            ORDER BY
                approver.invoice_id
        ) ia ON ia.invoice_id = aia.invoice_id
        INNER JOIN gl_code_combinations gc ON gc.code_combination_id = aia.accts_pay_code_combination_id
    WHERE
        aia.approval_status = 'APPROVED'
        AND aila.line_type_lookup_code = 'ITEM'
        AND aida.line_type_lookup_code = 'ITEM'
        AND aila.discarded_flag = 'N'
    ORDER BY
        aia.invoice_id
),
PO_num AS (
    SELECT
        inv_po.invoice_id,
        inv_po.invoice_amount,
        --inv_po.Business_Unit, 
        MAX(
            CASE
                WHEN inv_po.po_seq = 1 THEN inv_po.Purchase_Order_Number
            END
        ) AS PO_1,
        MAX(
            CASE
                WHEN inv_po.po_seq = 2 THEN inv_po.Purchase_Order_Number
            END
        ) AS PO_2,
        MAX(
            CASE
                WHEN inv_po.po_seq = 3 THEN inv_po.Purchase_Order_Number
            END
        ) AS PO_3,
        MAX(
            CASE
                WHEN inv_po.po_seq = 4 THEN inv_po.Purchase_Order_Number
            END
        ) AS PO_4,
        MAX(
            CASE
                WHEN inv_po.po_seq = 5 THEN inv_po.Purchase_Order_Number
            END
        ) AS PO_5,
        MAX(
            CASE
                WHEN inv_po.po_seq = 6 THEN inv_po.Purchase_Order_Number
            END
        ) AS PO_6
    FROM
        (
            SELECT
                inv.*,
                ROW_NUMBER() OVER (
                    PARTITION BY inv.invoice_id,
                    inv.invoice_amount
                    ORDER BY
                        inv.Purchase_Order_Number
                ) AS Po_Seq
            FROM
                (
                    SELECT
                        DISTINCT poh.segment1 AS Purchase_Order_Number,
                        /* Using DISTINCT as invoices can have multiple lines/distribution lines */
                        poh.po_header_id,
                        aid.invoice_id,
                        invoices.invoice_amount
                    FROM
                        po_headers_all poh
                        INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
                        INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id
                        AND pla.po_line_id = pod.po_line_id
                        INNER JOIN ap_invoice_distributions_all aid ON aid.po_distribution_id = pod.po_distribution_id
                        INNER JOIN invoices ON invoices.invoice_id = aid.invoice_id
                ) inv
        ) inv_po
    WHERE
        inv_po.po_seq <= 6
    GROUP BY
        inv_po.invoice_id,
        inv_po.invoice_amount
)
SELECT
    DISTINCT invoices.invoice_id,
    invoices.invoice_num,
    invoices.invoice_amount,
    invoices.invoice_date,
    invoices.FY,
    invoices.created_by,
    invoices.invoice_creation_date,
    invoices.gl_date,
    invoices.invoice_desc,
    invoices.payment_status_flag,
    invoices.Supplier_Name,
    invoices.Supplier_num,
    invoices.approver_1,
    invoices.approver_2,
    invoices.approver_3,
    invoices.Business_Unit,
    po_num.PO_1,
    po_num.PO_2,
    po_num.PO_3,
    po_num.PO_4,
    po_num.PO_5,
    po_num.PO_6,
    ROW_NUMBER() OVER (
        ORDER BY
            invoices.invoice_id
    ) + 999 AS unique_row_number,
    CASE
        WHEN (
            invoices.invoice_amount >= 100000
            AND invoices.approver_1 = 'Auto Approved'
            AND invoices.approver_2 IS NULL
            AND invoices.approver_3 IS NULL
        ) THEN 'ERROR'
        ELSE NULL
    END AS rule_error1 --, 
    /*    CASE
     WHEN invoices.invoice_amount >= 100000 THEN NULL 
     WHEN invoices.invoice_amount < 100000 AND invoices.created_by <> 'Batch Scheduler' THEN NULL
     WHEN invoices.invoice_amount < 100000 AND invoices.approver_1 = 'Not Required' THEN NULL
     WHEN invoices.invoice_amount < 100000 AND invoices.created_by = 'Batch Scheduler' AND invoices.approver_1 = 'Auto Approved' AND invoices.approver_2 IS NULL AND invoices.approver_3 IS NULL THEN NULL 
     ELSE 'Intervention'
     END rule_error2 */
FROM
    invoices
    LEFT JOIN po_num ON po_num.invoice_id = invoices.invoice_id
    AND po_num.invoice_amount = invoices.invoice_amount
WHERE
    invoices.invoice_amount <> 0
    AND (
        COALESCE(NULL, :Bus_Unit) IS NULL
        OR invoices.Business_Unit IN (:Bus_Unit)
    )
    AND (
        COALESCE(NULL, :Financial_Year) IS NULL
        OR invoices.fy IN (:Financial_Year)
    )
ORDER BY
    invoices.invoice_num


    /*---------------------------------------------------- Invoice Intervention Logic --------------------------------------------------------------- */

SELECT
    inv_lines.*
FROM
    (
        SELECT
            aia.invoice_id,
            aila.period_name,
            aia.invoice_num,
            CASE
                WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO')
                AND aia.invoice_amount != aila.amount THEN aia.invoice_amount
                WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO')
                AND aia.invoice_amount = aila.amount THEN aila.amount
                ELSE (
                    aia.invoice_amount - COALESCE(aia.total_tax_amount, 0)
                )
            END AS invoice_amount,
            aia.invoice_date,
            aia.created_by,
            aia.creation_date AS invoice_creation_date,
            aia.gl_date,
            aila.Creation_Date AS invoice_line_creation_date,
            aia.description AS invoice_desc,
            aia.payment_status_flag,
            aila.description AS invoice_line_description,
            aida.po_distribution_id,
            aila.created_by AS line_created_by,
            aila.last_updated_by AS line_last_updated_by,
            CASE
                WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO')
                AND aia.invoice_amount != aila.amount THEN aila.amount
                WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO')
                AND aia.invoice_amount = aila.amount THEN NULL
                WHEN aila.amount = (
                    aia.invoice_amount - COALESCE(aia.total_tax_amount, 0)
                ) THEN NULL
                ELSE aila.amount
            END AS invoice_line_amount,
            CASE
                WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO')
                AND aia.invoice_amount != aila.amount THEN aila.line_number
                WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO')
                AND aia.invoice_amount = aila.amount THEN NULL
                WHEN aila.amount = (
                    aia.invoice_amount - COALESCE(aia.total_tax_amount, 0)
                ) THEN NULL
                ELSE aila.line_number
            END AS invoice_line_number,
            CASE
                WHEN aia.created_by = 'Batch.Scheduler'
                AND aila.created_by = 'Batch.Scheduler'
                AND aila.last_updated_by = 'Batch.Scheduler' THEN 'No Intervention'
                WHEN aia.created_by = 'Batch.Scheduler'
                AND aila.created_by = 'Batch.Scheduler'
                AND aila.last_updated_by <> 'Batch.Scheduler' THEN 'Intervention'
                WHEN aia.created_by = 'Batch.Scheduler'
                AND aila.created_by <> 'Batch.Scheduler'
                AND aila.last_updated_by <> 'Batch.Scheduler' THEN 'Intervention'
            END AS Intervention_Status,
            CASE
                WHEN aia.created_by = 'Batch.Scheduler'
                AND aila.created_by = 'Batch.Scheduler' THEN 'System Created Invoice'
                WHEN aia.created_by = 'Batch.Scheduler'
                AND aila.created_by <> 'Batch.Scheduler' THEN 'Manually Created Invoice'
                WHEN aia.created_by <> 'Batch.Scheduler'
                AND aila.created_by <> 'Batch.Scheduler' THEN 'Manually Created Invoice'
            END AS Creation_Status,
            po.Purchase_Order_Number,
            po.PO_Line_Number,
            po.Supplier_Name,
            po.Supplier_num,
            hou.name AS Business_Unit,
            CASE
                WHEN EXTRACT(
                    MONTH
                    FROM
                        aia.gl_date
                ) >= 7 THEN TO_CHAR(aia.gl_date, 'YYYY') || '-' || TO_CHAR(
                    EXTRACT(
                        YEAR
                        FROM
                            aia.gl_date
                    ) + 1
                )
                ELSE TO_CHAR(
                    EXTRACT(
                        YEAR
                        FROM
                            aia.gl_date
                    ) - 1
                ) || '-' || TO_CHAR(aia.gl_date, 'YYYY')
            END AS FY
        FROM
            ap_invoices_all aia
            INNER JOIN ap_invoice_lines_all aila ON aia.invoice_id = aila.invoice_id
            INNER JOIN ap_invoice_distributions_all aida ON aida.invoice_id = aia.invoice_id
            AND aila.line_number = aida.invoice_line_number
            INNER JOIN hr_organization_units_f_tl hou ON hou.organization_id = aia.org_id
            LEFT JOIN (
                SELECT
                    poh.segment1 AS Purchase_Order_Number,
                    poh.po_header_id,
                    pla.line_num AS PO_Line_Number,
                    pod.po_distribution_id,
                    pz.segment1 AS Supplier_num,
                    hp.party_name AS Supplier_Name
                FROM
                    po_headers_all poh
                    INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
                    INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id
                    AND pla.po_line_id = pod.po_line_id
                    INNER JOIN poz_suppliers pz ON poh.vendor_id = pz.vendor_id
                    INNER JOIN hz_parties hp ON pz.party_id = hp.party_id
            ) po ON po.po_distribution_id = aida.po_distribution_id
        WHERE
            aia.approval_status = 'APPROVED'
            AND aila.line_type_lookup_code = 'ITEM'
            AND aida.line_type_lookup_code = 'ITEM'
            AND aila.discarded_flag = 'N'
            AND aia.invoice_amount <> 0
    ) inv_lines
WHERE
    (
        COALESCE(NULL, :Bus_Unit) IS NULL
        OR inv_lines.Business_Unit IN (:Bus_Unit)
    )
    AND (
        COALESCE(NULL, :Financial_Year) IS NULL
        OR inv_lines.fy IN (:Financial_Year)
    )
ORDER BY
    inv_lines.invoice_num,
    inv_lines.invoice_line_number