/*
// pgAgent - PostgreSQL Tools
// 
// Copyright (C) 2002 - 2024, The pgAdmin Development Team
// This software is released under the PostgreSQL Licence
//
// pgagent.sql - pgAgent tables and functions
//
*/

BEGIN TRANSACTION;



CREATE SCHEMA pgagent;
COMMENT ON SCHEMA pgagent IS 'pgAgent system tables';



CREATE TABLE pgagent.pga_jobagent (
jagpid               int4                 NOT NULL PRIMARY KEY,
jaglogintime         timestamptz          NOT NULL DEFAULT current_timestamp,
jagstation           text                 NOT NULL
) WITHOUT OIDS;
COMMENT ON TABLE pgagent.pga_jobagent IS 'Active job agents';



CREATE TABLE pgagent.pga_jobclass (
jclid                serial               NOT NULL PRIMARY KEY,
jclname              text                 NOT NULL
) WITHOUT OIDS;
CREATE UNIQUE INDEX pga_jobclass_name ON pgagent.pga_jobclass(jclname);
COMMENT ON TABLE pgagent.pga_jobclass IS 'Job classification';

INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Routine Maintenance');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Data Import');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Data Export');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Data Summarisation');
INSERT INTO pgagent.pga_jobclass (jclname) VALUES ('Miscellaneous');
-- Be sure to update pg_extension_config_dump() below and in
-- upgrade scripts etc, when adding new classes.


CREATE TABLE pgagent.pga_job (
jobid                serial               NOT NULL PRIMARY KEY,
jobjclid             int4                 NOT NULL REFERENCES pgagent.pga_jobclass (jclid) ON DELETE RESTRICT ON UPDATE RESTRICT,
jobname              text                 NOT NULL,
jobdesc              text                 NOT NULL DEFAULT '',
jobhostagent         text                 NOT NULL DEFAULT '',
jobenabled           bool                 NOT NULL DEFAULT true,
jobcreated           timestamptz          NOT NULL DEFAULT current_timestamp,
jobchanged           timestamptz          NOT NULL DEFAULT current_timestamp,
jobagentid           int4                 NULL REFERENCES pgagent.pga_jobagent(jagpid) ON DELETE SET NULL ON UPDATE RESTRICT,
jobnextrun           timestamptz          NULL,
joblastrun           timestamptz          NULL
) WITHOUT OIDS;
COMMENT ON TABLE pgagent.pga_job IS 'Job main entry';
COMMENT ON COLUMN pgagent.pga_job.jobagentid IS 'Agent that currently executes this job.';



CREATE TABLE pgagent.pga_jobstep (
jstid                serial               NOT NULL PRIMARY KEY,
jstjobid             int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jstname              text                 NOT NULL,
jstdesc              text                 NOT NULL DEFAULT '',
jstenabled           bool                 NOT NULL DEFAULT true,
jstkind              char                 NOT NULL CHECK (jstkind IN ('b', 's')), -- batch, sql
jstcode              text                 NOT NULL,
jstconnstr           text                 NOT NULL DEFAULT '' CHECK ((jstconnstr != '' AND jstkind = 's' ) OR (jstconnstr = '' AND (jstkind = 'b' OR jstdbname != ''))),
jstdbname            name                 NOT NULL DEFAULT '' CHECK ((jstdbname != '' AND jstkind = 's' ) OR (jstdbname = '' AND (jstkind = 'b' OR jstconnstr != ''))),
jstonerror           char                 NOT NULL CHECK (jstonerror IN ('f', 's', 'i')) DEFAULT 'f', -- fail, success, ignore
jscnextrun           timestamptz          NULL
) WITHOUT OIDS;
CREATE INDEX pga_jobstep_jobid ON pgagent.pga_jobstep(jstjobid);
COMMENT ON TABLE pgagent.pga_jobstep IS 'Job step to be executed';
COMMENT ON COLUMN pgagent.pga_jobstep.jstkind IS 'Kind of jobstep: s=sql, b=batch';
COMMENT ON COLUMN pgagent.pga_jobstep.jstonerror IS 'What to do if step returns an error: f=fail the job, s=mark step as succeeded and continue, i=mark as fail but ignore it and proceed';



