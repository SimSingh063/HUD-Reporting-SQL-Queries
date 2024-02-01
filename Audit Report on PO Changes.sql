/* 
Title - Audit Report on PO Changes
Author - Simranjeet Singh
Date - 01/02/2024
Description - To provide a comprehensive overview of Purchase Orders (POs) throughout their lifecycle, from creation to the closing stage.
In addition, the report aims to enhance the understanding of any changes made to the POs.
*/

WITH PO_Agreement_Header AS (
SELECT 
    pha.po_header_id, 
    pv.version_id,
    pha.segment1 AS po_number,
    pha.Type_Lookup_Code,
    pv.co_sequence AS Header_co_sequence, 
    TRIM(pha.comments) AS PO_Description,
    NVL(pv.co_num, 0) AS co_num, 
    pv.change_order_desc, 
    pv.originator_id, 
    pv.originator_role,
    pha.entity_change_type_code,
    TO_CHAR(fv.document_date, 'dd-MM-yyyy') AS PO_Date_Display,
    TO_CHAR(pv.document_date, 'dd-MM-yyyy') AS PO_ChangeOrder_Date, 
    TO_CHAR(pv.creation_date, 'dd-MM-yyyy') AS Version_Date, 
    CASE 
        WHEN pha.cancel_flag = 'Y' THEN 'Cancelled'
        WHEN pha.from_co_seq = pv.co_sequence THEN CASE 
                                                    WHEN pha.entity_change_type_code = 'I' THEN 'New'
                                                    WHEN pha.entity_change_type_code = 'U' THEN 'Changed'
                                                    WHEN pha.entity_change_type_code = 'C' THEN 'Changed'
                                                    ELSE NULL
                                                END
        ELSE NULL
    END AS HeaderStatus, 
    hou.name AS BusinessUnit, 
    pz.segment1 AS Supplier_Num, 
    hp.party_name AS Supplier_Name
FROM 
    po_headers_archive_all pha 
    INNER JOIN po_versions pv ON pv.po_header_id = pha.po_header_id AND pha.from_co_seq <= pv.co_sequence AND pha.to_co_seq > pv.co_sequence
    INNER JOIN po_versions fv ON fv.po_header_id = pha.po_header_id AND fv.co_sequence = 0 /* First Version of the PO */
    INNER JOIN hr_organization_units_f_tl hou ON hou.organization_id = pha.prc_bu_id
    INNER JOIN poz_suppliers pz ON pha.vendor_id = pz.vendor_id
    INNER JOIN hz_parties hp ON pz.party_id = hp.party_id 
), 
 
