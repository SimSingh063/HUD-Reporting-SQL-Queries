SELECT 
    poh.segment1 AS PO_Number,
    poh.po_header_id,
    pla.line_num AS PO_Line_Number, 
    --pla.category_id, 
    ecb.category_code, 
    CONCAT(UPPER(SUBSTR(poh.document_status, 1, 1)), LOWER(SUBSTR(poh.document_status, 2))) AS document_status,
    CONCAT(UPPER(SUBSTR(pla.line_status, 1, 1)), LOWER(SUBSTR(pla.line_status, 2))) AS PO_line_status,
    pol.assessable_value, 
    pol.quantity_accepted,  
    pol.receipt_required_flag, 
    pol.PO_Value,
    gcc.segment1 || '-' || gcc.segment2 || '-' || gcc.segment3 || '-' || gcc.segment4 || '-' || gcc.segment5 AS Cost_Codes, --Entity - Cost Centre - Natural Account - Activity - Future  
    ffv.description, 
    ppn.display_name AS full_name, 
    hou.name AS Business_Unit, 
    hp.party_name, 
    hp.party_number,
    pz.segment1 AS Supplier_num,  
    TO_CHAR(poh.creation_date, 'dd-MM-yyyy') AS Creation_Date,
    TRIM(poh.comments) AS PO_Description, 
    pod.po_distribution_id, 
    invoices.invoice_id, 
    invoices.invoice_line_number, 
    invoices.period_name, 
    invoices.invoice_num, 
    invoices.invoice_amount, 
    invoices.original_amount,
    invoices.invoice_date, 
    TO_CHAR(invoices.invoice_creation_date,'dd-MM-yyyy') AS invoice_creation_date, 
    TO_CHAR(invoices.invoice_line_creation_Date,'dd-MM-yyyy') AS invoice_line_creation_date,
    invoices.invoice_desc,
    invoices.payment_status_flag, 
    invoices.invoice_line_description
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
    INNER JOIN EGP_CATEGORIES_B ecb ON ecb.category_id = pla.category_id 
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN POZ_SUPPLIERS pz ON poh.vendor_id = pz.vendor_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN HZ_PARTIES hp ON pz.party_id = hp.party_id 
    INNER JOIN FND_FLEX_VALUES_VL ffv  ON ffv.flex_value = gcc.segment4
    INNER JOIN (
                SELECT 
                    aia.invoice_id, 
                    aila.line_number AS invoice_line_number, 
                    aila.period_name,
                    aia.invoice_num, 
                    aia.invoice_amount, 
                    aila.original_amount, 
                    aia.invoice_date, 
                    aia.created_by, 
                    aia.creation_date AS invoice_creation_date, 
                    aila.Creation_Date AS invoice_line_creation_date,
                    aia.description AS invoice_desc, 
                    aia.payment_status_flag, 
                    aila.description AS invoice_line_description, 
                    aida.po_distribution_id
                FROM 
                    ap_invoices_all aia  
					INNER JOIN ap_invoice_lines_all aila ON aia.invoice_id = aila.invoice_id  
					INNER JOIN ap_invoice_distributions_all aida ON aida.invoice_id = aia.invoice_id AND aila.line_number = aida.invoice_line_number
                WHERE 
                    aia.approval_status = 'APPROVED'
                    --AND aila.period_name = 'May-23'
                    AND aila.line_type_lookup_code = 'ITEM'
                    AND aida.line_type_lookup_code = 'ITEM'
                    AND aila.discarded_flag = 'N'
                    --AND aia.invoice_id = 395010
    ) invoices ON invoices.po_distribution_id = pod.po_distribution_id
WHERE 
    ppn.name_type = 'GLOBAL'
    AND poh.creation_date between ppn.effective_start_date AND ppn.effective_end_date 
    AND ffv.value_category = 'HUD_ACTIVITY'
    AND (COALESCE(NULL, :CostCentre) IS NULL OR gcc.segment2 IN (:CostCentre))  
    AND (COALESCE(NULL, :DocumentStatus) IS NULL OR poh.document_status IN (:DocumentStatus))
    AND (COALESCE(NULL, :Party_Name) IS NULL OR hp.party_name IN (:Party_Name))
    AND (COALESCE(NULL, :PO_Number) IS NULL OR poh.segment1 IN (:PO_Number))
    AND (COALESCE(NULL, :Activity) IS NULL OR ffv.flex_value IN (:Activity))
    AND (COALESCE(NULL, :PO_Value) IS NULL OR pol.PO_Value IN (:PO_Value))
    AND (COALESCE(NULL, :Period_Name) IS NULL OR invoices.period_name IN (:Period_Name))
   --AND invoices.invoice_creation_date BETWEEN NVL (:DATE_FROM, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AND NVL (:DATE_TO, TO_DATE('01/01/2100', 'DD/MM/YYYY'))
ORDER BY 
    poh.segment1, 
    pla.line_num,
    invoices.invoice_num, 
    invoices.invoice_line_number

Invoice id = 272007
