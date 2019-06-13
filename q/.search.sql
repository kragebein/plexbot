-- Den her blocken vil erstatt plex.sh.tt0898266
-- Vil output all data om evt match i json.
DECLARE
    showtype         VARCHAR2(6);
    output           VARCHAR(9999);
    json_null        VARCHAR2(90);
    input            VARCHAR2(30);
    input_int        NUMBER;
    input_char       VARCHAR(30);
    episodes_count   NUMBER;
    this_id          NUMBER;
BEGIN
    input := '%query%';
    IF regexp_like(input, '^[0-9]{1,3}(.*)$') THEN
-- is intls
        input_int := input;
        input_char := '00000';
    ELSE
-- is char
        input_char := input;
        input_int := '00000';
    END IF;

    json_null := '{"error": '
                 || input
                 || ' was not found}';
-- do the actual search
    SELECT
        id
    INTO this_id
    FROM
        pb
    WHERE
        pb.id = input_int
        OR pb.imdbid = input_char
        OR pb.service_id = input_int
        OR pb.plexid = input_int;
-- get type      

    SELECT
        type
    INTO showtype
    FROM
        pb
    WHERE
        id = this_id;

    IF showtype = 'movie' THEN
        SELECT
            JSON_OBJECT ( 'id' VALUE pb.id, 'type' VALUE pb.type, 'name' VALUE pb_movies.name, 'path' VALUE pb_movies.path, 'status'
            VALUE pb_movies.status, 'request' VALUE pb_movies.request, 'data' VALUE JSON_OBJECT ( 'imdbid' VALUE pb.imdbid, 'serviceid'
            VALUE pb.service_id, 'plexid' VALUE pb.plexid ABSENT ON NULL ) ABSENT ON NULL )
        INTO output
        FROM
            pb_movies
            INNER JOIN pb ON pb.id = pb_movies.id
        WHERE
            pb.id = this_id;

        dbms_output.put_line(output);
    ELSIF showtype = 'series' THEN
        SELECT
            JSON_OBJECT ( 'id' VALUE pb.id, 'type' VALUE pb.type, 'name' VALUE pb_series.name, 'request' VALUE pb_series.request,
            'status' VALUE pb_series.status, 'data' VALUE JSON_OBJECT ( 'imdbid' VALUE pb.imdbid, 'serviceid' VALUE pb.service_id
            , 'plexid' VALUE pb.plexid ABSENT ON NULL ) ABSENT ON NULL )
        INTO output
        FROM
            pb_series
            INNER JOIN pb ON pb.id = pb_series.id
        WHERE
            pb.id = this_id;

        dbms_output.put_line(output);
    ELSE
        dbms_output.put_line(json_null);
    END IF;

EXCEPTION
    WHEN no_data_found THEN
        dbms_output.put_line(json_null);
    WHEN too_many_rows THEN
        dbms_output.put_line('{"error": Results returned too many rows. Check db.}');
    WHEN OTHERS THEN
        dbms_output.put_line('{"error":'||SQLERRM||'}');
END;
.
/