PO_Agreement_Line AS (
SELECT
    plaa.po_line_id,
    pohdr.po_header_id,
    Version.version_id,
    plaa.line_num,
    plaa.item_revision,
    plaa.item_description,
    plaa.vendor_product_num,
    linetype.line_type,
    plaa.shipping_uom_quantity AS quantity,
    plaa.uom_code AS pricing_uom_code,
    plaa.base_qty,
    plaa.base_uom,
    plaa.unit_price,
    line_locations.assessable_value AS PO_Ordered_Amount, 
    plaa.cancel_flag,
    plaa.category_id,
    CASE
        WHEN plaa.from_co_seq = Version.co_sequence THEN plaa.entity_change_type_code
        ELSE 'C'
    END AS Entity_Change_Type_Code,
    CASE
        WHEN plaa.from_co_seq = Version.co_sequence THEN
            CASE
                WHEN plaa.cancel_flag = 'Y' THEN 'CANCELLED'
                ELSE
                    CASE
                        WHEN  plaa.entity_change_type_code = 'I' THEN 'New'
                        WHEN  plaa.entity_change_type_code = 'U' THEN 'Changed'
                        WHEN  plaa.entity_change_type_code = 'C' THEN 'Changed'
                        ELSE NULL
                    END
            END
        ELSE 'Changed'
    END AS Line_Status, 
    line_dist.code_combination_id, 
    line_dist.Requester, 
    gcc.segment1 AS Entity, 
    gcc.segment2 AS Cost_Centre, 
    gcc.segment3 AS Natural_Account, 
    gcc.segment4 AS Activity, 
    gcc.segment5 AS Future, 
    ecb.Category_code AS categorycode
FROM 
    PO_LINES_ARCHIVE_ALL Plaa
    INNER JOIN PO_LINE_TYPES_VL LineType ON plaa.line_type_id = LineType.line_type_id
    INNER JOIN PO_VERSIONS Version ON plaa.po_header_id = Version.po_header_id
    INNER JOIN (SELECT 
                    plla.po_header_id, 
                    plla.line_location_id, 
                    plla.po_line_id, 
                    pv.version_id, 
                    plla.assessable_value
                FROM
                    PO_LINE_LOCATIONS_ARCHIVE_ALL plla
                    INNER JOIN po_versions pv on plla.po_header_id = pv.po_header_id AND plla.from_co_seq <= pv.co_sequence AND plla.to_co_seq > pv.co_sequence
                    INNER JOIN po_lines_archive_all pla ON pla.po_line_id = plla.po_line_id AND pla.po_header_id = plla.po_header_id AND pla.from_co_seq <= pv.co_sequence AND pla.to_co_seq > pv.co_sequence
                    INNER JOIN po_headers_archive_all pha ON pha.po_header_id = plla.po_header_id AND pha.from_co_seq <= pv.co_sequence AND pha.to_co_seq > pv.co_sequence
                WHERE 
                    (plla.from_co_seq = pv.co_sequence
                    OR EXISTS (SELECT 
                                    'x' 
                                FROM 
                                    po_distributions_archive_all da1
                                WHERE 
                                    da1.line_location_id = plla.line_location_id
                                    AND da1.from_co_seq = pv.co_sequence
                                    AND da1.to_co_seq = 9999999
                                    AND plla.to_co_seq = 9999999
                                ) 
                    ) 
                ) line_locations ON line_locations.po_header_id = plaa.po_header_id AND line_locations.po_line_id = plaa.po_line_id AND line_locations.version_id = Version.version_id
    INNER JOIN (SELECT 
                    pdaa.po_header_id, 
                    pdaa.line_location_id, 
                    pdaa.po_line_id, 
                    pv.version_id,
                    pdaa.code_combination_id, 
                    ppn.display_name AS Requester
                FROM 
                    po_distributions_archive_all pdaa  
                    INNER JOIN po_versions pv on pdaa.po_header_id = pv.po_header_id AND pdaa.from_co_seq <= pv.co_sequence AND pdaa.to_co_seq > pv.co_sequence
                    INNER JOIN po_lines_archive_all plaa ON pdaa.po_line_id = plaa.po_line_id AND plaa.from_co_seq <= pv.co_sequence AND plaa.to_co_seq > pv.co_sequence
                    INNER JOIN po_headers_archive_all pha ON pha.po_header_id = pdaa.po_header_id AND pha.from_co_seq <= pv.co_sequence AND pha.to_co_seq > pv.co_sequence
                    INNER JOIN PER_PERSON_NAMES_F ppn ON pdaa.deliver_to_person_id = ppn.person_id
                WHERE 
                    ppn.name_type = 'GLOBAL'
                    AND TRUNC(SYSDATE) BETWEEN ppn.effective_start_date AND ppn.effective_end_date
                )line_dist ON line_dist.po_line_id = plaa.po_line_id AND line_dist.line_location_id = line_locations.line_location_id AND line_dist.po_header_id = plaa.po_header_id AND line_dist.version_id = version.version_id
    INNER JOIN PO_HEADERS_ARCHIVE_ALL PoHdr ON plaa.po_header_id = PoHdr.po_header_id AND PoHdr.from_co_seq <= Version.co_sequence AND PoHdr.to_co_seq > Version.co_sequence
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = line_dist.code_combination_id
    INNER JOIN EGP_CATEGORIES_B ecb ON ecb.category_id = plaa.category_id 
WHERE
    plaa.from_co_seq <= Version.co_sequence
    AND plaa.to_co_seq > Version.co_sequence
    AND (plaa.from_co_seq = Version.co_sequence
        OR EXISTS (SELECT 
                        'x' 
                    FROM 
                        po_line_locations_archive_all sa1
                    WHERE 
                        sa1.po_line_id = plaa.po_line_id
                        AND sa1.from_co_seq = Version.co_sequence
                        AND sa1.to_co_seq = 9999999
                        AND plaa.to_co_seq = 9999999
                    )
        OR EXISTS (SELECT 
                        'x' 
                    FROM 
                        po_distributions_archive_all da1
                    WHERE 
                        da1.po_line_id = plaa.po_line_id
                        AND da1.from_co_seq = Version.co_sequence
                        AND da1.to_co_seq = 9999999
                        AND plaa.to_co_seq = 9999999
                    ) 
        )                 
), 

