/* 
Title - PO Risk Report
Author - Simranjeet Singh
Date - 19/09/2023
Department - Contracts Management Team (CMT) 
Description - Description - Provides detailed information about the PO and its corresponding contracts and invoices. (Excel Template Report)
*/

SELECT 
    poh.segment1 AS Purchase_Order_Number,
    poh.po_header_id,
    pla.line_num AS PO_Line_Number, 
    ecb.Category_code AS categorycode, 
    CONCAT(UPPER(SUBSTR(poh.document_status, 1, 1)), LOWER(SUBSTR(poh.document_status, 2))) AS PO_status,
    CONCAT(UPPER(SUBSTR(pla.line_status, 1, 1)), LOWER(SUBSTR(pla.line_status, 2))) AS PO_line_status,
    pol.assessable_value AS PO_Ordered_Amount, 
    pol.quantity_accepted,  
    pol.receipt_required_flag, 
    pol.Purchase_Order_Value,
    gcc.segment1 || '-' || gcc.segment2 || '-' || gcc.segment3 || '-' || gcc.segment4 || '-' || gcc.segment5 AS Cost_Codes, --Entity - Cost Centre - Natural Account - Activity - Future  
    ffv.description AS Activity_Name, 
    hou.name AS Business_Unit, 
    hp.party_name AS Supplier_Name, 
    pz.segment1 AS Supplier_num,  
    TO_CHAR(poh.creation_date, 'dd-MM-yyyy') AS Creation_Date,
    TRIM(poh.comments) AS PO_Description, 
    ppn.display_name AS Requestor_name, 
    Contracts.contract_number AS Contracts_num,
    Contracts.line_number AS Contract_Line_number,  
    Contracts.line_amount AS Contract_line_amount,
    Contracts.Contract_Group, 
    Contracts.contract_owner, 
    TO_CHAR(Contracts.start_date, 'dd-MM-yyyy') AS Contract_Start_Date, 
    TO_CHAR(Contracts.end_date, 'dd-MM-yyyy') AS Contract_End_Date,
    pod.po_distribution_id, 
    invoices.Total_invoice_Amt AS PO_Amount_Spent,
    (pol.assessable_value - COALESCE(invoices.Total_invoice_Amt,0)) AS PO_Amount_Left, 
    COALESCE(invoices.Invoice_count,0) AS Invoice_count, 
    invoices.Avg_invoice_Amt AS PO_Avg_Invoice_Amt, 
    FLOOR((pol.assessable_value - invoices.Total_invoice_Amt)/Avg_invoice_Amt) AS Invoices_Remaining, 
    CASE   
        WHEN EXTRACT(MONTH FROM SYSDATE) >= 7 THEN 12 - EXTRACT(MONTH FROM SYSDATE) + 6  
        ELSE 6 - EXTRACT(MONTH FROM SYSDATE)  
    END AS months_left_in_financial_year
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN (
                SELECT 
                    pll.po_header_id, 
                    pll.po_line_id, 
                    pll.line_location_id, 
                    CASE 
                        WHEN pll.assessable_value = 0 THEN NULL 
                        ELSE pll.assessable_value
                    END AS assessable_value, 
                    CASE 
                        WHEN COALESCE(pll.amount_received, pll.quantity_received) = 0 THEN NULL 
                        ELSE COALESCE(pll.amount_received, pll.quantity_received)
                    END quantity_received, 
                    pll.quantity_accepted,
                    pll.quantity_rejected,  
                    CASE 
                        WHEN COALESCE(pll.amount_billed, pll.quantity_billed) = 0 THEN NULL 
                        ELSE COALESCE(pll.amount_billed, pll.quantity_billed)
                    END quantity_billed,
                    pll.quantity_cancelled, 
                    pll.receipt_required_flag,
                    CASE 
                        WHEN  pll.assessable_value IS NULL OR pll.assessable_value <= 1 THEN 'False'
                        ELSE 'True'
                    END Purchase_Order_Value /* Case statement to allow the user to filter out PO's which have <=1 amount */
                FROM 
                    PO_LINE_LOCATIONS_ALL pll
                ) pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
    INNER JOIN PER_PERSON_NAMES_F ppn ON pod.deliver_to_person_id = ppn.person_id
    INNER JOIN EGP_CATEGORIES_B ecb ON ecb.category_id = pla.category_id 
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN POZ_SUPPLIERS pz ON poh.vendor_id = pz.vendor_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN HZ_PARTIES hp ON pz.party_id = hp.party_id 
    INNER JOIN FND_FLEX_VALUES_VL ffv  ON ffv.flex_value = gcc.segment4
    LEFT JOIN (
                SELECT 
                    inv.po_distribution_id, 
                    COALESCE(SUM(
                        CASE   
                            WHEN inv.invoice_line_amount IS NULL THEN inv.invoice_amount  
                            ELSE inv.invoice_line_amount  
                        END  
                        ),0) AS Total_invoice_Amt,   
                    COALESCE(COUNT(DISTINCT inv.invoice_id),0) AS Invoice_count, 
                    COALESCE(ROUND(SUM(
                        CASE   
                            WHEN inv.invoice_line_amount IS NULL THEN inv.invoice_amount  
                            ELSE inv.invoice_line_amount  
                        END  
                       ) / NULLIF(COUNT(DISTINCT inv.invoice_id), 0), 2), 0) AS Avg_invoice_Amt 
                FROM(
                    SELECT 
                        aia.invoice_id, 
                        aila.period_name,
                        aia.invoice_num, 
                        CASE 
                            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount != aila.amount THEN aia.invoice_amount
                            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount = aila.amount THEN aila.amount
                            ELSE (aia.invoice_amount -  COALESCE(aia.total_tax_amount,0))
                        END AS invoice_amount,
                        aia.invoice_date, 
                        aia.created_by, 
                        aia.creation_date AS invoice_creation_date, 
                        aila.Creation_Date AS invoice_line_creation_date,
                        aia.description AS invoice_desc, 
                        aia.payment_status_flag, 
                        aila.description AS invoice_line_description, 
                        aida.po_distribution_id, 
                        CASE 
                            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount != aila.amount THEN aila.amount
                            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount = aila.amount THEN NULL
                            WHEN aila.amount = (aia.invoice_amount -  COALESCE(aia.total_tax_amount,0)) THEN NULL 
                            ELSE aila.amount 
                        END AS invoice_line_amount, 
                        CASE 
                            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount != aila.amount THEN aila.line_number
                            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount = aila.amount THEN NULL
                            WHEN aila.amount = (aia.invoice_amount -  COALESCE(aia.total_tax_amount,0)) THEN NULL
                            ELSE aila.line_number 
                        END AS invoice_line_number 
                    FROM 
                        ap_invoices_all aia  
					    INNER JOIN ap_invoice_lines_all aila ON aia.invoice_id = aila.invoice_id  
					    INNER JOIN ap_invoice_distributions_all aida ON aida.invoice_id = aia.invoice_id AND aila.line_number = aida.invoice_line_number
                    WHERE 
                        aia.approval_status = 'APPROVED'
                        AND aila.line_type_lookup_code = 'ITEM'
                        AND aida.line_type_lookup_code = 'ITEM'
                        AND aila.discarded_flag = 'N'
                    )inv
                GROUP BY 
                    inv.po_distribution_id
            )invoices ON invoices.po_distribution_id = pod.po_distribution_id
    LEFT JOIN (
            SELECT 
                okcd.chr_id,
                okcd.po_doc_number,
                okcd.purchasing_pk2_value, 
                okch.contract_number,
                okcd.po_line_number, 
                okcd.purchasing_pk1_value, 
                okch.major_version AS Contract_Version,
                okch.estimated_amount AS Total_Contract_Value,
                okch.start_date, 
                okch.end_date,
                okch.attribute2 AS Contract_Type,
                okch.attribute4 AS Contract_Group,  
                con_own.contract_owner, 
                con_own.major_version, 
                okcl.line_id,  
                okcl.line_number, 
                COALESCE(okcl.line_amount, okch.agreed_amount) AS line_amount, 
                okcl.Purchasing_category_id
            FROM 
                okc_k_headers_all_b okch
                INNER JOIN okc_dts_deliverables_b okcd ON okcd.chr_id = okch.id AND okcd.deliverable_status not in ('INCOMPLETE','CANCELED')
                LEFT JOIN okc_k_lines_b okcl on okcl.chr_id = okch.id and okcl.major_version = okch.major_version AND okcl.line_id = okcd.cle_id 
                LEFT JOIN (SELECT 
                            hzp.party_name AS Contract_Owner, 
                            okcp.chr_id, 
                            okcp.major_version
                           FROM 
                            okc_k_party_roles_vl okcp 
                            INNER JOIN okc_contacts okcc ON okcc.cpl_id = okcp.id 
                            INNER JOIN hz_parties hzp ON (CASE 
                                                            WHEN okcc.jtot_object1_code ='OKX_RESOURCE' THEN okcc.object1_id1
                                                            ELSE NULL 
                                                          END) = hzp.party_id
                            WHERE 
                                okcc.owner_yn = 'Y'
                                AND okcc.cro_code = 'CONTRACT_ADMIN' /* Assiging people with CONTRACT_ADMIN code as Contract Owner */
                           ) Con_own ON con_own.chr_id = okch.id AND  con_own.major_version = okch.major_version          
            WHERE 
               okch.version_type = 'C'
            ) Contracts ON (Contracts.purchasing_pk1_value = pla.from_header_id AND Contracts.purchasing_pk2_value = pla.from_line_id)
                        OR (Contracts.purchasing_pk1_value = pla.contract_id) 
                        OR ((Contracts.purchasing_pk1_value = pla.contract_id AND Contracts.Purchasing_category_id = pla.category_id) OR (Contracts.purchasing_pk1_value = pla.contract_id)) 
                        OR ((Contracts.po_doc_number = poh.segment1 AND Contracts.po_line_number = pla.line_num AND contracts.Purchasing_category_id = pla.category_id) OR (Contracts.po_doc_number = poh.segment1 AND Contracts.po_line_number = pla.line_num))
