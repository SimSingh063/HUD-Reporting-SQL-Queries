/* 
Title - Contract and Purchase Order Report
Author - Simranjeet Singh
Date - 21/08/2023
Description - Report showcasing all Purchase Orders alongside their respective Contracts. 
(Note that not every Purchase Order has a contract, and in such cases, it will be marked as 'nil')
*/

SELECT 
    poh.segment1 AS PO_Number,
    poh.po_header_id,
    pla.line_num AS PO_Line_Number, 
    pla.category_id,
    pla.from_header_id, 
    pla.from_line_id,
    pla.contract_id, 
    CASE 
        WHEN poh.document_status = 'CANCELED' THEN 'Canceled'
        WHEN poh.document_status = 'CLOSED' THEN 'Closed'
        WHEN poh.document_status = 'INCOMPLETE' THEN 'Incomplete'
        WHEN poh.document_status = 'CLOSED FOR INVOICING' THEN 'Closed for Invoicing'
        WHEN poh.document_status = 'CLOSED FOR RECEIVING' THEN 'Closed for Receiving'
        WHEN poh.document_status = 'FINALLY CLOSED' THEN 'Finally Closed'
        WHEN poh.document_status = 'ON HOLD' THEN 'On Hold'
        WHEN poh.document_status = 'OPEN' THEN 'Open'
        WHEN poh.document_status = 'PENDING APPROVAL' THEN 'Pending Approval'
        WHEN poh.document_status = 'WITHDRAWN' THEN 'Withdrawn'
        END AS document_status, 
    poh.currency_code, 
    pol.assessable_value, 
    pol.quantity_received, 
    pol.quantity_accepted, 
    pol.quantity_rejected, 
    pol.quantity_billed, 
    pol.quantity_cancelled, 
    pol.receipt_required_flag, 
    pol.PO_Value,
    gcc.segment2 || '-' || gcc.segment3 || '-' || gcc.segment4 AS Cost_Codes,
    ffv.description, 
    ppn.display_name AS full_name, 
    hou.name AS Business_Unit, 
    hp.party_name, 
    hp.party_number,
    pz.segment1 AS Supplier_num,  
    TO_CHAR(poh.creation_date, 'dd-MM-yyyy') AS Creation_Date,
    TO_CHAR(poh.creation_date, 'MONTH-YY') AS PO_Start_Period,
    TRIM(poh.comments) AS Comments, 
    contracts.contract_number, 
    contracts.contract_version, 
    contracts.total_contract_value, 
    TO_CHAR(contracts.start_date, 'dd-MM-yyyy') AS Contract_Start_Date,
    TO_CHAR(contracts.end_date, 'dd-MM-yyyy') AS Contract_End_Date, 
    TO_CHAR(contracts.start_date, 'MONTH-YY') AS Contract_Start_Period,  
    contracts.contract_type, 
    contracts.Contract_Group,
    Contracts.contract_owner, 
    Contracts.line_id, 
    Contracts.line_number AS Con_line_number, 
    Contracts.line_amount AS Con_line_amount
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
                    END PO_Value /* Case statement to allow the user to filter out PO's which have <=1 amount */
                FROM 
                    PO_LINE_LOCATIONS_ALL pll
                ) pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
    INNER JOIN PER_PERSON_NAMES_F ppn ON pod.deliver_to_person_id = ppn.person_id
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN POZ_SUPPLIERS pz ON poh.vendor_id = pz.vendor_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN HZ_PARTIES hp ON pz.party_id = hp.party_id 
    INNER JOIN FND_FLEX_VALUES_VL ffv  ON ffv.flex_value = gcc.segment4
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
                INNER JOIN okc_dts_deliverables_b okcd ON okcd.chr_id = okch.id
                LEFT JOIN okc_k_lines_b okcl on okcl.chr_id = okch.id and okcl.major_version = okch.major_version
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
               okcd.deliverable_status not in ('INCOMPLETE','CANCELED')
               AND okch.version_type = 'C'
            ) Contracts ON (Contracts.purchasing_pk1_value = pla.from_header_id AND Contracts.purchasing_pk2_value = pla.from_line_id  AND contracts.Purchasing_category_id = pla.category_id)
                        OR (Contracts.purchasing_pk1_value = pla.contract_id) 
                        OR (Contracts.po_doc_number = poh.segment1 AND Contracts.po_line_number = pla.line_num AND contracts.Purchasing_category_id = pla.category_id)