Category_Code AS (
SELECT
    pa.po_header_id, 
    pa.version_id, 
    pl.line_num, 
    pa.co_num, 
    pl.line_status,
    CASE 
        WHEN ((pa.headerstatus IS NULL AND pl.line_status IS NULL) OR (pa.headerstatus IS NOT NULL AND pl.line_status IS NULL)) THEN COALESCE(pl.category_id, LAG(pl.category_id, 1) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.category_id, 2) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.category_id, 3) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.category_id, 4) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.category_id, 5) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.category_id, 6) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.category_id, 7) OVER (ORDER BY pa.po_header_id, pa.co_num))
        ELSE pl.category_id 
    END AS category_id,
    CASE 
        WHEN ((pa.headerstatus IS NULL AND pl.line_status IS NULL) OR (pa.headerstatus IS NOT NULL AND pl.line_status IS NULL)) THEN COALESCE(pl.categorycode, LAG(pl.categorycode, 1) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.categorycode, 2) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.categorycode, 3) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.categorycode, 4) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.categorycode, 5) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.categorycode, 6) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.categorycode, 7) OVER (ORDER BY pa.po_header_id, pa.co_num))
        ELSE pl.categorycode 
    END AS categorycode, 
    CASE 
        WHEN ((pa.headerstatus IS NULL AND pl.line_status IS NULL) OR (pa.headerstatus IS NOT NULL AND pl.line_status IS NULL)) THEN COALESCE(pl.entity, LAG(pl.entity, 1) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.entity, 2) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.entity, 3) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.entity, 4) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.entity, 5) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.entity, 6) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.entity, 7) OVER (ORDER BY pa.po_header_id, pa.co_num))
        ELSE pl.entity 
    END AS entity,
    CASE 
        WHEN ((pa.headerstatus IS NULL AND pl.line_status IS NULL) OR (pa.headerstatus IS NOT NULL AND pl.line_status IS NULL)) THEN COALESCE(pl.cost_centre, LAG(pl.cost_centre, 1) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.cost_centre, 2) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.cost_centre, 3) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.cost_centre, 4) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.cost_centre, 5) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.cost_centre, 6) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.cost_centre, 7) OVER (ORDER BY pa.po_header_id, pa.co_num))
        ELSE pl.cost_centre 
    END AS cost_centre,
    CASE 
        WHEN ((pa.headerstatus IS NULL AND pl.line_status IS NULL) OR (pa.headerstatus IS NOT NULL AND pl.line_status IS NULL)) THEN COALESCE(pl.activity, LAG(pl.activity, 1) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.activity, 2) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.activity, 3) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.activity, 4) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.activity, 5) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.activity, 6) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.activity, 7) OVER (ORDER BY pa.po_header_id, pa.co_num))
        ELSE pl.activity 
    END AS activity,
    CASE 
        WHEN ((pa.headerstatus IS NULL AND pl.line_status IS NULL) OR (pa.headerstatus IS NOT NULL AND pl.line_status IS NULL)) THEN COALESCE(pl.future, LAG(pl.future, 1) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.future, 2) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.future, 3) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.future, 4) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.future, 5) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.future, 6) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.future, 7) OVER (ORDER BY pa.po_header_id, pa.co_num))
        ELSE pl.future 
    END AS future,
    CASE 
        WHEN ((pa.headerstatus IS NULL AND pl.line_status IS NULL) OR (pa.headerstatus IS NOT NULL AND pl.line_status IS NULL)) THEN COALESCE(pl.natural_account, LAG(pl.natural_account, 1) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.natural_account, 2) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.natural_account, 3) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.natural_account, 4) OVER (ORDER BY pa.po_header_id, pa.co_num),LAG(pl.natural_account, 5) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.natural_account, 6) OVER (ORDER BY pa.po_header_id, pa.co_num), LAG(pl.natural_account, 7) OVER (ORDER BY pa.po_header_id, pa.co_num))
        ELSE pl.natural_account 
    END AS natural_account
FROM
    PO_Agreement_Header pa 
    LEFT JOIN PO_Agreement_Line pl ON pl.po_header_id = pa.po_header_id AND pl.version_id = pa.version_id
), 

Changer_order_person AS (
SELECT
    DISTINCT originator_id, 
    ppn.display_name AS Initiator_Name
FROM 
    PO_Agreement_Header ph 
    INNER JOIN per_person_names_f ppn ON ph.originator_id = ppn.person_id
WHERE 
    ppn.name_type = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN ppn.effective_start_date AND ppn.effective_end_date
)