WHERE 
    gcc.segment2 = 427
    AND hou.name = 'Crown'
    AND pol.Purchase_Order_Value = 'True'
    AND ffv.value_category = 'HUD_ACTIVITY'
    AND ppn.name_type = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN ppn.effective_start_date AND ppn.effective_end_date 
    AND (COALESCE(NULL, :DocumentStatus) IS NULL OR poh.document_status IN (:DocumentStatus))
    AND (COALESCE(NULL, :Party_Name) IS NULL OR hp.party_name IN (:Party_Name))
    AND (COALESCE(NULL, :PO_Number) IS NULL OR poh.segment1 IN (:PO_Number))
    AND (COALESCE(NULL, :Activity) IS NULL OR ffv.flex_value IN (:Activity))
    AND (COALESCE(NULL, :Contract_Number) IS NULL OR Contracts.contract_number IN (:Contract_Number))
    AND (COALESCE(NULL, :Requester_Name) IS NULL OR ppn.display_name IN (:Requester_Name))
    AND (COALESCE(NULL, :Contract_Start_Period) IS NULL OR TO_CHAR(Contracts.start_date, 'Month-YY') IN (:Contract_Start_Period))
    AND (COALESCE(NULL, :Contract_End_Period) IS NULL OR TO_CHAR(Contracts.end_date, 'Month-YY') IN (:Contract_End_Period))