WHERE 
    ppn.name_type = 'GLOBAL'
    AND poh.creation_date between ppn.effective_start_date AND ppn.effective_end_date 
    AND ffv.value_category = 'HUD_ACTIVITY'
    AND (COALESCE(NULL, :CostCentre) IS NULL OR gcc.segment2 IN (:CostCentre))  
    AND (COALESCE(NULL, :DocumentStatus) IS NULL OR poh.document_status IN (:DocumentStatus))
    AND (COALESCE(NULL, :Party_Name) IS NULL OR hp.party_name IN (:Party_Name))
    AND (COALESCE(NULL, :Business_Unit) IS NULL OR hou.name IN (:Business_Unit))
    AND (COALESCE(NULL, :PO_Number) IS NULL OR poh.segment1 IN (:PO_Number))
    AND (COALESCE(NULL, :Activity) IS NULL OR ffv.flex_value IN (:Activity))
    AND (COALESCE(NULL, :PO_Value) IS NULL OR pol.PO_Value IN (:PO_Value))
    AND (COALESCE(NULL, :Contract_Type) IS NULL OR contracts.contract_type IN (:Contract_Type))
    AND (COALESCE(NULL, :Contract_Group) IS NULL OR contracts.contract_group IN (:Contract_Group))
    AND (COALESCE(NULL, :Period_Name) IS NULL OR TO_CHAR(poh.creation_date, 'Month-YY') IN (:Period_Name))
    AND (COALESCE(NULL, :Contract_Period) IS NULL OR TO_CHAR(contracts.start_date, 'Month-YY') IN (:Contract_Period))
    AND poh.creation_date BETWEEN NVL (:DATE_FROM, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AND NVL (:DATE_TO, TO_DATE('01/01/2100', 'DD/MM/YYYY'))
ORDER BY 
    poh.segment1, 
    pla.line_num
    
/* ---------------------------------- Filters --------------------------------------- */
/* Document Status */
SELECT
    DISTINCT poh.document_status
FROM 
    po_headers_all poh
ORDER BY 
    document_status

/* Cost Centre */
SELECT 
    DISTINCT segment2 
FROM 
    GL_CODE_COMBINATIONS
ORDER BY 
    segment2 


/* Party Name */ 
SELECT 
    DISTINCT hp.party_name
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
    INNER JOIN PER_PERSON_NAMES_F ppn ON pod.deliver_to_person_id = ppn.person_id
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN POZ_SUPPLIERS pz ON poh.vendor_id = pz.vendor_id
    INNER JOIN HZ_PARTIES hp ON pz.party_id = hp.party_id  
ORDER BY 
    hp.party_name


/* PO Number */
SELECT 
    DISTINCT poh.segment1 AS PO_Number
FROM 
PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 

/* Activity */
SELECT 
    DISTINCT ffv.description,
    ffv.flex_value
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN FND_FLEX_VALUES_VL ffv ON ffv.flex_value = gcc.segment4
WHERE 
    ffv.value_category = 'HUD_ACTIVITY'
ORDER BY 
    ffv.flex_value


/* Contract Type */
SELECT 
    DISTINCT okch.attribute2 AS Contract_Type
FROM 
    okc_k_headers_all_b okch
    INNER JOIN okc_dts_deliverables_b okcd ON okcd.chr_id = okch.id

/* Contract Group */
SELECT 
    DISTINCT okch.attribute4 AS Contract_Group
FROM 
    okc_k_headers_all_b okch
    INNER JOIN okc_dts_deliverables_b okcd ON okcd.chr_id = okch.id

/* PO Creation Period */ 
SELECT 
    CASE 
        WHEN Period.Month_Created = 01 THEN 'Jan' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 02 THEN 'Feb' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 03 THEN 'Mar' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 04 THEN 'Apr' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 05 THEN 'May' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 06 THEN 'Jun' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 07 THEN 'Jul' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 08 THEN 'Aug' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 09 THEN 'Sep' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 10 THEN 'Oct' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 11 THEN 'Nov' || '-' || Period.Year_Created
        WHEN Period.Month_Created = 12 THEN 'Dec' || '-' || Period.Year_Created
    END AS Period_Name,
    Period.Period_Created

FROM(
    SELECT 
        DISTINCT TO_CHAR(poh.creation_date, 'Month') AS Month_Created, 
        TO_CHAR(poh.creation_date, 'YY') AS Year_Created, 
        TO_CHAR(poh.creation_date, 'Month-YY') AS Period_Created
    FROM 
        PO_HEADERS_ALL poh
    ) Period
ORDER BY 
    Period.Year_Created DESC, 
    Period.Month_Created DESC 
    
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

/* Organisation Unit */

SELECT 
    DISTINCT hou.name AS Org_unit
FROM 
    HR_ORGANIZATION_UNITS_F_TL hou 
ORDER BY 
    hou.name