CREATE TABLE pgagent.pga_schedule (
jscid                serial               NOT NULL PRIMARY KEY,
jscjobid             int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jscname              text                 NOT NULL,
jscdesc              text                 NOT NULL DEFAULT '',
jscenabled           bool                 NOT NULL DEFAULT true,
jscstart             timestamptz          NOT NULL DEFAULT current_timestamp,
jscend               timestamptz          NULL,
jscminutes           bool[60]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
jschours             bool[24]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
jscweekdays          bool[7]              NOT NULL DEFAULT '{f,f,f,f,f,f,f}',
jscmonthdays         bool[32]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}',
jscmonths            bool[12]             NOT NULL DEFAULT '{f,f,f,f,f,f,f,f,f,f,f,f}',
CONSTRAINT pga_schedule_jscminutes_size CHECK (array_upper(jscminutes, 1) = 60),
CONSTRAINT pga_schedule_jschours_size CHECK (array_upper(jschours, 1) = 24),
CONSTRAINT pga_schedule_jscweekdays_size CHECK (array_upper(jscweekdays, 1) = 7),
CONSTRAINT pga_schedule_jscmonthdays_size CHECK (array_upper(jscmonthdays, 1) = 32),
CONSTRAINT pga_schedule_jscmonths_size CHECK (array_upper(jscmonths, 1) = 12)
) WITHOUT OIDS;
CREATE INDEX pga_jobschedule_jobid ON pgagent.pga_schedule(jscjobid);
COMMENT ON TABLE pgagent.pga_schedule IS 'Schedule for a job';



CREATE TABLE pgagent.pga_exception (
jexid                serial               NOT NULL PRIMARY KEY,
jexscid              int4                 NOT NULL REFERENCES pgagent.pga_schedule (jscid) ON DELETE CASCADE ON UPDATE RESTRICT,
jexdate              date                NULL,
jextime              time                NULL
)
WITHOUT OIDS;
CREATE INDEX pga_exception_jexscid ON pgagent.pga_exception (jexscid);
CREATE UNIQUE INDEX pga_exception_datetime ON pgagent.pga_exception (jexdate, jextime);
COMMENT ON TABLE pgagent.pga_schedule IS 'Job schedule exceptions';



CREATE TABLE pgagent.pga_joblog (
jlgid                serial               NOT NULL PRIMARY KEY,
jlgjobid             int4                 NOT NULL REFERENCES pgagent.pga_job (jobid) ON DELETE CASCADE ON UPDATE RESTRICT,
jlgstatus            char                 NOT NULL CHECK (jlgstatus IN ('r', 's', 'f', 'i', 'd')) DEFAULT 'r', -- running, success, failed, internal failure, aborted
jlgstart             timestamptz          NOT NULL DEFAULT current_timestamp,
jlgduration          interval             NULL
) WITHOUT OIDS;
CREATE INDEX pga_joblog_jobid ON pgagent.pga_joblog(jlgjobid);
COMMENT ON TABLE pgagent.pga_joblog IS 'Job run logs.';
COMMENT ON COLUMN pgagent.pga_joblog.jlgstatus IS 'Status of job: r=running, s=successfully finished, f=failed, i=no steps to execute, d=aborted';



CREATE TABLE pgagent.pga_jobsteplog (
jslid                serial               NOT NULL PRIMARY KEY,
jsljlgid             int4                 NOT NULL REFERENCES pgagent.pga_joblog (jlgid) ON DELETE CASCADE ON UPDATE RESTRICT,
jsljstid             int4                 NOT NULL REFERENCES pgagent.pga_jobstep (jstid) ON DELETE CASCADE ON UPDATE RESTRICT,
jslstatus            char                 NOT NULL CHECK (jslstatus IN ('r', 's', 'i', 'f', 'd')) DEFAULT 'r', -- running, success, ignored, failed, aborted
jslresult            int4                 NULL,
jslstart             timestamptz          NOT NULL DEFAULT current_timestamp,
jslduration          interval             NULL,
jsloutput            text
) WITHOUT OIDS;
CREATE INDEX pga_jobsteplog_jslid ON pgagent.pga_jobsteplog(jsljlgid);
COMMENT ON TABLE pgagent.pga_jobsteplog IS 'Job step run logs.';
COMMENT ON COLUMN pgagent.pga_jobsteplog.jslstatus IS 'Status of job step: r=running, s=successfully finished,  f=failed stopping job, i=ignored failure, d=aborted';
COMMENT ON COLUMN pgagent.pga_jobsteplog.jslresult IS 'Return code of job step';