/* PO Number */
SELECT 
    DISTINCT poh.segment1 AS PO_Number
FROM 
po_headers_all poh 
    INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN po_line_locations_all pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id
    INNER JOIN ap_invoice_distributions_all aida ON aida.po_distribution_id = pod.po_distribution_id /* Inner joining Invoices to only display PO's that have been invoiced*/
    INNER JOIN ap_invoice_lines_all aila ON aila.line_number = aida.invoice_line_number AND aila.invoice_id = aida.invoice_id
    INNER JOIN ap_invoices_all aia ON aia.invoice_id = aila.invoice_id
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
WHERE 
    gcc.segment2 = 427 /* Using this logic to get PO's applicable for only CMT Team i.e., Cost Centre = 427 and Business Unit = Crown */
    AND hou.name = 'Crown'
    AND aia.approval_status = 'APPROVED'
    AND aila.line_type_lookup_code = 'ITEM'
    AND aida.line_type_lookup_code = 'ITEM'
    AND aila.discarded_flag = 'N'
ORDER BY 
    poh.segment1


/* Supplier Name */
SELECT 
    DISTINCT hp.party_name
FROM 
po_headers_all poh 
    INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN po_line_locations_all pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id
    INNER JOIN ap_invoice_distributions_all aida ON aida.po_distribution_id = pod.po_distribution_id /* Inner joining Invoices to only display Suppliers that have been invoiced*/
    INNER JOIN ap_invoice_lines_all aila ON aila.line_number = aida.invoice_line_number AND aila.invoice_id = aida.invoice_id
    INNER JOIN ap_invoices_all aia ON aia.invoice_id = aila.invoice_id
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN POZ_SUPPLIERS pz ON poh.vendor_id = pz.vendor_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN HZ_PARTIES hp ON pz.party_id = hp.party_id 
WHERE 
    gcc.segment2 = 427 /* Using this logic to get suppliers applicable for only CMT Team i.e., Cost Centre = 427 and Business Unit = Crown */
    AND hou.name = 'Crown'
    AND aia.approval_status = 'APPROVED'
    AND aila.line_type_lookup_code = 'ITEM'
    AND aida.line_type_lookup_code = 'ITEM'
    AND aila.discarded_flag = 'N'
