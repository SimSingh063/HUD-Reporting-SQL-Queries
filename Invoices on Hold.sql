/* 
Title - Invoices on Hold Report
Author - Simranjeet Singh
Date - 12/03/2024
Department - Finance/Procurement 
Description - Report showing the list of invoices on hold and the reason behind it. 
*/

SELECT   
    inv_hold.*,   
    pha.segment1,   
    pla.line_num, 
    ppn.display_name AS Requestor_name
FROM (  
    SELECT  
        TO_CHAR(aia.invoice_date, 'dd-MM-yyyy') AS Invoice_date,     
        aia.invoice_id,    
        aia.invoice_num,  
        aia.invoice_amount,    
        aia.description AS invoice_description,    
        aha.hold_lookup_code,   
        aha.hold_reason,      
        alc.description AS lookup_description,   
        alc.displayed_field,   
        aha.line_location_id,
        hp.party_name AS Supplier_Name, 
        pz.segment1 AS Supplier_num,  
        hou.name AS Business_Unit, 
        zn.note_txt AS Note
    FROM    
        ap_invoices_all aia    
        INNER JOIN ap_holds_all aha ON aha.invoice_id = aia.invoice_id    
        INNER JOIN ap_lookup_codes alc ON alc.lookup_code = aha.hold_lookup_code 
        LEFT JOIN zmm_notes zn ON zn.source_object_uid = aia.invoice_id 
        INNER JOIN poz_suppliers pz ON aia.vendor_id = pz.vendor_id
        INNER JOIN hz_parties hp ON pz.party_id = hp.party_id 
        INNER JOIN hr_organization_units_f_tl hou ON hou.organization_id = aia.org_id
    WHERE    
        aha.release_lookup_code IS NULL    
        AND alc.lookup_type = 'HOLD CODE'  
    ) inv_hold   
    LEFT JOIN po_line_locations pll ON pll.line_location_id = inv_hold.line_location_id  
    LEFT JOIN po_lines_all pla ON pla.po_header_id = pll.po_header_id AND pla.po_line_id = pll.po_line_id 
    LEFT JOIN Po_distributions_all pod ON pla.po_header_id = pod.po_header_id AND pla.po_line_id = pod.po_line_id AND pod.line_location_id = pll.line_location_id  
    LEFT JOIN po_headers_all pha ON pha.po_header_id = pll.po_header_id  
    LEFT JOIN per_person_names_f ppn ON pod.deliver_to_person_id = ppn.person_id
WHERE 
    inv_hold.invoice_amount <> 0
    AND ppn.name_type = 'GLOBAL'
    AND (COALESCE(NULL, :HoldReason) IS NULL OR inv_hold.displayed_field IN (:HoldReason))
    AND (COALESCE(NULL, :BusinessUnit) IS NULL OR inv_hold.Business_Unit IN (:BusinessUnit))

/*------------------------------------FILTERS--------------------------------------*/

SELECT 
    DISTINCT alc.displayed_field
FROM    
    ap_invoices_all aia    
    INNER JOIN ap_holds_all aha ON aha.invoice_id = aia.invoice_id    
    INNER JOIN ap_lookup_codes alc ON alc.lookup_code = aha.hold_lookup_code    
WHERE    
    aha.release_lookup_code IS NULL    
    AND alc.lookup_type = 'HOLD CODE'  
    AND aha.hold_lookup_code <> 'INCOMPLETE INVOICE'
    