CREATE OR REPLACE FUNCTION pgagent.pgagent_schema_version() RETURNS int2 AS '
BEGIN
    -- RETURNS PGAGENT MAJOR VERSION
    -- WE WILL CHANGE THE MAJOR VERSION, ONLY IF THERE IS A SCHEMA CHANGE
    RETURN 4;
END;
' LANGUAGE 'plpgsql' VOLATILE;


CREATE OR REPLACE FUNCTION pgagent.pga_next_schedule(int4, timestamptz, timestamptz, _bool, _bool, _bool, _bool, _bool, _bool) RETURNS timestamptz AS '
DECLARE
    jscid           ALIAS FOR $1;
    jscstart        ALIAS FOR $2;
    jscend          ALIAS FOR $3;
    jscminutes      ALIAS FOR $4;
    jschours        ALIAS FOR $5;
    jscweekdays     ALIAS FOR $6;
    jscmonthdays    ALIAS FOR $7;
    jscmonths       ALIAS FOR $8;
    jscoccurence    ALIAS FOR $9;

    nextrun         timestamp := ''1970-01-01 00:00:00-00'';
    runafter        timestamp := ''1970-01-01 00:00:00-00'';

    bingo            bool := FALSE;
    gotit            bool := FALSE;
    foundval        bool := FALSE;
    daytweak        bool := FALSE;
    minutetweak        bool := FALSE;

    i                int2 := 0;
    d                int2 := 0;

    nextminute        int2 := 0;
    nexthour        int2 := 0;
    nextday            int2 := 0;
    nextmonth       int2 := 0;
    nextyear        int2 := 0;

    -- Variables for occurrence handling
    current_occurrence int2 := 0;
    target_occurrence int2 := 0;
    current_weekday int2 := 0;
    target_weekday int2 := 0;
