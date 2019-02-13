DECLARE
  SRCJSON CLOB;
  ARCHIVEJSON CLOB;
BEGIN
  SRCJSON := '{
                        "operation": "delete",
                        "archlevel":"study",
                        "sourceschema":"gefa0728",
                        "archtabledetails": {"tablename":"gdpr_table_field","keycolumn":["DEFAULT_HASH_TYPE_CODE"]}, 
                        "masterkeydetails": {"keytable":"gdpr_hash_types" , "keycolumn":"hash_type_code", "keyvalue":"''COLUMN_PARTNERID''"},
                        "tablerelationpath":[
                                            { "righttable": "gdpr_table_field",
                                              "rightkeys": ["default_hash_type_code"], 
                                              "lefttable": "gdpr_hash_types",
                                              "leftkeys": ["hash_type_code"]
                                            }    
                                            ]
                            }';
  ARCHIVEJSON := '{
								"schema":"gefa0728",
								"tablename":"archive_gdpr_table_field"
						}';

  ARCHIVE_CDR(
    SRCJSON => SRCJSON,
    ARCHIVEJSON => ARCHIVEJSON
  );
--rollback; 
END;