ORDER BY 
    hp.party_name



/* Contract Number*/
SELECT
    DISTINCT Contracts.contract_number
FROM(
    SELECT 
        okch.contract_number, 
        okcd.purchasing_pk1_value,
        okcd.purchasing_pk2_value,
        okcd.po_doc_number, 
        okcl.Purchasing_category_id, 
        okcd.po_line_number
    FROM 
        okc_k_headers_all_b okch
        INNER JOIN okc_dts_deliverables_b okcd ON okcd.chr_id = okch.id AND okcd.deliverable_status not in ('INCOMPLETE','CANCELED')
        LEFT JOIN okc_k_lines_b okcl on okcl.chr_id = okch.id and okcl.major_version = okch.major_version AND okcl.line_id = okcd.cle_id 
    WHERE 
        EXISTS( 
            SELECT 
                pla.from_header_id, 
                pla.from_line_id, 
                pla.contract_id, 
                pla.category_id,
                pla.line_num,
                poh.segment1
            FROM 
                po_headers_all poh
                INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
                INNER JOIN po_line_locations_all pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
                INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id
                INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id AND hou.name = 'Crown' 
                INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id  AND gcc.segment2 = 427 
            WHERE 
                (okcd.purchasing_pk1_value = pla.from_header_id AND okcd.purchasing_pk2_value = pla.from_line_id)
                OR (okcd.purchasing_pk1_value = pla.contract_id) 
                OR ((okcd.purchasing_pk1_value = pla.contract_id AND okcl.Purchasing_category_id = pla.category_id) OR (okcd.purchasing_pk1_value = pla.contract_id)) 
                OR (okcd.po_doc_number = poh.segment1 AND okcd.po_line_number = pla.line_num AND okcl.Purchasing_category_id = pla.category_id)
            )
    ) Contracts /* Using this logic to get contracts applicable for only CMT Team i.e., Cost Centre = 427 and Business Unit = Crown */
ORDER BY 
    Contracts.contract_number

/* Requestor */ 
SELECT 
    DISTINCT ppn.display_name AS Requester_Name
FROM 
    po_headers_all poh 
    INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN po_line_locations_all pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id
    INNER JOIN ap_invoice_distributions_all aida ON aida.po_distribution_id = pod.po_distribution_id
    INNER JOIN ap_invoice_distributions_all aida ON aida.po_distribution_id = pod.po_distribution_id /* Inner joining Invoices to only display Suppliers that have been invoiced*/
    INNER JOIN ap_invoice_lines_all aila ON aila.line_number = aida.invoice_line_number AND aila.invoice_id = aida.invoice_id
    INNER JOIN ap_invoices_all aia ON aia.invoice_id = aila.invoice_id
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN PER_PERSON_NAMES_F ppn ON pod.deliver_to_person_id = ppn.person_id
WHERE 
    ppn.name_type = 'GLOBAL' /* Using this logic to get requestors applicable for only CMT Team i.e., Cost Centre = 427 and Business Unit = Crown */
    AND gcc.segment2 = 427 
    AND hou.name = 'Crown'
    AND aia.approval_status = 'APPROVED'
    AND aila.line_type_lookup_code = 'ITEM'
    AND aida.line_type_lookup_code = 'ITEM'
    AND aila.discarded_flag = 'N'
ORDER BY 
    ppn.display_name

/* Activity */ 
SELECT 
    DISTINCT ffv.description,
    ffv.flex_value
