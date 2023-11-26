/* 
Title - Contractor Consultant Report
Author - Simranjeet Singh
Date - 24/11/2023
Department - Procurement and Finance 
Description - Provides detailed information about all the PO's and its corresponding contracts that come under Contractor and Consultant Purchasing Category
*/

/* SQL Code to get PO and Contract Details and calucate the PO Amount Spent for between two dates */
SELECT 
    poh.segment1 AS Purchase_Order_Number,
    poh.po_header_id,
    pla.line_num AS PO_Line_Number, 
    ecb.Category_code, 
    CONCAT(UPPER(SUBSTR(poh.document_status, 1, 1)), LOWER(SUBSTR(poh.document_status, 2))) AS POstatus,
    CONCAT(UPPER(SUBSTR(pla.line_status, 1, 1)), LOWER(SUBSTR(pla.line_status, 2))) AS PO_line_status,
    pol.assessable_value AS PO_Ordered_Amount, 
    CASE 
        WHEN pol.tax_exclusive_price = 1 THEN NULL 
        WHEN pol.uom_code = 'ea' THEN NULL 
        WHEN pol.uom_code IS NULL THEN NULL
        ELSE pol.quantity
    END quantity,   
    CASE
        WHEN pol.tax_exclusive_price = 1 THEN NULL 
        WHEN pol.uom_code = 'ea' THEN NULL 
        ELSE pol.uom_code
    END AS uom_code,
    CASE 
        WHEN pol.tax_exclusive_price = 1 THEN NULL 
        WHEN pol.uom_code = 'ea' THEN NULL 
        WHEN pol.uom_code IS NULL THEN NULL
        ELSE pol.tax_exclusive_price
    END AS price,
    pol.receipt_required_flag, 
    gcc.segment1 AS Entity, 
    gcc.segment2 AS Cost_Centre, 
    gcc.segment3 AS Natural_Account, 
    gcc.segment4 AS Activity, 
    gcc.segment5 AS Future,
    ffv.description AS Activity_Name, 
    hou.name AS BusinessUnit, 
    hp.party_name AS Supplier_Name, 
    pz.segment1 AS Supplier_num,  
    TO_CHAR(poh.creation_date, 'dd-MM-yyyy') AS PO_Creation_Date,
    TO_CHAR(poh.closed_date, 'dd-MM-yyyy') AS PO_Closed_Date,
    TO_CHAR(pol.need_by_date, 'dd-MM-yyyy') AS PO_Need_by_Date, 
    TRIM(poh.comments) AS PO_Description, 
    pla.item_description,
    ppn.display_name AS Requestor_name, 
    pod.po_distribution_id, 
    COALESCE(invoices.PO_spend,0) AS PO_spend,
    Contracts.contract_number AS Contracts_num,
    Contracts.line_number AS Contract_Line_number,  
    Contracts.line_amount AS Contract_line_amount,
    Contracts.Contract_Group, 
    Contracts.contract_owner, 
    Contracts.Contract_Start_Date, 
    Contracts.Contract_End_Date
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
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
                COALESCE(SUM ( 
                        CASE   
                            WHEN inv.invoice_line_amount IS NULL THEN inv.invoice_amount  
                            ELSE inv.invoice_line_amount  
                        END  ),0) AS PO_Spend
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
                    aia.gl_date, 
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
                    END AS invoice_line_number, 
                    CASE  
                        WHEN EXTRACT(MONTH FROM aia.gl_date) >= 7 THEN EXTRACT(YEAR FROM aia.gl_date)  
                        ELSE EXTRACT(YEAR FROM aia.gl_date) - 1  
                    END Invoice_FY  
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
            WHERE  
                inv.gl_date BETWEEN NVL (:INV_DATE_FROM, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AND NVL (:INV_DATE_TO, TO_DATE('01/01/2100', 'DD/MM/YYYY')) /* To allow the user to find the PO Amount Spend between two dates*/
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
                TO_CHAR(okch.start_date,'dd-MM-yyyy') AS Contract_Start_Date,
                TO_CHAR(okch.end_date, 'dd-MM-yyyy') AS Contract_End_Date, 
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
    ppn.name_type = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN ppn.effective_start_date AND ppn.effective_end_date 
    AND ecb.Category_code IN ('AOG - Contractors', 'AOG - Other Professional Services','AOG_-_Consultancy')
    AND pol.assessable_value != 0
    AND (COALESCE(NULL, :Business_Unit) IS NULL OR hou.name IN (:Business_Unit))
    AND (COALESCE(NULL, :CategoryCode) IS NULL OR ecb.Category_code IN (:CategoryCode))
    AND (COALESCE(NULL, :PO_status) IS NULL OR poh.document_status IN (:PO_status))
    AND poh.creation_date BETWEEN NVL (:DATE_FROM, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AND NVL (:DATE_TO, TO_DATE('01/01/2100', 'DD/MM/YYYY'))  
ORDER BY 
    poh.segment1, 
    pla.line_num

/* SQL code to calcualte total PO Amount Spent and total PO Amount Spent for the current Financial Year */ 
SELECT 
    inv.po_distribution_id, 
    COALESCE(SUM ( 
                CASE   
                    WHEN inv.invoice_line_amount IS NULL THEN inv.invoice_amount  
                    ELSE inv.invoice_line_amount  
                END  ),0) AS Total_PO_spend,
    COALESCE(SUM (  
                CASE  
                    WHEN inv.invoice_FY = 
                    CASE  
                        WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 7 THEN EXTRACT(YEAR FROM CURRENT_DATE)  
                        ELSE EXTRACT(YEAR FROM CURRENT_DATE) - 1  
                    END THEN 
                    CASE  
                        WHEN inv.invoice_line_amount IS NULL THEN inv.invoice_amount  
                        ELSE inv.invoice_line_amount  
                    END  
                    ELSE 0  
                END) ,0) AS Total_PO_spend_current_FY, 
    COALESCE(COUNT(DISTINCT inv.invoice_id),0) AS Invoice_count
FROM(
     SELECT 
        aia.invoice_id, 
        aia.invoice_num, 
        CASE 
            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount != aila.amount THEN aia.invoice_amount
            WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount = aila.amount THEN aila.amount
            ELSE (aia.invoice_amount -  COALESCE(aia.total_tax_amount,0))
        END AS invoice_amount,
        aia.invoice_date, 
        aia.gl_date, 
        TO_CHAR(aia.gl_date, 'yyyy') AS gl_year, 
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
        END AS invoice_line_number, 
        CASE  
            WHEN EXTRACT(MONTH FROM aia.gl_date) >= 7 THEN EXTRACT(YEAR FROM aia.gl_date)  /* Extract Year from the GL Date to get the Financial Year */
            ELSE EXTRACT(YEAR FROM aia.gl_date) - 1  
        END Invoice_FY  
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


/* Po Status */
SELECT
    DISTINCT poh.document_status
FROM 
    po_headers_all poh
ORDER BY 
    document_status


/* Category Code */
SELECT 
    DISTINCT ecb.Category_code
FROM 
    EGP_CATEGORIES_B ecb
WHERE 
    ecb.Category_code IN ('AOG - Contractors', 'AOG - Other Professional Services','AOG_-_Consultancy')
ORDER BY 
    ecb.Category_code