BEGIN
    -- No valid start date has been specified
    IF jscstart IS NULL THEN RETURN NULL; END IF;

    -- The schedule is past its end date
    IF jscend IS NOT NULL AND jscend < now() THEN RETURN NULL; END IF;

    -- Get the time to find the next run after
    IF date_trunc(''MINUTE'', jscstart) > date_trunc(''MINUTE'', (now() + ''1 Minute''::interval)) THEN
        runafter := date_trunc(''MINUTE'', jscstart);
    ELSE
        runafter := date_trunc(''MINUTE'', (now() + ''1 Minute''::interval));
    END IF;

    -- Main scheduling loop
    WHILE NOT bingo LOOP
        nextrun := runafter;
        nextminute := date_part(''MINUTE'', nextrun)::int2;
        nexthour := date_part(''HOUR'', nextrun)::int2;
        nextday := date_part(''DAY'', nextrun)::int2;
        nextmonth := date_part(''MONTH'', nextrun)::int2;
        nextyear := date_part(''YEAR'', nextrun)::int2;

        -- Check if we have a valid minute
        IF jscminutes[nextminute + 1] THEN
            -- Check if we have a valid hour
            IF jschours[nexthour + 1] THEN
                -- Check if we have a valid weekday
                current_weekday := date_part(''DOW'', nextrun)::int2;
                IF jscweekdays[current_weekday + 1] THEN
                    -- Check if we have a valid month day
                    IF jscmonthdays[nextday] THEN
                        -- Check if we have a valid month
                        IF jscmonths[nextmonth] THEN
                            -- Check occurrence if specified
                            IF jscoccurence IS NOT NULL AND array_position(jscoccurence, true) IS NOT NULL THEN
                                -- Calculate current occurrence in the month
                                current_occurrence := 0;
                                FOR i IN 0..6 LOOP
                                    IF jscweekdays[i + 1] THEN
                                        current_occurrence := current_occurrence + 1;
                                        IF i = current_weekday THEN
                EXIT;
            END IF;
                END IF;
           END LOOP;

                                -- Check if this is the desired occurrence
                                target_occurrence := array_position(jscoccurence, true);
                                IF current_occurrence = target_occurrence THEN
                                    bingo := TRUE;
                                ELSE
                                    -- Move to next occurrence
                                    runafter := nextrun + INTERVAL ''1 Week'';
                                    bingo := FALSE;
                                    minutetweak := FALSE;
                                    daytweak := TRUE;
                                END IF;
                            ELSE
                                bingo := TRUE;
                            END IF;
                        ELSE
                            -- Wrong month, move to next month
                            runafter := nextrun + INTERVAL ''1 Month'';
                            bingo := FALSE;
                            minutetweak := FALSE;
                            daytweak := TRUE;
                        END IF;
                    ELSE
                        -- Wrong day of month, move to next day
                        runafter := nextrun + INTERVAL ''1 Day'';
                        bingo := FALSE;
                        minutetweak := FALSE;
                        daytweak := TRUE;
                    END IF;
                ELSE
                    -- Wrong day of week, move to next day
                    runafter := nextrun + INTERVAL ''1 Day'';
                    bingo := FALSE;
                    minutetweak := FALSE;
                    daytweak := TRUE;
                END IF;
            ELSE
                -- Wrong hour, move to next hour
                runafter := nextrun + INTERVAL ''1 Hour'';
                bingo := FALSE;
                minutetweak := TRUE;
                daytweak := FALSE;
            END IF;
        ELSE
            -- Wrong minute, move to next minute
            runafter := nextrun + INTERVAL ''1 Minute'';
            bingo := FALSE;
            minutetweak := TRUE;
        daytweak := FALSE;
        END IF;

        -- Check for exceptions
        SELECT INTO d jexid FROM pgagent.pga_exception 
        WHERE jexscid = jscid 
        AND ((jexdate = nextrun::date AND jextime = nextrun::time) 
             OR (jexdate = nextrun::date AND jextime IS NULL) 
             OR (jexdate IS NULL AND jextime = nextrun::time));
        
        IF FOUND THEN
            -- Found an exception, increment time and try again
            runafter := nextrun + INTERVAL ''1 Minute'';
            bingo := FALSE;
            minutetweak := TRUE;
            daytweak := FALSE;
        END IF;
    END LOOP;

    RETURN nextrun;
END;
' LANGUAGE 'plpgsql' VOLATILE;
COMMENT ON FUNCTION pgagent.pga_next_schedule(int4, timestamptz, timestamptz, _bool, _bool, _bool, _bool, _bool, _bool) IS 'Calculates the next runtime for a given schedule';



--
-- Test code
--
-- SELECT pgagent.pga_next_schedule(
--     2, -- Schedule ID
--     '2005-01-01 00:00:00', -- Start date
--     '2006-10-01 00:00:00', -- End date
--     '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', -- Minutes
--     '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', -- Hours
--     '{f,f,f,f,f,f,f}', -- Weekdays
--     '{f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f}', -- Monthdays
--     '{f,f,f,f,f,f,f,f,f,f,f,f}' -- Months
-- );



CREATE OR REPLACE FUNCTION pgagent.pga_is_leap_year(int2) RETURNS bool AS '
BEGIN
    IF $1 % 4 != 0 THEN
        RETURN FALSE;
    END IF;

    IF $1 % 100 != 0 THEN
        RETURN TRUE;
    END IF;

    RETURN $1 % 400 = 0;
END;
' LANGUAGE 'plpgsql' IMMUTABLE;
COMMENT ON FUNCTION pgagent.pga_is_leap_year(int2) IS 'Returns TRUE if $1 is a leap year';