FROM 
    po_headers_all poh 
    INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN po_line_locations_all pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id
    INNER JOIN ap_invoice_distributions_all aida ON aida.po_distribution_id = pod.po_distribution_id
    INNER JOIN ap_invoice_distributions_all aida ON aida.po_distribution_id = pod.po_distribution_id /* Inner joining Invoices to only display Suppliers that have been invoiced*/
    INNER JOIN ap_invoice_lines_all aila ON aila.line_number = aida.invoice_line_number AND aila.invoice_id = aida.invoice_id
    INNER JOIN ap_invoices_all aia ON aia.invoice_id = aila.invoice_id
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN FND_FLEX_VALUES_VL ffv ON ffv.flex_value = gcc.segment4
WHERE 
    gcc.segment2 = 427 
    AND hou.name = 'Crown'
    AND aia.approval_status = 'APPROVED'
    AND aila.line_type_lookup_code = 'ITEM'
    AND aida.line_type_lookup_code = 'ITEM'
    AND aila.discarded_flag = 'N'
    AND ffv.value_category = 'HUD_ACTIVITY'
ORDER BY 
    ffv.flex_value

/* Contract Start Period */
SELECT 
    CASE 
        WHEN okc.Month_Started = 01 THEN 'Jan' || '-' || okc.Year_started
        WHEN okc.Month_Started = 02 THEN 'Feb' || '-' || okc.Year_started
        WHEN okc.Month_Started = 03 THEN 'Mar' || '-' || okc.Year_started
        WHEN okc.Month_Started = 04 THEN 'Apr' || '-' || okc.Year_started
        WHEN okc.Month_Started = 05 THEN 'May' || '-' || okc.Year_started
        WHEN okc.Month_Started = 06 THEN 'Jun' || '-' || okc.Year_started
        WHEN okc.Month_Started = 07 THEN 'Jul' || '-' || okc.Year_started
        WHEN okc.Month_Started = 08 THEN 'Aug' || '-' || okc.Year_started
        WHEN okc.Month_Started = 09 THEN 'Sep' || '-' || okc.Year_started
        WHEN okc.Month_Started = 10 THEN 'Oct' || '-' || okc.Year_started
        WHEN okc.Month_Started = 11 THEN 'Nov' || '-' || okc.Year_started
        WHEN okc.Month_Started = 12 THEN 'Dec' || '-' || okc.Year_started
    END AS Contract_Period,
    okc.Period_Started 
FROM(
    SELECT 
        DISTINCT TO_CHAR(okch.start_date, 'Month') AS Month_Started, 
        TO_CHAR(okch.start_date, 'YY') AS Year_Started, 
        TO_CHAR(okch.start_date, 'Month-YY') AS Period_Started
    FROM 
        okc_k_headers_all_b okch
    ) okc
ORDER BY 
    okc.Year_Started DESC, 
    okc.Month_Started DESC 


/* Contract End Period */
SELECT 
    CASE 
        WHEN okc.Month_End = 01 THEN 'Jan' || '-' || okc.Year_End
        WHEN okc.Month_End = 02 THEN 'Feb' || '-' || okc.Year_End
        WHEN okc.Month_End = 03 THEN 'Mar' || '-' || okc.Year_End
        WHEN okc.Month_End = 04 THEN 'Apr' || '-' || okc.Year_End
        WHEN okc.Month_End = 05 THEN 'May' || '-' || okc.Year_End
        WHEN okc.Month_End = 06 THEN 'Jun' || '-' || okc.Year_End
        WHEN okc.Month_End = 07 THEN 'Jul' || '-' || okc.Year_End
        WHEN okc.Month_End = 08 THEN 'Aug' || '-' || okc.Year_End
        WHEN okc.Month_End = 09 THEN 'Sep' || '-' || okc.Year_End
        WHEN okc.Month_End = 10 THEN 'Oct' || '-' || okc.Year_End
        WHEN okc.Month_End = 11 THEN 'Nov' || '-' || okc.Year_End
        WHEN okc.Month_End = 12 THEN 'Dec' || '-' || okc.Year_End
    END AS Contract_Period,
    okc.Period_End
FROM(
    SELECT 
        DISTINCT TO_CHAR(okch.end_date, 'Month') AS Month_End, 
        TO_CHAR(okch.end_date, 'YY') AS Year_End, 
        TO_CHAR(okch.end_date, 'Month-YY') AS Period_End
    FROM 
        okc_k_headers_all_b okch
    ) okc
ORDER BY 
    okc.Year_End DESC, 
    okc.Month_End DESC 