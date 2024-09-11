/* 
 Title - Buyer Created Invoice 
 Author - Simranjeet Singh
 Date - 09/09/2024
 Department - Finance 
 Description - 
 */
SELECT
    aia.invoice_id,
    aila.period_name,
    aia.invoice_num,
    aia.invoice_amount,
    TO_CHAR(aia.invoice_date, 'dd-MM-yyyy') AS invoice_date,
    aia.created_by,
    TO_CHAR(aia.creation_date, 'dd-MM-yyyy') AS invoice_creation_date,
    TO_CHAR(aia.gl_date, 'dd-MM-yyyy') AS gl_date,
    TO_CHAR(aila.Creation_Date, 'dd-MM-yyyy') AS invoice_line_creation_date,
    aia.description AS invoice_desc,
    aia.payment_status_flag,
    aila.description AS invoice_line_description,
    aila.created_by AS line_created_by,
    aila.last_updated_by AS line_last_updated_by,
    aila.line_type_lookup_code,
    CASE
        WHEN aila.line_type_lookup_code = 'TAX' THEN 'GST'
        ELSE NULL
    END AS line_code,
    aila.amount AS invoice_line_amount,
    aila.line_number,
    hou.name AS Business_Unit,
    pz.segment1 AS Supplier_num,
    hp.party_name AS Supplier_Name,
    hps.party_site_name AS Supplier_address,
    zr.tax_regime_code,
    CONCAT(
        CONCAT(
            SUBSTR(TO_CHAR(zr.registration_number), 1, 3),
            '-'
        ),
        CONCAT(
            SUBSTR(TO_CHAR(zr.registration_number), 4, 3),
            '-'
        )
    ) || SUBSTR(TO_CHAR(zr.registration_number), 7, 3) AS Supplier_gst,
    zr.effective_from,
    CASE
        WHEN hou.name = 'Crown' THEN '126-905-564'
        WHEN hou.name = 'Departmental' THEN '126-848-161'
    END AS Buyer_GST,
    'Ministry Of Housing and Urban Development' AS Buyer_Name,
    'PO Box 82 Wellington NZ 6140' AS Buyer_Address,
    re.remit_advice_email,
    aida.po_distribution_id,
    po.Purchase_Order_Number
FROM
    ap_invoices_all aia
    INNER JOIN ap_invoice_lines_all aila ON aia.invoice_id = aila.invoice_id
    INNER JOIN ap_invoice_distributions_all aida ON aida.invoice_id = aia.invoice_id
    AND aila.line_number = aida.invoice_line_number
    INNER JOIN hr_organization_units_f_tl hou ON hou.organization_id = aia.org_id
    INNER JOIN poz_suppliers pz ON aia.vendor_id = pz.vendor_id
    INNER JOIN hz_parties hp ON pz.party_id = hp.party_id
    INNER JOIN hz_party_sites hps ON hps.party_id = hp.party_id
    INNER JOIN zx_party_tax_profile zpt ON zpt.party_id = hp.party_id
    INNER JOIN zx_registrations zr ON zr.party_tax_profile_id = zpt.party_tax_profile_id
    INNER JOIN (
        SELECT
            DISTINCT iep.payee_party_id,
            iep.party_site_id,
            iep.supplier_site_id, 
            iep.remit_advice_email
        FROM
            iby_external_payees_all iep
        WHERE
            iep.remit_advice_email IS NOT NULL
    ) re ON re.payee_party_id = hps.party_id
    AND re.party_site_id = hps.party_site_id
    AND re.supplier_site_id = aia.vendor_site_id
    LEFT JOIN (
        SELECT
            DISTINCT
            /* Using DISTINCT as invoices can have multiple lines/distribution lines */
            poh.segment1 AS Purchase_Order_Number,
            pod.po_distribution_id
        FROM
            po_headers_all poh
            INNER JOIN po_lines_all pla ON pla.po_header_id = poh.po_header_id
            INNER JOIN po_distributions_all pod ON pla.po_header_id = pod.po_header_id
            AND pla.po_line_id = pod.po_line_id
    ) po ON po.po_distribution_id = aida.po_distribution_id
WHERE
    aia.approval_status = 'APPROVED'
    AND aila.line_type_lookup_code IN ('ITEM', 'TAX')
    AND (
        aila.discarded_flag = 'N'
        OR aila.discarded_flag IS NULL
    )
    AND (
        aida.reversal_flag = 'N'
        OR aida.reversal_flag IS NULL
    )
    AND aia.invoice_amount <> 0
    AND aila.amount <> 0
    AND aida.amount <> 0
    AND pz.vendor_type_lookup_code = 'BCI_SUPPLIER'
    AND zr.registration_number IS NOT NULL
    AND zr.effective_to IS NULL
    AND (
        COALESCE(NULL, :InvoiceNum) IS NULL
        OR aia.invoice_num IN (:InvoiceNum)
    )
    AND (
        COALESCE(NULL, :SupplierName) IS NULL
        OR hp.party_name IN (:SupplierName)
    )
ORDER BY
    aia.invoice_id,
    aila.line_number 
    
    
    ---------------------------------------------------Report Filters------------------------------------------------------------------
    /*Invoice Num Filter*/
SELECT
    DISTINCT aia.invoice_num
FROM
    ap_invoices_all aia
    INNER JOIN ap_invoice_lines_all aila ON aia.invoice_id = aila.invoice_id
    INNER JOIN poz_suppliers pz ON aia.vendor_id = pz.vendor_id
    INNER JOIN hz_parties hp ON pz.party_id = hp.party_id
    INNER JOIN hz_party_sites hps ON hps.party_id = hp.party_id
    INNER JOIN zx_party_tax_profile zpt ON zpt.party_id = hp.party_id
    INNER JOIN zx_registrations zr ON zr.party_tax_profile_id = zpt.party_tax_profile_id
WHERE
    aia.approval_status = 'APPROVED'
    AND aila.line_type_lookup_code IN ('ITEM', 'TAX')
    AND (
        aila.discarded_flag = 'N'
        OR aila.discarded_flag IS NULL
    )
    AND (
        aia.invoice_amount <> 0
        OR aila.amount <> 0
    )
    AND zr.registration_number IS NOT NULL
    AND pz.vendor_type_lookup_code = 'BCI_SUPPLIER'
    AND hp.party_name = :SupplierName
ORDER BY
    aia.invoice_num

    /*Supplier Name Filter*/
SELECT
    DISTINCT hp.party_name AS Supplier_Name
FROM
    poz_suppliers pz
    INNER JOIN hz_parties hp ON pz.party_id = hp.party_id
    INNER JOIN hz_party_sites hps ON hps.party_id = hp.party_id
    INNER JOIN zx_party_tax_profile zpt ON zpt.party_id = hp.party_id
    INNER JOIN zx_registrations zr ON zr.party_tax_profile_id = zpt.party_tax_profile_id
    INNER JOIN (
        SELECT
            DISTINCT iep.payee_party_id,
            iep.party_site_id,
            iep.remit_advice_email
        FROM
            iby_external_payees_all iep
        WHERE
            iep.remit_advice_email IS NOT NULL
    ) re ON re.payee_party_id = hps.party_id
    AND re.party_site_id = hps.party_site_id
    AND pz.vendor_type_lookup_code = 'BCI_SUPPLIER'
ORDER BY
    hp.party_name