CREATE OR REPLACE FUNCTION pgagent.pga_job_trigger()
  RETURNS "trigger" AS
'
BEGIN
    IF NEW.jobenabled THEN
        IF NEW.jobnextrun IS NULL THEN
             SELECT INTO NEW.jobnextrun
                    MIN(pgagent.pga_next_schedule(jscid, jscstart, jscend, jscminutes, jschours, jscweekdays, jscmonthdays, jscmonths, jscoccurence))
               FROM pgagent.pga_schedule
              WHERE jscenabled AND jscjobid=OLD.jobid;
        END IF;
    ELSE
        NEW.jobnextrun := NULL;
    END IF;
    RETURN NEW;
END;
'
  LANGUAGE 'plpgsql' VOLATILE;
COMMENT ON FUNCTION pgagent.pga_job_trigger() IS 'Update the job''s next run time.';

CREATE TRIGGER pga_job_trigger BEFORE UPDATE
  ON pgagent.pga_job FOR EACH ROW
  EXECUTE PROCEDURE pgagent.pga_job_trigger();
COMMENT ON TRIGGER pga_job_trigger ON pgagent.pga_job IS 'Update the job''s next run time.';


CREATE OR REPLACE FUNCTION pgagent.pga_schedule_trigger() RETURNS trigger AS '
BEGIN
    IF TG_OP = ''DELETE'' THEN
        -- update pga_job from remaining schedules
        -- the actual calculation of jobnextrun will be performed in the trigger
        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid=OLD.jscjobid;
        RETURN OLD;
    ELSE
        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid=NEW.jscjobid;
        RETURN NEW;
    END IF;
END;
' LANGUAGE 'plpgsql';
COMMENT ON FUNCTION pgagent.pga_schedule_trigger() IS 'Update the job''s next run time whenever a schedule changes';



CREATE TRIGGER pga_schedule_trigger AFTER INSERT OR UPDATE OR DELETE
   ON pgagent.pga_schedule FOR EACH ROW
   EXECUTE PROCEDURE pgagent.pga_schedule_trigger();
COMMENT ON TRIGGER pga_schedule_trigger ON pgagent.pga_schedule IS 'Update the job''s next run time whenever a schedule changes';


CREATE OR REPLACE FUNCTION pgagent.pga_exception_trigger() RETURNS "trigger" AS '
DECLARE

    v_jobid int4 := 0;

BEGIN

     IF TG_OP = ''DELETE'' THEN

        SELECT INTO v_jobid jscjobid FROM pgagent.pga_schedule WHERE jscid = OLD.jexscid;

        -- update pga_job from remaining schedules
        -- the actual calculation of jobnextrun will be performed in the trigger
        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid = v_jobid;
        RETURN OLD;
    ELSE

        SELECT INTO v_jobid jscjobid FROM pgagent.pga_schedule WHERE jscid = NEW.jexscid;

        UPDATE pgagent.pga_job
           SET jobnextrun = NULL
         WHERE jobenabled AND jobid = v_jobid;
        RETURN NEW;
    END IF;
END;
' LANGUAGE 'plpgsql' VOLATILE;
COMMENT ON FUNCTION pgagent.pga_exception_trigger() IS 'Update the job''s next run time whenever an exception changes';



CREATE TRIGGER pga_exception_trigger AFTER INSERT OR UPDATE OR DELETE
  ON pgagent.pga_exception FOR EACH ROW
  EXECUTE PROCEDURE pgagent.pga_exception_trigger();
COMMENT ON TRIGGER pga_exception_trigger ON pgagent.pga_exception IS 'Update the job''s next run time whenever an exception changes';

-- Extension dump support.
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobagent', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobclass', $$WHERE jclname NOT IN ('Routine Maintenance', 'Data Import', 'Data Export', 'Data Summarisation', 'Miscellaneous')$$);
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_job', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobstep', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_schedule', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_exception', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_joblog', '');
-- EXT SELECT pg_catalog.pg_extension_config_dump('pga_jobsteplog', '');

COMMIT TRANSACTION;
