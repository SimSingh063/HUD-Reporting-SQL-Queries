/* 
Title - New Supplier Requisition Alert Report
Author - Tathagata Mukherjee
Date - 18/09/2023
Description - A custom alert report created for the Procurement team as a part of the Aho Q2 enhancements to alert the team members via email if a new requisition is submitted with the ‘New Supplier’ flag checked 
*/

SELECT
    DISTINCT prha.Requisition_number, 
    prha.Description, 
    prha.document_status AS Status,  
    prla.line_Number, 
    prla.Unit_Price, 
    prla.Quantity, 
    prla.uom_code AS UOM, 
    prla.suggested_vendor_name,
    prla.suggested_vendor_site AS Site, 
    prla.suggested_vendor_contact_phone AS Phone, 
    prla.suggested_vendor_contact_email AS Email, 
    prla.suggested_supplier_item_number AS Item_Number
FROM 
    POR_REQUISITION_HEADERS_ALL prha 
    INNER JOIN POR_REQUISITION_LINES_ALL prla ON prha.requisition_header_id = prla.requisition_header_id
WHERE 
    prla.new_supplier_flag = 'Y'
    AND prha.submission_date > SYSDATE-1
ORDER BY 
    prha.requisition_number DESC

/* Event Tigger */
SELECT
    'true'
FROM
    POR_REQUISITION_HEADERS_ALL prha 
    INNER JOIN POR_REQUISITION_LINES_ALL prla ON prha.requisition_header_id = prla.requisition_header_id
WHERE 
    prla.new_supplier_flag = 'Y'
    AND prha.submission_date > SYSDATE-1


