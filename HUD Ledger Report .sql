SELECT DISTINCT
    gjh.Name AS Journal_name, 
	gjh.Posting_acct_seq_value AS Accounting_Sequence_Number, 
	gjh.period_name, 
	gjl.je_header_id,
	gjl.currency_code AS Entered_Currency, 
	gjl.status AS status_type, 
	COALESCE(xal.gl_sl_link_id, gjl.gl_sl_link_id) AS LinkID,
	CASE
	    WHEN gjl.gl_sl_link_id IS NULL THEN COALESCE(xal.entered_dr, gjl.entered_dr, 0)
		ELSE gjl.entered_dr
	END -
	CASE 
	    WHEN gjl.gl_sl_link_id IS NULL THEN COALESCE(xal.entered_cr, gjl.entered_cr, 0)
		ELSE gjl.entered_cr
	END AS Entered_Amount,
	gcc.segment1 AS Entity_Type, 
	gcc.segment2 AS Cost_Centre, 
	gcc.segment3 AS Natural_Account,
    SUBSTR(TO_CHAR(gcc.segment3),1,1) AS Natural_Account_Classification,
	gcc.segment4 AS Activity_Type, 
	gcc.segment5 AS Future_Type, 
	gjc.USER_JE_CATEGORY_NAME AS Journal_Category, 
	gjs.je_source_key AS Journal_Source, 
	gjb.name AS Batch_Name, 
	gjb.je_batch_id, 
	TO_CHAR(gjb.Posted_Date, 'DD/MM/YYYY') AS Posted_Date, 
	xah.doc_sequence_value AS Document_Sequence_Number, 
	TO_CHAR(COALESCE(xah.Accounting_Date, gjh.default_effective_date), 'DD/MM/YYYY') AS GL_Date, 
	xte.transaction_number, 
	COALESCE(inv.created_by,txn.created_by, gjl.created_by) AS Createdby, 
	REPLACE(REPLACE(COALESCE(inv.hdr, txn.hdr, xal.description, gjl.Description), CHR(13), ' '), CHR(10), ' ') AS Description, 
	COALESCE(inv.typ, txn.typ, fdsc.description, 'Journal') AS DocumentType, 
	inv.PO_NUMBER, 
	COALESCE(xal.ae_line_num, gjl.je_line_num) AS journal_line,
	gl_flexfields_pkg.get_concat_description(gcc.chart_of_accounts_id,gcc.code_combination_id) coa_desc,
	CASE 
        WHEN inv.typ = 'AP Invoice' THEN inv.PO_VENDOR_NAME  
        WHEN txn.typ = 'Invoice Payments' THEN txn.PO_VENDOR_NAME  
        ELSE NULL  
    END AS SupplierName,  
     CASE
        WHEN TXN.TYP = 'Expense Claim' THEN TXN.PO_VENDOR_NAME  
        WHEN TXN.TYP = 'Expense Payments' THEN TXN.PO_VENDOR_NAME  
        ELSE NULL  
    END AS EmployeeName,  
    CASE
        WHEN inv.TYP = 'AP Invoice' THEN inv.VENDOR_NUM  
        WHEN TXN.TYP = 'Invoice Payments' THEN TXN.VENDOR_NUM  
        ELSE NULL  
    END AS SupplierNum,
	CASE
        WHEN TXN.TYP = 'Expense Claim' THEN TXN.vendor_num  
        WHEN TXN.TYP = 'Expense Payments' THEN TXN.vendor_num  
        ELSE NULL       
	END AS EmployeeNum
