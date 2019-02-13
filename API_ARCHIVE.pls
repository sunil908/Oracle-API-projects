create or replace PROCEDURE archive_cdr (srcjson CLOB, archivejson CLOB)
IS
BEGIN
    declare 
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
                        "archtabledetails": {"tablename":"gdpr_table_fild","keycolumn":["DEFAULT_HASH_TYPE_CODE"]}, 
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
     (select archivejson as p_doc from dual)
      select schemaname,tablename, schemaname || '.' || tablename    INTO varchiveschema, varchivetablename, varchiveschematable
              from 
                p_document,
                 json_table ( p_doc, '$' 
                    COLUMNS (
                        schemaname  PATH '$.schema',
                        tablename PATH '$.tablename'
                          )
                    );


    with p_document as
    (select srcjson as p_doc from dual)
    select a.right_table, a.rightkeys, b.left_table, b.leftkeys BULK COLLECT INTO tlinkrec
    --' AND ' || right_table||'.'||rightkeys || ' = ' || left_table || ' . ' || leftkeys 
    from 
            (
            select rightside.* from
            (
            select 'right' as tabletype,key_row_number,row_number,right_table ,rightkeys  from 
                        p_document,
                         json_table ( p_doc, '$.tablerelationpath[*]' 
                            COLUMNS (
                                row_number FOR ORDINALITY,
                                right_table path '$.righttable',
                                NESTED PATH '$.rightkeys[*]' columns (
                                    key_row_number FOR ORDINALITY,
                                   "rightkeys" path '$' null on error
                                    )
                            )
                         )
            ) rightside
        ) a
    LEFT join (
        select leftside.* from (
              select 'left' as tabletype,key_row_number,row_number,left_table, leftkeys from 
                p_document,
                 json_table ( p_doc, '$.tablerelationpath[*]' 
                    COLUMNS (
                        row_number FOR ORDINALITY,
                        left_table  PATH '$.lefttable',
                        NESTED PATH '$.leftkeys[*]' columns (
                            key_row_number FOR ORDINALITY,
                           "leftkeys" path '$' null on error
                            )
                    )
                 )
              ) leftside
        ) b
      ON  a.row_number=b.row_number AND a.key_row_number=b.key_row_number;

    FOR i IN tlinkrec.FIRST .. tlinkrec.LAST
    LOOP
        sqlwhere := sqlwhere || ' AND ' || tlinkrec(i).right_table || '.' || tlinkrec(i).rightkeys || '='|| tlinkrec(i).left_table || '.' || tlinkrec(i).leftkeys;
    END LOOP;

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


    -- from clause buildup
    with p_document as
    (select srcjson as p_doc from dual)
    select tablename BULK COLLECT INTO ttablelist
    from 
    (
    select row_number,tablename from 
                        p_document,
                         json_table ( p_doc, '$' 
                            COLUMNS (
                                row_number FOR ORDINALITY,
                                tablename path '$.archtabledetails.tablename'
                                )
                            )
    UNION
    select row_number,tablename from 
                        p_document,
                         json_table ( p_doc, '$.tablerelationpath[*]' 
                            COLUMNS (
                                row_number FOR ORDINALITY,
                                tablename path '$.righttable'
                                )
                            )
        UNION
    select row_number,tablename from 
                        p_document,
                         json_table ( p_doc, '$.tablerelationpath[*]' 
                            COLUMNS (
                                row_number FOR ORDINALITY,
                                tablename path '$.lefttable'
                                )
                            )
    ) fromtablenames;

    -- deduplicate the tablelist before forming the expression
    ttablelist := SET(ttablelist);

    -- Initial assignment
    FOR i IN ttablelist.FIRST .. ttablelist.LAST
    LOOP
        IF(i=1) THEN 
                vcomma:='';
        ELSE 
                vcomma:=', '; 
        END IF;

        sqlfrom := sqlfrom || vcomma || vsourceschema || '.' || ttablelist(i);
        --dbms_output.put_line('tablename: '||ttablelist(i));
    END LOOP;



    -- nested query for deletion operation
    with p_document as
     (select srcjson as p_doc from dual)
      select keycolumns BULK COLLECT INTO tarchivekeycol
              from 
                p_document,
                 json_table ( p_doc, '$.archtabledetails' 
                    COLUMNS (
                        NESTED PATH '$.keycolumn[*]' columns (
                            key_row_number FOR ORDINALITY,
                           "keycolumns" path '$' null on error
                            )
                          )
                    );
        -- final where clause to form nested query in sqldelete. This is used to find records from archiving table
        FOR i IN tarchivekeycol.FIRST .. tarchivekeycol.LAST
        LOOP
            sqlwhere3 := sqlwhere3 || ' AND ' || 'deltable.' || tarchivekeycol(i) || 
                                    '=' || vsourceschematable || '.' || tarchivekeycol(i) ;
            --dbms_output.put_line('tablename: '||ttablelist(i));
        END LOOP;

        sqlselquery := sqlselquery || sqlquery || ' FROM ' || sqlfrom || ' WHERE ' || sqlwhere  || sqlwhere2 ;
        sqlnestedsel := sqlnestedsel || sqlquery || ' FROM ' || sqlfrom || ' WHERE ' || sqlwhere  || sqlwhere2 || sqlwhere3;
        sqlinsert :=  sqlinsert || varchiveschematable || ' ' ||  sqlselquery ;
        sqldelete := sqldelete || ' FROM ' || vsourceschematable  || ' deltable '  || ' WHERE EXISTS (' || sqlnestedsel || ')';

        SAVEPOINT sp_archive;

        EXECUTE IMMEDIATE  sqlinsert;
        EXECUTE IMMEDIATE  sqldelete;

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
END archive_cdr;
