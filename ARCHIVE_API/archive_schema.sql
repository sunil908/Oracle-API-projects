create or replace PROCEDURE archive_schema (
    voperatype IN varchar, 
    vmastertablename IN varchar,
    vmasterkeycolumnname IN varchar,
    vmasterkeyvalue IN varchar,
    varchiveschema IN varchar
)
IS
BEGIN
/* Example all: CALL archive_schema('','customers','customernumber','181','gdpr_archive') */
DECLARE
    /* points to schema where the source table resides. Currently only take the user schema 
    in which it is running. */
    vschema  VARCHAR(200);
    
    /* variables to hold the 'from' clause and the 'where' clause */
    vtablelist clob;
    vrelationcond clob;

    /* json parameter that is passed to the archive table procedure */    
    varchivejson clob;
    vsourcejson clob;
	
    varchiveprefix VARCHAR(200);
    tablecount INTEGER;
    vrelmapcount INTEGER;
    
    TYPE nodetyp IS RECORD (Nodename VARCHAR(200), tableorder INTEGER);
    
    /* hold all the tablenames (nodes) for processing */
    CURSOR cursor_tablelist  IS SELECT Nodename, tableorder from dijnodes order by tableorder DESC;
    node cursor_tablelist%ROWTYPE;
    
BEGIN
     
    /*  
     --Example paramter values 
     voperatype := 'archive' ; -- not used not currently
     vmastertablename := 'customers';
     vmasterkeycolumnname := 'customernumber';
     vmasterkeyvalue := '181';
     varchiveschema  := 'test';
    */
     
     varchiveprefix := '';

   
     select sys_context( 'userenv', 'current_schema' ) into vschema from dual;

     -- Cleanup the nodes and path for this execution   
     EXECUTE IMMEDIATE 'TRUNCATE TABLE dijnodes';
     EXECUTE IMMEDIATE 'TRUNCATE TABLE dijpaths';

    -- Build the nodes and paths data from the rel_ex data that is provided to this algorithm
    INSERT INTO dijnodes (nodename) 
            SELECT  tablename from (SELECT tablename from rel_ex  UNION select referredtablename as tablename from rel_ex) table_union;
    
    UPDATE dijnodes
    SET  tableorder =(SELECT COALESCE(a.TopologyOrderNum,0)  
            from dijnodes b LEFT JOIN rel_ex a 
            ON a.ReferredTableName=b.Nodename 
            WHERE dijnodes.Nodename=b.Nodename
    );

    INSERT INTO dijpaths(FromNodeID, ToNodeID, Costs, RelationReferenceID ) 
                SELECT  
        b1.NodeID, 
        b2.NodeID, 1, 
        ReferenceID 
    from   rel_ex a
         , dijnodes b1 
         , dijnodes b2
    where b1.Nodename=a.tablename
    AND b2.Nodename=a.ReferredTableName;
   
   
      OPEN cursor_tablelist ;
      LOOP

        FETCH cursor_tablelist INTO node;
        
        EXIT WHEN cursor_tablelist%NOTFOUND;
        
        vrelationcond :='';
        vtablelist :='';
        
        dbms_output.put_line('call on the loop: '|| vmastertablename || ' AND  '||node.Nodename);
        dijresolve(vmastertablename,node.Nodename);

            BEGIN
            select count(*) into vrelmapcount from relmap;
            EXCEPTION
            WHEN NO_DATA_FOUND then
                    vrelmapcount:=0;
            END;
            
            IF (vmastertablename<>node.Nodename AND vrelmapcount=0) THEN
                INSERT INTO logtable SELECT 'Warning: Path doesnt exists for from=' || vmastertablename || ' To=' || node.Nodename from dual;
                CONTINUE;
            END IF;
    
        select
            LISTAGG(tablename, ',') WITHIN GROUP (ORDER BY tablename) INTO vtablelist
        FROM   
            (SELECT fromnodename tablename from relmap 
                UNION SELECT tonodename tablename from relmap 
                UNION select vmastertablename from dual) tablist;

      
        select 
                LISTAGG(' AND '||b.tablename||'.'||b.columnname||'='||b.ReferredTableName||'.'||b.ReferredColumnName, '') 
                WITHIN GROUP (ORDER BY tablename) INTO vrelationcond
        from 
            relmap a,
            rel_ex b
        where a.RelationReferenceID=b.ReferenceID;
    
    /* 
        $1 : OperType - Currently not used. But signals what type of operations you may want to perform.
        $2 : tablelist - compiles list of tables that forms the path from master table to the source table.
        $3 : sourceschema - source schema is the current schema in which the source table to be archived exists.
        $4 : archtabledtails - we collect information on where is the archive table for moving the archive records. It 
                                is currently assigned as the source table name.
        $5 : masterkeydetails -> keytable - It assigns the seeding table from where the master record is choosen to archive. Its 
                                also starting point for searching the path until the source table.
        $6 : masterkeydetails -> keycolumn - Column frmo master table that will be used to select records from master table. It will use value 
                                column to select the records for filtering.
        $7 : masterkeydetails -> keyvalue - Column value to select records from the master table for archiving the related records across 
                                the schema.
        $8 : relationshippath : relatinship path between master table until the source table in the realationship hieararchy.                                
     */
    
    vsourcejson := '{"opertype": "$1", 
      "tablelist": "$2", 
      "sourceschema": "$3", 
      "archtabledetails": {"tablename": "$4"}, 
      "masterkeydetails": {"keytable": "$5", 
                        "keyvalue": "$6", 
                        "keycolumn": "$7"
                       }, 
    "tablerelationpath": "$8"}';
    
     SELECT REPLACE(vsourcejson,'$2', vtablelist) into vsourcejson FROM dual;
     SELECT REPLACE(vsourcejson,'$3', vschema) into vsourcejson FROM dual;
     SELECT REPLACE(vsourcejson,'$4', node.Nodename) into vsourcejson FROM dual;
     SELECT REPLACE(vsourcejson,'$5',vmastertablename ) into vsourcejson FROM dual;
     SELECT REPLACE(vsourcejson,'$6',vmasterkeyvalue ) into vsourcejson FROM dual;
     SELECT REPLACE(vsourcejson,'$7', vmasterkeycolumnname) into vsourcejson FROM dual;
     SELECT REPLACE(vsourcejson,'$8', vrelationcond) into vsourcejson FROM dual;
     
    /* Build the archive json parameter to be passed for archiving.  
    */
     varchivejson := '{
								"schema":$1,
								"tablename":$2
						}';
    

     SELECT REPLACE(varchivejson,'$1', varchiveschema) into varchivejson FROM dual;
     SELECT REPLACE(varchivejson,'$2', varchiveprefix || node.Nodename) into varchivejson FROM dual;

    dbms_output.put_line('Final json : '||vsourcejson || ' archive: ' || varchivejson);    
    archive_table(vsourcejson, varchivejson);
    
    END LOOP;
    --dbms_output.put_line('Final json : '||vsourcejson);    
    CLOSE cursor_tablelist;
    END;
END;
/

--CALL dijResolve('customers','orders');
--select * from dijnodes;
--select * from dijpaths;
--select * from relmap;