FROM 
    GL_JE_HEADERS gjh
	INNER JOIN GL_JE_LINES gjl ON gjl.je_header_id = gjh.je_header_id
	INNER JOIN GL_JE_CATEGORIES gjc ON gjc.je_category_name = gjh.je_category
	INNER JOIN GL_CODE_COMBINATIONS gcc ON gcc.code_combination_id = gjl.code_combination_id
	LEFT JOIN GL_JE_BATCHES gjb ON gjb.je_batch_id = gjh.je_batch_id
	LEFT JOIN GL_IMPORT_REFERENCES gir ON gir.je_header_id = gjl.je_header_id AND gir.je_line_num = gjl.je_line_num
	LEFT JOIN XLA_AE_LINES xal ON xal.gl_sl_link_id = COALESCE(gjl.gl_sl_link_id, gir.gl_sl_link_id)
	LEFT JOIN XLA_AE_HEADERS xah ON xah.ae_header_id = xal.ae_header_id
	LEFT JOIN XLA_TRANSACTION_ENTITIES xte ON xte.entity_id = xah.entity_id
	LEFT JOIN FND_DOC_SEQUENCE_CATEGORIES fdsc ON fdsc.code = xah.doc_category_code 
	LEFT JOIN GL_JE_SOURCES_B gjs ON gjs.JE_SOURCE_NAME = gjh.je_source
	LEFT JOIN (
	           SELECT DISTINCT
                    'AP_INVOICES' AS Entity_code, 
                    xah.ae_header_id,
					ael.ae_line_num,
					aia.invoice_id, 
					aia.invoice_num, 
					aia.payment_status_flag AS Payment_status, 
					aia.invoice_currency_code AS Invoice_currency, 
					aia.invoice_amount, 
					aia.total_tax_amount AS Tax_amount,
					pha.segment1 po_number, 
					posv.vendor_name AS PO_vendor_name, 
					aia.invoice_date, 
					aia.created_by, 
					aia.creation_date, 
					aia.description AS Hdr,  
					posv.segment1 AS vendor_num, 
					200 AS Appl_id, 
					'AP Invoice' AS Typ  
				FROM 
				    ap_invoices_all aia  
					INNER JOIN ap_invoice_lines_all aila ON aia.invoice_id = aila.invoice_id  
					INNER JOIN ap_invoice_distributions_all aida ON aida.invoice_id = aia.invoice_id AND aila.line_number = aida.invoice_line_number
					INNER JOIN po_distributions_all pda ON aida.po_distribution_id = pda.po_distribution_id  
					INNER JOIN po_lines_all pla ON pla.po_line_id = pda.po_line_id
					INNER JOIN po_headers_all pha ON pha.po_header_id = pla.po_header_id 
					INNER JOIN poz_suppliers_v posv ON aia.vendor_id = posv.vendor_id
					INNER JOIN xla_distribution_links xdl ON aida.invoice_distribution_id = xdl.source_distribution_id_num_1 AND aida.distribution_line_number = xdl.ae_line_num 
					INNER JOIN xla_ae_lines ael ON ael.ae_line_num = xdl.ae_line_num
					INNER JOIN xla_ae_headers xah ON xah.ae_header_id = xdl.ae_header_id
                WHERE  
					aia.approval_status = 'APPROVED'
                    AND aila.line_type_lookup_code = 'ITEM'
                    AND aida.line_type_lookup_code = 'ITEM'
                    AND aila.discarded_flag = 'N'
                ) inv ON inv.Invoice_id = xte.source_id_int_1 AND inv.appl_id = xte.application_id AND inv.entity_code = xte.entity_code AND inv.ae_header_id = xah.ae_header_id AND inv.ae_line_num = xal.ae_line_num
    LEFT JOIN (		   
			   SELECT   
			       'AP_INVOICES' AS ENTITY_CODE,  
				   API.INVOICE_ID,  
				   API.INVOICE_NUM,  
				   API.PAYMENT_STATUS_FLAG AS PAYMENT_STATUS,  
				   API.INVOICE_CURRENCY_CODE AS INVOICE_CURRENCY,  
				   API.INVOICE_AMOUNT,  
				   API.TOTAL_TAX_AMOUNT AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   hp.PARTY_NAME AS PO_VENDOR_NAME,  
				   api.invoice_date,  
				   api.created_by,  
				   api.creation_date,  
				   api.description AS hdr,  
				   PAP.PERSON_NUMBER AS vendor_num,  
				   200 AS APPL_ID,  
				   'Expense Claim' AS typ  
			   FROM   
			       AP_INVOICES_ALL API  
				   INNER JOIN hz_parties hp ON API.party_id = hp.party_id  
				   INNER JOIN HZ_ORIG_SYS_REFERENCES HSR ON hp.PARTY_ID = HSR.OWNER_TABLE_ID 
				   INNER JOIN PER_ALL_PEOPLE_F PAP ON PAP.PERSON_ID = HSR.ORIG_SYSTEM_REFERENCE  
			   WHERE   
			       API.SOURCE = 'EMP_EXPENSE_REPORT'  
				   AND hp.PARTY_TYPE = 'PERSON'  
				   AND HSR.ORIG_SYSTEM = 'FUSION_HCM'  
				   AND HSR.OWNER_TABLE_NAME = 'HZ_PARTIES'  
  
               UNION ALL 

               SELECT   
                   'TRANSACTIONS' AS ENTITY_CODE, 
				   rct.customer_trx_id AS INVOICE_ID,  
				   rct.trx_number AS INVOICE_NUM,  
				   NULL AS PAYMENT_STATUS,  
				   rct.INVOICE_CURRENCY_CODE AS INVOICE_CURRENCY,  
				   aps.amount_due_original AS INVOICE_AMOUNT,  
				   aps.tax_original AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   hp.party_name AS PO_VENDOR_NAME,  
				   rct.trx_date,  
				   rct.created_by,  
				   rct.creation_date,  
				   rct.comments,  
				   NULL AS vendor_num,  
				   222 AS APPL_ID, 
				   'AR Invoice' AS typ  
               FROM   
                   ra_customer_trx_all rct  
				   INNER JOIN ar_payment_schedules_all aps ON rct.customer_trx_id = aps.customer_trx_id  
				   INNER JOIN hz_cust_accounts hca ON aps.customer_id = hca.cust_account_id  
				   INNER JOIN hz_parties hp ON hca.party_id = hp.party_id  
  
               UNION ALL  
  
               SELECT   
                  'RECEIPTS' AS ENTITY_CODE,  
				  acr.cash_receipt_id AS INVOICE_ID,  
				  acr.receipt_number AS INVOICE_NUM,  
				  NULL AS PAYMENT_STATUS,  
				  acr.currency_code AS INVOICE_CURRENCY,  
				  acr.amount AS INVOICE_AMOUNT,  
				  acr.TAX_AMOUNT,  
				  NULL AS PO_NUMBER,  
				  hp.party_name AS PO_VENDOR_NAME,  
				  acr.receipt_date,  
				  acr.created_by,  
				  acr.creation_date,  
				  acr.comments,  
				  NULL AS vendor_num,  
				  222 AS APPL_ID,  
				  'AR Receipts' AS typ				  
			   FROM   
                  ar_cash_receipts_all acr  
				  INNER JOIN hz_cust_accounts hca ON acr.pay_from_customer = hca.cust_account_id  
				  INNER JOIN hz_parties hp ON hca.party_id = hp.party_id  
  
               UNION ALL

               SELECT   
                   'AP_PAYMENTS' AS ENTITY_CODE,  
				   ac.check_id AS INVOICE_ID,  
				   NULL AS INVOICE_NUM,  
				   NULL AS PAYMENT_STATUS,  
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   ac.vendor_name AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   ac.created_by,  
				   ac.creation_date,  
				   ac.description,  
				   POSV.segment1 AS vendor_num,  
				   200 AS APPL_ID,  
				   'Invoice Payments' AS typ  
               FROM   
			       ap_checks_all ac  
				   INNER JOIN POZ_SUPPLIERS_V POSV ON ac.VENDOR_ID = POSV.VENDOR_ID  
  
               UNION ALL  
  
               SELECT   
                   'AP_PAYMENTS' AS ENTITY_CODE,  
				   ac.check_id AS INVOICE_ID,  
				   NULL AS INVOICE_NUM,  
				   NULL AS PAYMENT_STATUS, 
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   ac.vendor_name AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   ac.created_by,  
				   ac.creation_date,  
				   ac.description,  
				   PAP.PERSON_NUMBER AS vendor_num,  
				   200 AS APPL_ID,  
				   'Expense Payments' AS typ  
               FROM   
			       ap_checks_all ac  
				   INNER JOIN hz_parties hp ON ac.party_id = hp.party_id  
				   INNER JOIN HZ_ORIG_SYS_REFERENCES HSR ON hp.PARTY_ID = HSR.OWNER_TABLE_ID
				   INNER JOIN PER_ALL_PEOPLE_F PAP ON PAP.PERSON_ID = HSR.ORIG_SYSTEM_REFERENCE  
               WHERE   
                   hp.PARTY_TYPE = 'PERSON'  
				   AND HSR.ORIG_SYSTEM = 'FUSION_HCM' 
				   AND HSR.OWNER_TABLE_NAME = 'HZ_PARTIES'  
  
               UNION ALL

               SELECT   
                   'DEPRECIATION' AS entity_code,   
				   fav.asset_id,   
				   fav.asset_number,  
				   NULL AS PAYMENT_STATUS,  
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   NULL AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   fav.created_by,  
				   fav.creation_date,  
				   fav.description AS hdr,  
				   NULL AS vendor_num,  
				   140 AS APPL_ID,  
				   'FA' AS typ  
               FROM   
                   fa_additions_vl fav  
  
               UNION ALL  
  
               SELECT   
                   'LEASE_EXPENSE' AS entity_code,   
				   fav.asset_id,   
				   fav.asset_number,  
				   NULL AS PAYMENT_STATUS,  
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   NULL AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   fav.created_by,  
				   fav.creation_date,  
				   fav.description AS hdr,  
				   NULL AS vendor_num,  
				   140 AS APPL_ID,  
				   'FA' AS typ  
               FROM   
			       fa_additions_vl fav  
  
               UNION ALL  
  
               SELECT   
                   'TRANSACTIONS' AS entity_code,   
				   fth.transaction_header_id,   
				   fav.asset_number,  
				   NULL AS PAYMENT_STATUS,  
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   NULL AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   fav.created_by,  
				   fav.creation_date,  
				   fav.description AS hdr,  
				   NULL AS vendor_num,  
				   140 AS APPL_ID,  
				   'FA' AS typ  
               FROM   
                   fa_additions_vl fav  
                   INNER JOIN fa_transaction_headers fth ON fav.asset_id = fth.asset_id 
  
               UNION ALL 

               SELECT   
                   cre.entity_code,  
				   cre.accounting_event_id,  
				   ct.receipt_number,  
				   NULL AS PAYMENT_STATUS,  
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   pha.segment1 AS PO_NUMBER,  
				   POSV.VENDOR_NAME AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   rt.created_by,  
				   rt.creation_date,  
				   pha.comments AS hdr,  
				   NULL AS vendor_num,  
				   10096 AS APPL_ID,  
				   'GRN' AS typ  
               FROM   
                   cmr_rcv_events cre  
				   INNER JOIN cmr_transactions ct ON cre.transaction_id = ct.transaction_id  
				   INNER JOIN rcv_transactions rt ON ct.rcv_transaction_id = rt.transaction_id  
				   INNER JOIN po_lines_all pla ON rt.po_line_id = pla.po_line_id  
				   INNER JOIN po_headers_all pha ON rt.po_header_id = pha.po_header_id  
				   INNER JOIN POZ_SUPPLIERS_V POSV ON posv.vendor_id = pha.vendor_id  
               WHERE   
                   cre.EVENT_TXN_TABLE_NAME = 'CMR_TRANSACTIONS'  
  
               UNION ALL 
  
               SELECT   
                   cre.entity_code,  
				   cre.accounting_event_id,  
				   ct.receipt_number,  
				   NULL AS PAYMENT_STATUS,  
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   pha.segment1 AS PO_NUMBER,  
				   POSV.VENDOR_NAME AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   rt.created_by,  
				   rt.creation_date,  
				   pha.comments AS hdr,  
				   NULL AS vendor_num,  
				   10096 AS APPL_ID,  
				   'GRN' AS typ  
               FROM   
                   cmr_rcv_events cre  
				   INNER JOIN CMR_AP_INVOICE_DTLS caid ON cre.EVENT_TRANSACTION_ID = caid.CMR_AP_INVOICE_DIST_ID  
				   INNER JOIN cmr_transactions ct ON caid.CMR_RCV_TRANSACTION_ID = ct.CMR_RCV_TRANSACTION_ID  
				   INNER JOIN rcv_transactions rt ON ct.rcv_transaction_id = rt.transaction_id  
				   INNER JOIN po_lines_all pla ON rt.po_line_id = pla.po_line_id  
				   INNER JOIN po_headers_all pha ON rt.po_header_id = pha.po_header_id  
				   INNER JOIN POZ_SUPPLIERS_V POSV ON posv.vendor_id = pha.vendor_id  
               WHERE   
                   cre.EVENT_TXN_TABLE_NAME = 'CMR_AP_INVOICE_DTLS'  
  
               UNION ALL  
  
               SELECT   
                   'CE_EXTERNAL' AS entity_code,  
				   cet.transaction_id,  
				   TO_CHAR(cet.transaction_id) AS transaction_id,  
				   NULL AS PAYMENT_STATUS,  
				   NULL AS INVOICE_CURRENCY,  
				   NULL AS INVOICE_AMOUNT,  
				   NULL AS TAX_AMOUNT,  
				   NULL AS PO_NUMBER,  
				   NULL AS PO_VENDOR_NAME,  
				   NULL AS receipt_date,  
				   cet.created_by,  
				   cet.creation_date,  
				   NULL AS hdr,  
				   NULL AS vendor_num,  
				   260 AS APPL_ID,  
				   'CE' AS typ  
               FROM   
			       ce_external_transactions cet
			  )txn ON txn.Invoice_id = xte.source_id_int_1 AND txn.appl_id = xte.application_id AND txn.entity_code = xte.entity_code			   
