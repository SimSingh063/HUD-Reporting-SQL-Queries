SELECT 
    poh.segment1 AS Purchase_Order_Number,
    poh.po_header_id,
    pla.line_num AS PO_Line_Number, 
    ecb.Category_code AS categorycode, 
    CONCAT(UPPER(SUBSTR(poh.document_status, 1, 1)), LOWER(SUBSTR(poh.document_status, 2))) AS document_status,
    CONCAT(UPPER(SUBSTR(pla.line_status, 1, 1)), LOWER(SUBSTR(pla.line_status, 2))) AS PO_line_status,
    pol.assessable_value, 
    pol.quantity_accepted,  
    pol.receipt_required_flag, 
    pol.Purchase_Order_Value,
    gcc.segment1 || '-' || gcc.segment2 || '-' || gcc.segment3 || '-' || gcc.segment4 || '-' || gcc.segment5 AS Cost_Codes, --Entity - Cost Centre - Natural Account - Activity - Future  
    ffv.description, 
    hou.name AS Business_Unit, 
    hp.party_name AS Supplier_Name, 
    hp.party_number,
    pz.segment1 AS Supplier_num,  
    TO_CHAR(poh.creation_date, 'dd-MM-yyyy') AS Creation_Date,
    TRIM(poh.comments) AS PO_Description, 
    pod.po_distribution_id, 
    invoices.invoice_id, 
    invoices.invoice_line_number, 
    invoices.period_name AS Period, 
    invoices.invoice_num, 
    invoices.invoice_amount, 
    invoices.invoice_line_amount,
    TO_CHAR(invoices.invoice_date, 'dd-MM-yyyy') AS invoice_date,
    TO_CHAR(invoices.gl_date, 'dd-MM-yyyy') AS GL_Date, 
    TO_CHAR(invoices.invoice_date, 'MONTH-YY') AS invoice_date_period,
    CASE  
        WHEN EXTRACT(MONTH FROM invoice_date) >= 7 THEN TO_CHAR(EXTRACT(YEAR FROM invoice_date)) || '-' || TO_CHAR(EXTRACT(YEAR FROM invoice_date) + 1)  
        ELSE TO_CHAR(EXTRACT(YEAR FROM invoice_date) - 1) || '-' || TO_CHAR(EXTRACT(YEAR FROM invoice_date))  
    END AS FY,
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
                    END Purchase_Order_Value /* Case statement to allow the user to filter out PO's which have <=1 amount */
                FROM 
                    PO_LINE_LOCATIONS_ALL pll
                ) pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
    INNER JOIN EGP_CATEGORIES_B ecb ON ecb.category_id = pla.category_id 
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN POZ_SUPPLIERS pz ON poh.vendor_id = pz.vendor_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
    INNER JOIN HZ_PARTIES hp ON pz.party_id = hp.party_id 
    INNER JOIN FND_FLEX_VALUES_VL ffv  ON ffv.flex_value = gcc.segment4
    INNER JOIN (
                SELECT 
                    aia.invoice_id, 
                    aila.period_name,
                    aia.invoice_num, 
                    CASE 
                        WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount != aila.amount THEN aia.invoice_amount
                        WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount = aila.amount THEN aila.amount
                        ELSE (aia.invoice_amount -  aia.total_tax_amount) 
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
                    CASE 
                        WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount != aila.amount THEN aila.amount
                        WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount = aila.amount THEN NULL
                        WHEN aila.amount = (aia.invoice_amount -  aia.total_tax_amount) THEN NULL 
                        ELSE aila.amount 
                    END AS invoice_line_amount, 
                    CASE 
                        WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount != aila.amount THEN aila.line_number
                        WHEN aila.tax_classification_code IN ('GST EXEMPT', 'GST ZERO') AND aia.invoice_amount = aila.amount THEN NULL
                        WHEN aila.amount = (aia.invoice_amount -  aia.total_tax_amount) THEN NULL
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
    ) invoices ON invoices.po_distribution_id = pod.po_distribution_id
WHERE 
    ffv.value_category = 'HUD_ACTIVITY'
    AND (COALESCE(NULL, :CostCentre) IS NULL OR gcc.segment2 IN (:CostCentre))  
    AND (COALESCE(NULL, :DocumentStatus) IS NULL OR poh.document_status IN (:DocumentStatus))
    AND (COALESCE(NULL, :Party_Name) IS NULL OR hp.party_name IN (:Party_Name))
    AND (COALESCE(NULL, :PO_Number) IS NULL OR poh.segment1 IN (:PO_Number))
    AND (COALESCE(NULL, :Activity) IS NULL OR ffv.flex_value IN (:Activity))
    AND (COALESCE(NULL, :Category_Code) IS NULL OR ecb.category_id IN (:Category_Code))
    AND (COALESCE(NULL, :PO_Value) IS NULL OR pol.Purchase_Order_Value IN (:PO_Value))
    AND (COALESCE(NULL, :Period_Name) IS NULL OR TO_CHAR(invoices.gl_date, 'Month-YY') IN (:Period_Name))
ORDER BY 
    poh.segment1, 
    pla.line_num,
    invoices.invoice_num, 
    invoices.invoice_line_number, 
    invoices.period_name

/* Invoice Period */
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
        DISTINCT TO_CHAR(aia.gl_date, 'Month') AS Month_Created, 
        TO_CHAR(aia.gl_date, 'YY') AS Year_Created, 
        TO_CHAR(aia.gl_date, 'Month-YY') AS Period_Created
    FROM 
        ap_invoices_all aia
    ) Period
ORDER BY 
    Period.Year_Created DESC, 
    Period.Month_Created DESC 

/* Document Status */
SELECT
    DISTINCT poh.document_status
FROM 
    po_headers_all poh
ORDER BY 
    document_status

/* Cost Centre */
SELECT 
    DISTINCT gcc.segment2 
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
ORDER BY 
    segment2 

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

/* Party Name */ 
SELECT 
    DISTINCT hp.party_name
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
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
ORDER BY 
    poh.segment1

/* Category Code */
SELECT 
    DISTINCT ecb.category_code, 
    ecb.category_id
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id 
    INNER JOIN EGP_CATEGORIES_B ecb ON ecb.category_id = pla.category_id 
ORDER BY 
    ecb.category_id