SELECT 
    header.*,
    CASE 
        WHEN header.originator_role = 'SYSTEM' THEN 'System' 
        ELSE cop.Initiator_Name
    END AS Initiator_Name,
    CASE 
        WHEN header.HeaderStatus IS NULL AND line.line_status IS NULL THEN 'Header Amended'
        WHEN header.HeaderStatus ='Changed' AND line.Line_Status IS NULL THEN 'Header Amended'
        WHEN header.HeaderStatus = 'New' AND line.line_status = 'New' THEN 'Original Document'
        WHEN header.HeaderStatus IS NULL AND line.Line_Status = 'New' THEN 'Line Created'
        WHEN header.HeaderStatus ='Changed' AND line.Line_Status = 'New' THEN 'Line Created'
        WHEN line.line_status <> 'New' THEN 'Line Amended'
    END AS Status, 
    line.line_num, 
    line.item_revision, 
    line.item_description, 
    line.Requester,
    line.vendor_product_num, 
    line.line_type, 
    line.quantity, 
    line.pricing_uom_code, 
    line.base_qty, 
    line.base_uom, 
    line.unit_price, 
    line.PO_Ordered_Amount, 
    line.cancel_flag, 
    line.entity_change_type_code AS Entity_line_change_type_code, 
    line.Line_Status, 
    line.code_combination_id, 
    COALESCE(cc.entity, c.entity) AS Entity, 
    COALESCE(cc.Cost_Centre, c.cost_centre) AS Cost_Centre, 
    COALESCE(cc.natural_account, c.natural_account) AS Natural_Account, 
    COALESCE(cc.activity, c.activity) AS Activity, 
    COALESCE(cc.future, c.future) AS Future, 
    COALESCE(cc.category_id, c.category_id) AS category_id,
    COALESCE(cc.categorycode, c.categorycode) AS categorycode 
FROM 
    PO_Agreement_Header header
    LEFT JOIN PO_Agreement_Line line ON line.po_header_id = Header.po_header_id AND line.version_id = header.version_id
    LEFT JOIN Category_Code cc ON cc.po_header_id = header.po_header_id AND cc.version_id = header.version_id AND cc.line_num = line.line_num AND cc.co_num = header.co_num AND cc.line_status IS NOT NULL
    LEFT JOIN Category_Code c ON c.po_header_id = header.po_header_id AND c.version_id = header.version_id AND c.co_num = header.co_num AND c.line_status IS NULL
    LEFT JOIN Changer_order_person cop ON cop.originator_id = header.originator_id
WHERE 
    (COALESCE(NULL, :PO_Number) IS NULL OR header.po_number IN (:PO_Number))
    AND (COALESCE(NULL, :CostCentre) IS NULL OR COALESCE(cc.Cost_Centre, c.cost_centre) IN (:CostCentre))
    AND (COALESCE(NULL, :Category_Code) IS NULL OR COALESCE(cc.category_id, c.category_id) IN (:Category_Code))
    AND (COALESCE(NULL, :Business_Unit) IS NULL OR header.BusinessUnit IN (:Business_Unit))
    AND (COALESCE(NULL, :SupplierNum) IS NULL OR header.Supplier_Num IN (:SupplierNum))
ORDER BY 
    header.po_number, 
    header.co_num, 
    line.line_num



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

/* PO Number */
SELECT 
    DISTINCT poh.segment1 AS PO_Number
FROM 
PO_HEADERS_ALL poh 
    INNER JOIN PO_LINES_ALL pla ON pla.po_header_id = poh.po_header_id
    INNER JOIN PO_LINE_LOCATIONS_ALL pol ON poh.po_header_id = pol.po_header_id AND pol.po_line_id = pla.po_line_id 
    INNER JOIN PO_DISTRIBUTIONS_ALL pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pol.line_location_id
    INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = pod.code_combination_id
WHERE 
    (COALESCE(NULL, :CostCentre) IS NULL OR gcc.segment2 IN (:CostCentre))
ORDER BY 
    poh.segment1


/* Supplier */
SELECT 
    DISTINCT hp.party_name AS SupplierName,
    pz.segment1 AS Supplier_Num
FROM 
    PO_HEADERS_ALL poh 
    INNER JOIN HR_ORGANIZATION_UNITS_F_TL hou ON hou.organization_id = poh.prc_bu_id
    INNER JOIN POZ_SUPPLIERS pz ON poh.vendor_id = pz.vendor_id
    INNER JOIN HZ_PARTIES hp ON pz.party_id = hp.party_id  
WHERE
    (COALESCE(NULL, :Business_Unit) IS NULL OR hou.name  IN (:Business_Unit))
ORDER BY 
    hp.party_name