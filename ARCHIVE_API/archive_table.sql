create or replace PROCEDURE archive_table (srcjson CLOB, archivejson CLOB)
IS
BEGIN

DECLARE
        /* example parameters 
        srcjson CLOB := ' {"opertype": "$1", 
                              "tablelist": "customers,orderdetails,orders", 
                              "sourceschema": "GEFA0728", 
                              "archtabledetails": {"tablename": "orderdetails","keycolumn":["DEFAULT_HASH_TYPE_CODE"]}, 
                              "masterkeydetails": {"keytable": "customers", 
                                                "keyvalue": "181", 
                                                "keycolumn": "customernumber"
                                               }, 
                            "tablerelationpath": " AND customers.customerid=orders.customerid AND orders.orderid=orderdetails.orderid"}' ;
        archivejson CLOB := '{
								"schema":,
								"tablename":orderdetails
						}';
        */
        
        sqlselquery CLOB :=' SELECT ';
        sqlinsert CLOB :=' INSERT INTO ';
        sqldelete CLOB :=' DELETE ';
        sqlnestedsel CLOB :=' SELECT ';
        sqlquery CLOB :='';
        answer CLOB :='';
        sqlfrom CLOB :='';
        sqlwhere CLOB :=' 1=1 ';
        sqlwhere2 CLOB :='';
        sqlwhere3 CLOB :='';
        sqlarchive CLOB :='';

        -- source table details
        vsourceschema VARCHAR2(100);
        vsourcetablename VARCHAR2(100);
        vsourceschematable VARCHAR(100);

        vcomma VARCHAR2(3);
        -- target archive table details
        varchiveschema VARCHAR(100);
        varchivetablename VARCHAR(100);
        varchiveschematable VARCHAR(100);

        --error code and description
        l_err_num number;
        l_err_desc varchar2(100);

        TYPE rlinkfilter_type is RECORD (right_table VARCHAR2(100),rightkeys VARCHAR2(100), left_table VARCHAR2(100), leftkeys VARCHAR2(100));
        TYPE tlinkfilter_type is TABLE OF rlinkfilter_type INDEX BY PLS_INTEGER;
        TYPE ttablistlist_type is TABLE OF VARCHAR2(100);
        TYPE tarchivekeycol_type is TABLE OF VARCHAR2(100);
        tlinkrec tlinkfilter_type;
        ttablelist ttablistlist_type;
        tarchivekeycol tarchivekeycol_type;
        dummytablelist ttablistlist_type:=ttablistlist_type('');
        /*
        srcjson CLOB :=  '{
                        "operation": "delete",
                        "archlevel":"study",
                        "sourceschema":"gefa0728",
                        "archtabledetails": {"tablename":"gdpr_table_fild"}, 
                        "masterkeydetails": {"keytable":"gdpr_hash_types" , "keycolumn":"hash_type_code", "keyvalue":"''COLUMN_PARTNERID''"},
                        "tablerelationpath":[
                                            { "righttable": "gdpr_table_field",
                                              "rightkeys": ["default_hash_type_code"], 
                                              "lefttable": "gdpr_hash_types",
                                              "leftkeys": ["hash_type_code"]
                                            }    
                                            ]
                            }';
            archivejson CLOB:= '{
                                    "schema":"gefa0728",
                                    "tablename":"archive_gdpr_table_field"
                            }';
                */
    begin

    -- Store the source schema and table to be archived vsourceschematable
    with p_document as
     (select srcjson as p_doc from dual)
      select sourceschema, sourcetablename, sourceschema || '.' || sourcetablename, sourceschema || '.' || sourcetablename || '.*' INTO vsourceschema, vsourcetablename, vsourceschematable, sqlquery
              from 
                p_document,
                 json_table ( p_doc, '$' 
                    COLUMNS (
                        sourceschema  PATH '$.sourceschema',
                        sourcetablename PATH '$.archtabledetails.tablename'
                          )
                    );


    -- store the target archive schema and the table
    with p_document as
     (select srcjson as p_doc from dual)
      select schemaname,tablename, schemaname || '.' || tablename    INTO varchiveschema, varchivetablename, varchiveschematable
              from 
                p_document,
                 json_table ( p_doc, '$' 
                    COLUMNS (
                        schemaname  PATH '$.schema',
                        tablename PATH '$.tablename'
                          )
                    );
    -- store the target archive schema and the table
    with p_document as
    (select srcjson as p_doc from dual)
    select  sqlwhere || tlinkrec INTO sqlwhere
              from 
                p_document,
                 json_table ( p_doc, '$' 
                    COLUMNS (
                        tlinkrec  path '$.tablerelationpath'
                          )
                    );
       
    
    with p_document2 as
    (select srcjson as p_doc from dual)
    select ' AND ' || keytable || '.' || keycolumn || '=' || keyvalue INTO sqlwhere2
    from 
    p_document2,
     json_table ( p_doc, '$.masterkeydetails' 
        COLUMNS (
            keytable  PATH '$.keytable',
            keycolumn PATH '$.keycolumn',
            keyvalue  PATH '$.keyvalue'
              )
        );

    
    /* from clause: extract the table list */
    with p_document as
    (select srcjson as p_doc from dual)
     select  sqlfrom || fromtablelist  into sqlfrom
              from 
                p_document,
                 json_table ( p_doc, '$' 
                    COLUMNS (
                        fromtablelist  path '$.tablelist'
                          )
                    );

        select ' AND deltable.ROWID' || '=' || vsourcetablename  || '.ROWID' INTO sqlwhere3 from dual;
         
        sqlselquery := sqlselquery || sqlquery || ' FROM ' || sqlfrom || ' WHERE ' || sqlwhere  || sqlwhere2 ;
        sqlnestedsel := sqlnestedsel || sqlquery || ' FROM ' || sqlfrom || ' WHERE ' || sqlwhere  || sqlwhere2 || sqlwhere3;
        sqlinsert :=  sqlinsert || varchiveschematable || ' ' ||  sqlselquery ;
        sqldelete := sqldelete || ' FROM ' || vsourceschematable  || ' deltable '  || ' WHERE EXISTS (' || sqlnestedsel || ')';
        
        /* Remove comment if you want to comment the generated code for archiving
        INSERT into logtable VALUES SELECT 'selected query:'||sqlselquery;
        INSERT into logtable VALUES SELECT 'delete query:'||sqldelete;
        INSERT into logtable VALUES SELECT 'archive insert query:'|| sqlinsert;
        */
        
        SAVEPOINT sp_archive;

--        EXECUTE IMMEDIATE  sqlinsert;
--        EXECUTE IMMEDIATE  sqldelete;

        DBMS_OUTPUT.PUT_LINE(sqlselquery);
        DBMS_OUTPUT.PUT_LINE(sqlinsert);
        DBMS_OUTPUT.PUT_LINE(sqldelete);

        EXCEPTION
            WHEN OTHERS THEN
                l_err_num := SQLCODE;
                l_err_desc := SQLERRM;
                -- if necessary you can put a insert statement or reassign to OUT variable
                dbms_output.put_line('custom message=>'||l_err_num ||': '||l_err_desc);
                ROLLBACK TO sp_archive;
            RAISE;
    COMMIT;
    END;
END archive_table;