WHERE 
	(COALESCE(NULL, :Status) IS NULL OR gjl.status IN (:Status))  
    AND (COALESCE(NULL, :CostCentre) IS NULL OR gcc.segment2 IN (:CostCentre))  
    AND (COALESCE(NULL, :AccountCode) IS NULL OR gcc.segment3 IN (:AccountCode))  
    AND (COALESCE(NULL, :Period) IS NULL OR gjh.period_name IN (:Period))  
    AND (COALESCE(NULL, :Source) IS NULL OR gjh.JE_SOURCE IN (:Source))
	AND (COALESCE(NULL, :Activity) IS NULL OR gcc.segment4 IN (:Activity))
	AND (COALESCE(NULL, :Future) IS NULL OR gcc.segment5 IN (:Future))
	AND (COALESCE(NULL, :Entity) IS NULL OR gcc.segment1 IN (:Entity))
    AND NVL(xah.Accounting_Date, gjh.default_effective_date) BETWEEN NVL (:DATE_FROM, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AND NVL (:DATE_TO, TO_DATE('01/01/2100', 'DD/MM/YYYY'))
ORDER BY 
    GL_Date,
	gjh.name,
	xte.transaction_number 

/* List of Values SQL Query*/
/* Source */
SELECT
    DISTINCT je_source_key, 
	je_source_name
FROM
	GL_JE_SOURCES_B
ORDER BY
    je_source_key

/* Status */
SELECT 
    DISTINCT status
FROM 
    GL_JE_LINES
ORDER BY 
    status 

/* Cost Centre */
SELECT 
    DISTINCT segment2 
FROM 
    GL_CODE_COMBINATIONS
ORDER BY 
    segment2 

/* Account */
SELECT 
    DISTINCT segment3
FROM 
    GL_CODE_COMBINATIONS
ORDER BY 
    segment3

/* Period */
SELECT
    Period.Period_name
FROM
    (SELECT
        DISTINCT period_name, 
		EXTRACT(MONTH FROM Default_Effective_Date) Period_Month,
	    EXTRACT(YEAR FROM Default_Effective_Date) Period_Year
     FROM
        GL_JE_HEADERS
     ORDER BY 
        Period_year DESC,
		Period_month DESC, 
        period_name 
	)Period	
	
/* Entity */
SELECT 
    DISTINCT segment1
FROM 
    GL_CODE_COMBINATIONS
ORDER BY 
    segment1

/* Activity */
SELECT 
    DISTINCT segment4
FROM 
    GL_CODE_COMBINATIONS
ORDER BY 
    segment4
	
/* Future */
SELECT 
    DISTINCT segment5
FROM 
    GL_CODE_COMBINATIONS
ORDER BY 
    segment5
